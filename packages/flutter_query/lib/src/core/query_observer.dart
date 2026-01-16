import 'dart:async';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:meta/meta.dart';

import 'infinite_data.dart';
import 'infinite_query_function_context.dart';
import 'infinite_query_observer_options.dart';
import 'infinite_query_result.dart';
import 'observable.dart';
import 'query.dart';
import 'query_client.dart';
import 'query_function_context.dart';
import 'query_options.dart';
import 'query_result.dart';
import 'query_state.dart';
import 'refetch_on_mount.dart';
import 'refetch_on_resume.dart';
import 'stale_duration.dart';

part 'infinite_query_observer.dart';

class QueryObserver<TData, TError> with Observer<QueryState<TData, TError>> {
  QueryObserver(
    QueryClient client,
    QueryObserverOptions<TData, TError> options,
  )   : _client = client,
        _options = options.withDefaults(client.defaultQueryOptions),
        _query = client.cache.build<TData, TError>(options) {
    _query.addObserver(this);

    // Capture initial state counters for isFetchedAfterMount calculation
    _initialDataUpdateCount = _query.state.dataUpdateCount;
    _initialErrorUpdateCount = _query.state.errorUpdateCount;

    // Get initial optimistic result
    _result = _getResult(optimistic: true);
  }

  final QueryClient _client;
  QueryObserverOptions<TData, TError> _options;
  Query<TData, TError> _query;
  late QueryResult<TData, TError> _result;

  late int _initialDataUpdateCount;
  late int _initialErrorUpdateCount;
  Timer? _refetchIntervalTimer;

  final Set<ResultChangeListener<TData, TError>> _listeners = {};

  QueryObserverOptions<TData, TError> get options => _options;
  QueryResult<TData, TError> get result => _result;

  set options(QueryObserverOptions<TData, TError> value) {
    final oldOptions = _options;
    final newOptions = value.withDefaults(_client.defaultQueryOptions);
    _options = newOptions;

    // Handle query key change separately - requires switching queries
    if (newOptions.queryKey != oldOptions.queryKey) {
      _query.removeObserver(this);

      _query = _client.cache.build<TData, TError>(newOptions);
      _query.addObserver(this);

      _initialDataUpdateCount = _query.state.dataUpdateCount;
      _initialErrorUpdateCount = _query.state.errorUpdateCount;

      result = _getResult(optimistic: true);

      if (_shouldFetchOnMount(newOptions, _query.state)) {
        _query.fetch().ignore();
      }

      _startRefetchInterval();

      return;
    }

    final didEnabledChange = newOptions.enabled != oldOptions.enabled;
    final didStaleDurationChange =
        newOptions.staleDuration != oldOptions.staleDuration;
    final didPlaceholderChange =
        newOptions.placeholder != oldOptions.placeholder;
    final didRefetchOnMountChange =
        newOptions.refetchOnMount != oldOptions.refetchOnMount;
    final didRefetchOnResumeChange =
        newOptions.refetchOnResume != oldOptions.refetchOnResume;
    final didRefetchIntervalChange =
        newOptions.refetchInterval != oldOptions.refetchInterval;
    final didRetryChange = !identical(newOptions.retry, oldOptions.retry);
    final didRetryOnMountChange =
        newOptions.retryOnMount != oldOptions.retryOnMount;

    // If nothing changed, return early
    if (!didEnabledChange &&
        !didStaleDurationChange &&
        !didPlaceholderChange &&
        !didRefetchOnMountChange &&
        !didRefetchOnResumeChange &&
        !didRefetchIntervalChange &&
        !didRetryChange &&
        !didRetryOnMountChange) {
      return;
    }

    final maySetResult = didEnabledChange ||
        didStaleDurationChange ||
        didPlaceholderChange ||
        didRefetchOnMountChange ||
        didRefetchOnResumeChange ||
        didRetryOnMountChange;

    final mayFetch = didEnabledChange ||
        didStaleDurationChange ||
        didRefetchOnMountChange ||
        didRetryOnMountChange;

    final mayStartRefetchInterval =
        didEnabledChange || didRefetchIntervalChange;

    if (maySetResult) {
      result = _getResult(optimistic: true);
    }

    if (mayFetch && _shouldFetchOnMount(newOptions, _query.state)) {
      _query.fetch().ignore();
    }

    if (mayStartRefetchInterval) {
      _startRefetchInterval();
    }
  }

  set result(QueryResult<TData, TError> newResult) {
    if (newResult != _result) {
      _result = newResult;
      for (final listener in _listeners) {
        listener(newResult);
      }
    }
  }

  void onMount() {
    if (_shouldFetchOnMount(_options, _query.state)) {
      _query.fetch().ignore();
    }

    _startRefetchInterval();
  }

  void onResume() {
    if (_shouldFetchOnResume(_options, _query.state)) {
      _query.fetch().ignore();
    }
  }

  void onUnmount() {
    _listeners.clear();
    _cancelRefetchInterval();
    _query.removeObserver(this);
  }

  @override
  void onNotified(QueryState<TData, TError> newState) {
    result = _getResult();
  }

  /// Manually refetch the query.
  ///
  /// [cancelRefetch] - If true (default), cancels any in-progress fetch before
  /// starting a new one. If false, returns the result of the existing fetch.
  ///
  /// [throwOnError] - If true, rethrows any error that occurs during the fetch.
  /// If false (default), errors are swallowed and captured in query state.
  Future<QueryResult<TData, TError>> refetch({
    bool cancelRefetch = true,
    bool throwOnError = false,
  }) async {
    try {
      await _query.fetch(cancelRefetch: cancelRefetch);
    } catch (e) {
      if (throwOnError) rethrow;
      // Swallow error - it's captured in query state
    }
    return _getResult();
  }

  void Function() subscribe(ResultChangeListener<TData, TError> listener) {
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  void _startRefetchInterval() {
    _cancelRefetchInterval();

    // Use getter to support subclass overrides (e.g. _QueryObserverAdapter)
    final enabled = options.enabled ?? true;
    final interval = options.refetchInterval;

    if (!enabled || interval == null || interval <= Duration.zero) {
      return;
    }

    _refetchIntervalTimer = Timer.periodic(
      interval,
      (_) => _query.fetch().ignore(),
    );
  }

  void _cancelRefetchInterval() {
    _refetchIntervalTimer?.cancel();
    _refetchIntervalTimer = null;
  }

  QueryResult<TData, TError> _getResult({bool optimistic = false}) {
    // Pull fresh state from query
    final state = _query.state;

    var status = state.status;
    var fetchStatus = state.fetchStatus;
    var data = state.data;
    var isPlaceholderData = false;

    // Check if we should fetch on mount (enabled and (no data or stale))
    if (optimistic) {
      fetchStatus = _shouldFetchOnMount(_options, state)
          ? FetchStatus.fetching
          : state.fetchStatus;
    }

    // Use placeholder if needed (when query is pending and has no data)
    if (_options.placeholder != null &&
        data == null &&
        status == QueryStatus.pending) {
      status = QueryStatus.success;
      data = _options.placeholder;
      isPlaceholderData = true;
    }

    final staleDuration = _options.staleDuration ?? const StaleDuration();

    // Compute isStale: disabled queries are never considered stale
    // This matches TanStack Query's behavior
    final isEnabled = _options.enabled ?? true;
    final isStale = isEnabled && _query.shouldFetch(staleDuration);

    return QueryResult<TData, TError>(
      status: status,
      fetchStatus: fetchStatus,
      data: data,
      dataUpdatedAt: state.dataUpdatedAt,
      dataUpdateCount: state.dataUpdateCount,
      error: state.error,
      errorUpdatedAt: state.errorUpdatedAt,
      errorUpdateCount: state.errorUpdateCount,
      isEnabled: isEnabled,
      isStale: isStale,
      isFetchedAfterMount: state.dataUpdateCount > _initialDataUpdateCount ||
          state.errorUpdateCount > _initialErrorUpdateCount,
      isPlaceholderData: isPlaceholderData,
      failureCount: state.failureCount,
      failureReason: state.failureReason,
      refetch: refetch,
    );
  }

  bool _shouldFetchOnMount(
    QueryObserverOptions<TData, TError> options,
    QueryState<TData, TError> state,
  ) {
    final enabled = options.enabled ?? true;
    final retryOnMount = options.retryOnMount ?? true;
    final refetchOnMount = options.refetchOnMount ?? RefetchOnMount.stale;

    if (!enabled) {
      return false;
    }

    // Don't fetch if query has error and retryOnMount is false
    if (state.status == QueryStatus.error && !retryOnMount) {
      return false;
    }

    // No data yet - should fetch
    if (state.data == null) {
      return true;
    }

    // Has data - check staleness and refetchOnMount
    final staleDuration = options.staleDuration ?? const StaleDuration();

    // With static staleDuration, data is always fresh and should never refetch automatically
    if (staleDuration is StaleDurationStatic) {
      return false;
    }

    if (refetchOnMount == RefetchOnMount.always) {
      return true;
    }
    if (refetchOnMount == RefetchOnMount.never) {
      return false;
    }

    final age = clock.now().difference(state.dataUpdatedAt!);

    return switch (staleDuration) {
      // Check if age exceeds or equals staleDuration (>= for zero staleDuration)
      StaleDurationValue duration => age >= duration,
      // If staleDuration is StaleDurationInfinity, never stale (unless invalidated)
      StaleDurationInfinity() => false,
      // If staleDuration is StaleDurationStatic, never stale
      StaleDurationStatic() => false,
    };
  }

  bool _shouldFetchOnResume(
    QueryObserverOptions<TData, TError> options,
    QueryState<TData, TError> state,
  ) {
    final enabled = options.enabled ?? true;
    final refetchOnResume = options.refetchOnResume ?? RefetchOnResume.stale;

    if (!enabled) return false;

    final staleDuration = options.staleDuration ?? const StaleDuration();

    // With static staleDuration, data is always fresh and should never refetch automatically
    if (staleDuration is StaleDurationStatic) {
      return false;
    }

    if (refetchOnResume == RefetchOnResume.never) {
      return false;
    }

    if (refetchOnResume == RefetchOnResume.always) {
      return true;
    }

    // For 'stale' mode: check if data is stale
    // If there's no data, it's considered stale
    if (state.data == null || state.dataUpdatedAt == null) {
      return true;
    }

    final age = clock.now().difference(state.dataUpdatedAt!);

    return switch (staleDuration) {
      StaleDurationValue duration => age >= duration,
      StaleDurationInfinity() => false,
      StaleDurationStatic() => false,
    };
  }
}

@internal
typedef ResultChangeListener<TData, TError> = void Function(
  QueryResult<TData, TError> result,
);
