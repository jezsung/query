import 'dart:async';
import 'dart:math';

import 'package:clock/clock.dart';

import 'infinite_data.dart';
import 'infinite_query_function_context.dart';
import 'infinite_query_observer_options.dart';
import 'infinite_query_result.dart';
import 'observable.dart';
import 'options/refetch_on_mount.dart';
import 'options/refetch_on_resume.dart';
import 'options/stale_duration.dart';
import 'query.dart';
import 'query_client.dart';
import 'query_function_context.dart';
import 'query_options.dart';
import 'query_result.dart';
import 'query_state.dart';

part 'infinite_query_observer.dart';

/// Callback type for result change listeners
typedef ResultChangeListener<TData, TError> = void Function(
    QueryResult<TData, TError> result);

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

    // Trigger initial fetch if enabled and (no data or data is stale)
    if (_shouldFetchOnMount(_options, _query.state)) {
      // Ignore result and errors - they're handled via query state
      _query.fetch().ignore();
    }

    // Start refetch interval if configured
    _updateRefetchInterval();
  }

  final QueryClient _client;
  QueryObserverOptions<TData, TError> _options;
  Query<TData, TError> _query;
  late QueryResult<TData, TError> _result;

  /// Tracks the initial dataUpdateCount when observer was created.
  /// Used to compute isFetchedAfterMount.
  late int _initialDataUpdateCount;

  /// Tracks the initial errorUpdateCount when observer was created.
  /// Used to compute isFetchedAfterMount.
  late int _initialErrorUpdateCount;

  /// Listeners that are notified when the result changes.
  /// Uses direct callback pattern instead of streams for synchronous updates.
  final Set<ResultChangeListener<TData, TError>> _listeners = {};

  /// Timer for refetchInterval. Continuously refetches at the specified interval.
  Timer? _refetchIntervalTimer;

  QueryObserverOptions<TData, TError> get options => _options;
  QueryResult<TData, TError> get result => _result;

  /// Subscribe to result changes. Returns an unsubscribe function.
  void Function() subscribe(ResultChangeListener<TData, TError> listener) {
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  /// Called by Query when its state changes.
  @override
  void onNotified(QueryState<TData, TError> newState) {
    final result = _getResult();
    _setResult(result);
  }

  void updateOptions(QueryObserverOptions<TData, TError> options) {
    final oldOptions = _options;
    final newOptions = options.withDefaults(_client.defaultQueryOptions);
    _options = newOptions;

    // Compare merged options to detect actual changes
    final didKeyChange = newOptions.queryKey != oldOptions.queryKey;
    final didEnabledChange = newOptions.enabled != oldOptions.enabled;
    final didPlaceholderChange =
        newOptions.placeholder != oldOptions.placeholder;
    final didRefetchIntervalChange =
        newOptions.refetchInterval != oldOptions.refetchInterval;
    final didRefetchOnMountChange =
        newOptions.refetchOnMount != oldOptions.refetchOnMount;
    final didRefetchOnResumeChange =
        newOptions.refetchOnResume != oldOptions.refetchOnResume;
    final didRetryChange = !identical(newOptions.retry, oldOptions.retry);
    final didRetryOnMountChange =
        newOptions.retryOnMount != oldOptions.retryOnMount;
    final didStaleDurationChange =
        newOptions.staleDuration != oldOptions.staleDuration;

    // If nothing changed, return early
    if (!didKeyChange &&
        !didEnabledChange &&
        !didStaleDurationChange &&
        !didPlaceholderChange &&
        !didRefetchIntervalChange &&
        !didRefetchOnMountChange &&
        !didRefetchOnResumeChange &&
        !didRetryChange &&
        !didRetryOnMountChange) {
      return;
    }

    if (didKeyChange) {
      final oldQuery = _query;

      _query = _client.cache.build<TData, TError>(newOptions);
      _query.addObserver(this);

      // Reset initial counters for the new query (for isFetchedAfterMount)
      _initialDataUpdateCount = _query.state.dataUpdateCount;
      _initialErrorUpdateCount = _query.state.errorUpdateCount;

      // Get optimistic result
      final result = _getResult(optimistic: true);
      _setResult(result);

      // Trigger initial fetch if enabled and (no data or data is stale)
      if (_shouldFetchOnMount(newOptions, _query.state)) {
        // Ignore result and errors - they're handled via query state
        _query.fetch().ignore();
      }

      // Update refetch interval for new query
      _updateRefetchInterval();

      // Remove this observer from the old query
      // This will schedule GC if it was the last observer
      oldQuery.removeObserver(this);

      return;
    }

    if (didEnabledChange) {
      // Update enabled state - get optimistic result and notify
      final result = _getResult(optimistic: true);
      _setResult(result);

      if (_shouldFetchOnMount(newOptions, _query.state)) {
        // Ignore result and errors - they're handled via query state
        _query.fetch().ignore();
      }
    }

    if (didPlaceholderChange) {
      // Recalculate optimistic result to reflect new placeholder
      final result = _getResult(optimistic: true);
      _setResult(result);
    }

    if (didRefetchOnMountChange) {
      // Refetch behavior on mount changed - recompute result and maybe refetch
      final result = _getResult(optimistic: true);
      _setResult(result);

      if (_shouldFetchOnMount(newOptions, _query.state)) {
        // Ignore result and errors - they're handled via query state
        _query.fetch().ignore();
      }
    }

    if (didRefetchOnResumeChange) {
      // Update optimistic result for refetchOnResume changes
      final result = _getResult(optimistic: true);
      _setResult(result);
    }

    if (didStaleDurationChange) {
      // Update staleDuration - recalculate result to update isStale getter
      final result = _getResult(optimistic: true);
      _setResult(result);

      // If data becomes stale with the new staleDuration, trigger refetch
      if (_shouldFetchOnMount(newOptions, _query.state)) {
        // Ignore errors - they're handled via query state
        _query.fetch().ignore();
      }
    }

    // // Handle retry option changes
    // if (didRetryChange) {
    //   // Update query options (affects future fetches)
    //   _query.options = newOptions;
    // }

    if (didRetryOnMountChange) {
      // Recalculate result and maybe refetch
      final result = _getResult(optimistic: true);
      _setResult(result);

      if (_shouldFetchOnMount(newOptions, _query.state)) {
        // Ignore errors - they're handled via query state
        _query.fetch().ignore();
      }
    }

    // Update refetch interval if it changed or if enabled changed
    if (didRefetchIntervalChange || didEnabledChange) {
      _updateRefetchInterval();
    }
  }

  /// Called when the app lifecycle returns to resumed state.
  void onResume() {
    if (_shouldFetchOnResume(options, _query.state)) {
      // Ignore errors - they're handled via query state
      _query.fetch().ignore();
    }
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

  void dispose() {
    _listeners.clear();
    _cancelRefetchInterval();

    // Remove this observer from the query
    // This will schedule GC if it was the last observer
    _query.removeObserver(this);
  }

  void _updateRefetchInterval() {
    _cancelRefetchInterval();

    // Don't set up interval if:
    // - Query is disabled
    // - No refetchInterval is configured
    // - refetchInterval is zero/negative
    if (!(options.enabled ?? true) ||
        options.refetchInterval == null ||
        options.refetchInterval!.inMilliseconds <= 0) {
      return;
    }

    _refetchIntervalTimer = Timer.periodic(
      options.refetchInterval!,
      (_) {
        // Ignore errors - they're handled via query state
        _query.fetch().ignore();
      },
    );
  }

  void _cancelRefetchInterval() {
    _refetchIntervalTimer?.cancel();
    _refetchIntervalTimer = null;
  }

  void _setResult(QueryResult<TData, TError> newResult) {
    // Only notify if the result actually changed, preventing infinite loops
    if (newResult != _result) {
      _result = newResult;
      // Notify all listeners synchronously
      for (final listener in _listeners) {
        listener(_result);
      }
    }
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
      fetchStatus = _shouldFetchOnMount(options, state)
          ? FetchStatus.fetching
          : state.fetchStatus;
    }

    // Use placeholder if needed (when query is pending and has no data)
    if (options.placeholder != null &&
        data == null &&
        status == QueryStatus.pending) {
      status = QueryStatus.success;
      data = options.placeholder;
      isPlaceholderData = true;
    }

    final staleDuration = options.staleDuration ?? const StaleDuration();

    // Compute isStale: disabled queries are never considered stale
    // This matches TanStack Query's behavior
    final isEnabled = options.enabled ?? true;
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
