import 'dart:async';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'infinite_query_function_context.dart';
import 'infinite_query_options.dart';
import 'infinite_query_snapshot.dart';
import 'observable.dart';
import 'query.dart';
import 'query_client.dart';
import 'query_options.dart';
import 'query_snapshot.dart';
import 'query_state.dart';
import 'utils.dart';

part 'infinite_query_observer.dart';

@internal
typedef QuerySnapshotListener<TData, TError> = void Function(
  QuerySnapshot<TData, TError> snapshot,
);

@internal
class QueryObserver<TData, TError> with Observer<QueryState<TData, TError>> {
  QueryObserver(
    this._client,
    QueryOptions<TData, TError> options,
  ) : _options = options.withDefaults(_client.defaultQueryOptions);

  final QueryClient _client;
  QueryOptions<TData, TError> _options;
  QuerySnapshot<TData, TError>? _result;
  QueryOptions<TData, TError>? _resultOptions;
  TData? _lastDefinedData;
  late Query<TData, TError> _query;
  late int _initialDataUpdateCount;
  late int _initialErrorUpdateCount;

  Timer? _refetchIntervalTimer;

  final Set<QuerySnapshotListener<TData, TError>> _listeners = {};

  QueryOptions<TData, TError> get options => _options;

  QuerySnapshot<TData, TError> get result {
    if (_result == null) {
      throw StateError(
        'Cannot access result before QueryObserver is mounted. '
        'Call onMount() first.',
      );
    }
    return _result as QuerySnapshot<TData, TError>;
  }

  set options(QueryOptions<TData, TError> value) {
    final oldOptions = _options;
    final newOptions = value.withDefaults(_client.defaultQueryOptions);
    _options = newOptions;

    // Handle query key change separately - requires switching queries
    if (newOptions.key != oldOptions.key) {
      _query.removeObserver(this);
      onMount();
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
      _fetch().ignore();
    }

    if (mayStartRefetchInterval) {
      _startRefetchInterval();
    }
  }

  set result(QuerySnapshot<TData, TError> newResult) {
    if (newResult != _result) {
      _result = newResult;
      for (final listener in _listeners) {
        listener(newResult);
      }
    }
  }

  void onMount() {
    _query = Query.cached(
      _client,
      _options.queryKey,
      gcDuration: _options.gcDuration,
      seed: _options.seed,
      seedUpdatedAt: _options.seedUpdatedAt,
    );
    _initialDataUpdateCount = _query.state.dataUpdateCount;
    _initialErrorUpdateCount = _query.state.errorUpdateCount;
    _query.addObserver(this);

    final newResult = _buildResult(_options, _query.state, optimistic: true);
    _result ??= newResult;
    result = newResult;

    if (_shouldFetchOnMount(_options, _query.state)) {
      _fetch().ignore();
    }

    _startRefetchInterval();
  }

  void onUnmount() {
    _listeners.clear();
    _cancelRefetchInterval();
    _query.removeObserver(this);
  }

  void onResume() {
    if (_shouldFetchOnResume(_options, _query.state)) {
      _fetch().ignore();
    }
  }

  void onReconnect() {
    if (_shouldFetchOnReconnect(_options, _query.state)) {
      _fetch().ignore();
    }
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
  Future<QuerySnapshot<TData, TError>> refetch({
    bool cancelRefetch = true,
    bool throwOnError = false,
  }) async {
    try {
      await _fetch(cancelRefetch: cancelRefetch);
    } catch (e) {
      if (throwOnError) rethrow;
      // Swallow error - it's captured in query state
    }
    return _buildResult(_options, _query.state);
  }

  void Function() subscribe(QuerySnapshotListener<TData, TError> listener) {
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  Future<TData> _fetch({bool cancelRefetch = false}) {
    return _query.fetch(
      _options.queryFn,
      gcDuration: _options.gcDuration,
      retry: _options.retry,
      networkMode: _options.networkMode,
      meta: _options.meta,
      cancelRefetch: cancelRefetch,
    );
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
      (_) => _fetch().ignore(),
    );
  }

  void _cancelRefetchInterval() {
    _refetchIntervalTimer?.cancel();
    _refetchIntervalTimer = null;
  }

  bool _shouldFetchOnMount(
    final QueryOptions<TData, TError> options,
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
            if (state.isInvalidated) {
              return true;
            }
            final age = clock.now().difference(state.dataUpdatedAt!);
            return age >= staleDuration;
          case StaleDurationInfinity():
            return state.isInvalidated;
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
    final QueryOptions<TData, TError> options,
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
            if (state.isInvalidated) {
              return true;
            }
            final age = clock.now().difference(state.dataUpdatedAt!);
            return age >= staleDuration;
          case StaleDurationInfinity():
            return state.isInvalidated;
          case StaleDurationStatic():
            return false;
        }
      case RefetchOnResume.never:
        return false;
      case RefetchOnResume.always:
        return true;
    }
  }

  bool _shouldFetchOnReconnect(
    final QueryOptions<TData, TError> options,
    final QueryState<TData, TError> state,
  ) {
    final enabled = options.enabled ?? true;
    final staleDuration = options.staleDuration ?? StaleDuration.zero;
    final refetchOnReconnect =
        options.refetchOnReconnect ?? RefetchOnReconnect.stale;

    if (!enabled) {
      return false;
    }
    if (staleDuration == StaleDuration.static) {
      return false;
    }
    switch (refetchOnReconnect) {
      case RefetchOnReconnect.stale:
        if (state.data == null || state.dataUpdatedAt == null) {
          return true;
        }
        switch (staleDuration) {
          case StaleDurationValue():
            if (state.isInvalidated) {
              return true;
            }
            final age = clock.now().difference(state.dataUpdatedAt!);
            return age >= staleDuration;
          case StaleDurationInfinity():
            return state.isInvalidated;
          case StaleDurationStatic():
            return false;
        }
      case RefetchOnReconnect.never:
        return false;
      case RefetchOnReconnect.always:
        return true;
    }
  }

  QuerySnapshot<TData, TError> _buildResult(
    QueryOptions<TData, TError> options,
    QueryState<TData, TError> state, {
    bool optimistic = false,
  }) {
    final fetchStatus = optimistic && _shouldFetchOnMount(options, state)
        ? FetchStatus.fetching
        : state.fetchStatus;
    final isEnabled = options.enabled ?? true;
    final isStale = isEnabled &&
        _query.shouldFetch(options.staleDuration ?? StaleDuration.zero);
    final isFetchedAfterMount =
        state.dataUpdateCount > _initialDataUpdateCount ||
            state.errorUpdateCount > _initialErrorUpdateCount;

    final placeholderData = _resolvePlaceholder(options, state);

    _resultOptions = options;
    if (state.data != null) {
      _lastDefinedData = state.data;
    }

    switch (state.status) {
      case QueryStatus.pending:
        if (placeholderData != null) {
          return QuerySuccess<TData, TError>(
            data: placeholderData,
            isPlaceholder: true,
            fetchStatus: fetchStatus,
            dataUpdatedAt: state.dataUpdatedAt,
            dataUpdateCount: state.dataUpdateCount,
            errorUpdatedAt: state.errorUpdatedAt,
            errorUpdateCount: state.errorUpdateCount,
            failureCount: state.failureCount,
            failureReason: state.failureReason,
            isEnabled: isEnabled,
            isStale: isStale,
            isFetchedAfterMount: isFetchedAfterMount,
            refetch: refetch,
          );
        }
        return QueryPending<TData, TError>(
          fetchStatus: fetchStatus,
          dataUpdatedAt: state.dataUpdatedAt,
          dataUpdateCount: state.dataUpdateCount,
          errorUpdatedAt: state.errorUpdatedAt,
          errorUpdateCount: state.errorUpdateCount,
          failureCount: state.failureCount,
          failureReason: state.failureReason,
          isEnabled: isEnabled,
          isStale: isStale,
          isFetchedAfterMount: isFetchedAfterMount,
          refetch: refetch,
        );
      case QueryStatus.success:
        return QuerySuccess<TData, TError>(
          data: state.data as TData,
          isPlaceholder: false,
          fetchStatus: fetchStatus,
          dataUpdatedAt: state.dataUpdatedAt,
          dataUpdateCount: state.dataUpdateCount,
          errorUpdatedAt: state.errorUpdatedAt,
          errorUpdateCount: state.errorUpdateCount,
          failureCount: state.failureCount,
          failureReason: state.failureReason,
          isEnabled: isEnabled,
          isStale: isStale,
          isFetchedAfterMount: isFetchedAfterMount,
          refetch: refetch,
        );
      case QueryStatus.error:
        return QueryError<TData, TError>(
          error: state.error as TError,
          data: state.data,
          fetchStatus: fetchStatus,
          dataUpdatedAt: state.dataUpdatedAt,
          dataUpdateCount: state.dataUpdateCount,
          errorUpdatedAt: state.errorUpdatedAt,
          errorUpdateCount: state.errorUpdateCount,
          failureCount: state.failureCount,
          failureReason: state.failureReason,
          isEnabled: isEnabled,
          isStale: isStale,
          isFetchedAfterMount: isFetchedAfterMount,
          refetch: refetch,
        );
    }
  }

  TData? _resolvePlaceholder(
    QueryOptions<TData, TError> options,
    QueryState<TData, TError> state,
  ) {
    final placeholder = options.placeholder;
    if (placeholder == null ||
        state.status != QueryStatus.pending ||
        state.data != null) {
      return null;
    }

    // Memoize: while the placeholder option is unchanged, keep showing the
    // previously resolved data instead of re-invoking a lazy callback.
    final prevResult = _result;
    if (prevResult is QuerySuccess<TData, TError> &&
        prevResult.isPlaceholder &&
        placeholder == _resultOptions?.placeholder) {
      return prevResult.data;
    }

    return switch (placeholder) {
      PlaceholderValue<TData>(:final value) => value,
      PlaceholderLazy<TData>(:final resolve) => resolve(_lastDefinedData),
      PlaceholderKeepPrevious() => _lastDefinedData,
    };
  }
}
