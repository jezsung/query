import 'dart:async';

import 'package:clock/clock.dart';

import '../hooks/use_query.dart';
import 'options/gc_duration.dart';
import 'options/placeholder_data.dart';
import 'options/refetch_on_mount.dart';
import 'options/refetch_on_resume.dart';
import 'options/stale_duration.dart';
import 'query.dart';
import 'query_client.dart';
import 'query_key.dart';
import 'query_options.dart';

/// Callback type for result change listeners
typedef ResultChangeListener<TData, TError> = void Function(
    UseQueryResult<TData, TError> result);

class QueryObserver<TData, TError> {
  QueryObserver(
    QueryClient client,
    QueryOptions<TData, TError> options,
  )   : _client = client,
        _options = options.mergeWith(client.defaultQueryOptions),
        _query = client.cache.build<TData, TError>(
          options.mergeWith(client.defaultQueryOptions),
        ) {
    _query.setOptions(_options);
    _query.addObserver(this);

    if (_query.state.data != null) {
      _lastQueryWithDefinedData = _query;
    }

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
  QueryOptions<TData, TError> _options;
  Query<TData, TError> _query;
  late UseQueryResult<TData, TError> _result;

  /// Tracks the last query that had non-null data for placeholder data resolution.
  /// This is used when calling PlaceholderData.resolveWith() callbacks.
  Query<TData, TError>? _lastQueryWithDefinedData;

  /// Listeners that are notified when the result changes.
  /// Uses direct callback pattern instead of streams for synchronous updates.
  final Set<ResultChangeListener<TData, TError>> _listeners = {};

  /// Timer for refetchInterval. Continuously refetches at the specified interval.
  Timer? _refetchIntervalTimer;

  QueryOptions<TData, TError> get options => _options;
  UseQueryResult<TData, TError> get result => _result;

  /// Subscribe to result changes. Returns an unsubscribe function.
  void Function() subscribe(ResultChangeListener<TData, TError> listener) {
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  /// Called by Query when its state changes.
  ///
  /// Matches TanStack Query's pattern: Query notifies observers via direct method call,
  /// and Observer pulls the current state from Query.
  void onQueryUpdate() {
    // Track last query with defined data
    if (_query.state.data != null) {
      _lastQueryWithDefinedData = _query;
    }

    final result = _getResult();
    _setResult(result);
  }

  void updateOptions(QueryOptions<TData, TError> options) {
    final oldOptions = _options;
    final newOptions = options.mergeWith(_client.defaultQueryOptions);
    _options = newOptions;

    // Compare merged options to detect actual changes
    final didKeyChange =
        QueryKey(newOptions.queryKey) != QueryKey(oldOptions.queryKey);
    final didGcDurationChange = newOptions.gcDuration != oldOptions.gcDuration;
    final didEnabledChange = newOptions.enabled != oldOptions.enabled;
    final didPlaceholderDataChange =
        newOptions.placeholderData != oldOptions.placeholderData;
    final didRefetchIntervalChange =
        newOptions.refetchInterval != oldOptions.refetchInterval;
    final didRefetchOnMountChange =
        newOptions.refetchOnMount != oldOptions.refetchOnMount;
    final didRefetchOnResumeChange =
        newOptions.refetchOnResume != oldOptions.refetchOnResume;
    final didRetryChange = !identical(newOptions.retry, oldOptions.retry);
    final didRetryOnMountChange =
        newOptions.retryOnMount != oldOptions.retryOnMount;
    // Resolve staleDuration to concrete values before comparing
    final newStaleDuration = newOptions.staleDurationResolver != null
        ? newOptions.staleDurationResolver!(_query)
        : (newOptions.staleDuration ?? const StaleDuration());
    final oldStaleDuration = oldOptions.staleDurationResolver != null
        ? oldOptions.staleDurationResolver!(_query)
        : (oldOptions.staleDuration ?? const StaleDuration());
    final didStaleDurationChange = newStaleDuration != oldStaleDuration;

    // If nothing changed, return early
    if (!didKeyChange &&
        !didEnabledChange &&
        !didStaleDurationChange &&
        !didGcDurationChange &&
        !didPlaceholderDataChange &&
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
      _query.setOptions(newOptions);
      _query.addObserver(this);

      // Track last query with defined data
      if (_query.state.data != null) {
        _lastQueryWithDefinedData = _query;
      }

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

    // Update gcDuration if it changed
    if (didGcDurationChange) {
      final gcDuration = options.gcDuration ?? const GcDuration(minutes: 5);
      _query.updateGcDuration(gcDuration);
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

    if (didPlaceholderDataChange) {
      // Recalculate optimistic result to reflect new placeholder data
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

    // Handle retry option changes
    if (didRetryChange) {
      // Update query options (affects future fetches)
      _query.setOptions(newOptions);
    }

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

  void _setResult(UseQueryResult<TData, TError> newResult) {
    // Only notify if the result actually changed, preventing infinite loops
    if (newResult != _result) {
      _result = newResult;
      // Notify all listeners synchronously
      for (final listener in _listeners) {
        listener(_result);
      }
    }
  }

  UseQueryResult<TData, TError> _getResult({bool optimistic = false}) {
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

    // Use placeholderData if needed (when query is pending and has no data)
    if (options.placeholderData != null &&
        data == null &&
        status == QueryStatus.pending) {
      // Resolve placeholder data (handles both value and callback forms)
      final resolvedPlaceholderData = options.placeholderData!.resolve(
        _lastQueryWithDefinedData?.state.data,
        _lastQueryWithDefinedData,
      );

      if (resolvedPlaceholderData != null) {
        status = QueryStatus.success;
        data = resolvedPlaceholderData;
        isPlaceholderData = true;
      }
    }

    // Resolve staleDuration: resolver takes precedence over static value
    final staleDuration = options.staleDurationResolver != null
        ? options.staleDurationResolver!(_query)
        : (options.staleDuration ?? const StaleDuration());

    return UseQueryResult<TData, TError>(
      status: status,
      fetchStatus: fetchStatus,
      data: data,
      dataUpdatedAt: state.dataUpdatedAt,
      error: state.error,
      errorUpdatedAt: state.errorUpdatedAt,
      errorUpdateCount: state.errorUpdateCount,
      isEnabled: options.enabled ?? true,
      staleDuration: staleDuration,
      isPlaceholderData: isPlaceholderData,
      failureCount: state.failureCount,
      failureReason: state.failureReason,
      // isFetchedAfterMount: state.dataUpdatedAt != null, // Simplified for now
    );
  }

  bool _shouldFetchOnMount(
    QueryOptions<TData, TError> options,
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
    // Resolver takes precedence over static value
    final staleDuration = options.staleDurationResolver != null
        ? options.staleDurationResolver!(_query)
        : (options.staleDuration ?? const StaleDuration());

    // With static stale duration, data is always fresh and should never refetch automatically
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
      StaleDurationDuration duration => age >= duration,
      // If staleDuration is StaleDurationInfinity, never stale (unless invalidated)
      StaleDurationInfinity() => false,
      // If staleDuration is StaleDurationStatic, never stale
      StaleDurationStatic() => false,
    };
  }

  bool _shouldFetchOnResume(
    QueryOptions<TData, TError> options,
    QueryState<TData, TError> state,
  ) {
    final enabled = options.enabled ?? true;
    final refetchOnResume = options.refetchOnResume ?? RefetchOnResume.stale;

    if (!enabled) return false;

    // Resolver takes precedence over static value
    final staleDuration = options.staleDurationResolver != null
        ? options.staleDurationResolver!(_query)
        : (options.staleDuration ?? const StaleDuration());

    // With static stale duration, data is always fresh and should never refetch automatically
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
      StaleDurationDuration duration => age >= duration,
      StaleDurationInfinity() => false,
      StaleDurationStatic() => false,
    };
  }
}
