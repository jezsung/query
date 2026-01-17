import 'dart:async';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'infinite_data.dart';
import 'infinite_query_function_context.dart';
import 'infinite_query_observer_options.dart';
import 'infinite_query_result.dart';
import 'observable.dart';
import 'query.dart';
import 'query_client.dart';
import 'query_options.dart';
import 'query_result.dart';
import 'query_state.dart';
import 'refetch_on_mount.dart';
import 'refetch_on_resume.dart';
import 'stale_duration.dart';
import 'utils.dart';

part 'infinite_query_observer.dart';

class QueryObserver<TData, TError> with Observer<QueryState<TData, TError>> {
  QueryObserver(
    QueryClient client,
    QueryObserverOptions<TData, TError> options,
  ) : _client = client {
    _options = options.withDefaults(client.defaultQueryOptions);
    _query = client.cache.build<TData, TError>(options)..addObserver(this);
    _initialDataUpdateCount = _query.state.dataUpdateCount;
    _initialErrorUpdateCount = _query.state.errorUpdateCount;
    _result = _buildResult(_options, _query.state, optimistic: true);
  }

  final QueryClient _client;

  late QueryObserverOptions<TData, TError> _options;
  late Query<TData, TError> _query;
  late int _initialDataUpdateCount;
  late int _initialErrorUpdateCount;
  late QueryResult<TData, TError> _result;

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

      result = _buildResult(_options, _query.state, optimistic: true);

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
      result = _buildResult(_options, _query.state, optimistic: true);
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
    result = _buildResult(_options, _query.state);
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
    return _buildResult(_options, _query.state);
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

  bool _shouldFetchOnMount(
    final QueryObserverOptions<TData, TError> options,
    final QueryState<TData, TError> state,
  ) {
    final enabled = options.enabled ?? true;
    final staleDuration = options.staleDuration ?? StaleDuration.zero;
    final refetchOnMount = options.refetchOnMount ?? RefetchOnMount.stale;
    final retryOnMount = options.retryOnMount ?? true;

    if (!enabled) {
      return false;
    }
    if (state.data == null || state.dataUpdatedAt == null) {
      if (state.status == QueryStatus.error && !retryOnMount) {
        return false;
      }
      return true;
    }
    if (staleDuration == StaleDuration.static) {
      return false;
    }
    switch (refetchOnMount) {
      case RefetchOnMount.stale:
        switch (staleDuration) {
          case StaleDurationValue():
            final age = clock.now().difference(state.dataUpdatedAt!);
            return age >= staleDuration;
          case StaleDurationInfinity():
          case StaleDurationStatic():
            return false;
        }
      case RefetchOnMount.never:
        return false;
      case RefetchOnMount.always:
        return true;
    }
  }

  bool _shouldFetchOnResume(
    final QueryObserverOptions<TData, TError> options,
    final QueryState<TData, TError> state,
  ) {
    final enabled = options.enabled ?? true;
    final staleDuration = options.staleDuration ?? StaleDuration.zero;
    final refetchOnResume = options.refetchOnResume ?? RefetchOnResume.stale;

    if (!enabled) {
      return false;
    }
    if (staleDuration == StaleDuration.static) {
      return false;
    }
    switch (refetchOnResume) {
      case RefetchOnResume.stale:
        if (state.data == null || state.dataUpdatedAt == null) {
          return true;
        }
        switch (staleDuration) {
          case StaleDurationValue():
            final age = clock.now().difference(state.dataUpdatedAt!);
            return age >= staleDuration;
          case StaleDurationInfinity():
          case StaleDurationStatic():
            return false;
        }
      case RefetchOnResume.never:
        return false;
      case RefetchOnResume.always:
        return true;
    }
  }

  QueryResult<TData, TError> _buildResult(
    QueryObserverOptions<TData, TError> options,
    QueryState<TData, TError> state, {
    bool optimistic = false,
  }) {
    final result = QueryResult<TData, TError>(
      status: state.status,
      fetchStatus: optimistic && _shouldFetchOnMount(options, state)
          ? FetchStatus.fetching
          : state.fetchStatus,
      data: state.data,
      dataUpdatedAt: state.dataUpdatedAt,
      dataUpdateCount: state.dataUpdateCount,
      error: state.error,
      errorUpdatedAt: state.errorUpdatedAt,
      errorUpdateCount: state.errorUpdateCount,
      isEnabled: options.enabled ?? true,
      isStale: (options.enabled ?? true) &&
          _query.shouldFetch(options.staleDuration ?? StaleDuration.zero),
      isFetchedAfterMount: state.dataUpdateCount > _initialDataUpdateCount ||
          state.errorUpdateCount > _initialErrorUpdateCount,
      isPlaceholderData: false,
      failureCount: state.failureCount,
      failureReason: state.failureReason,
      refetch: refetch,
    );
    return result.copyWithPlaceholder(options.placeholder);
  }
}

@internal
typedef ResultChangeListener<TData, TError> = void Function(
  QueryResult<TData, TError> result,
);
