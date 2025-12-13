import 'dart:async';

import 'package:clock/clock.dart';

import '../hooks/use_query.dart';
import 'options/gc_duration.dart';
import 'options/stale_duration.dart';
import 'query.dart';
import 'query_client.dart';
import 'query_key.dart';

class QueryObserver<TData, TError> {
  QueryObserver(this.client, this.options) {
    // Get or create query using cache.build()
    _query = client.cache.build<TData, TError>(options);

    // Set options on the query (will set initialData if query has no data)
    _query.setOptions(options);

    // Register this observer with the query
    // This will clear any pending gc timeout
    _query.addObserver(this);

    // Get initial optimistic result
    _result = _getOptimisticResult();

    // Trigger initial fetch if enabled and (no data or data is stale)
    if (options.enabled && _shouldFetchOnMount(_query.state)) {
      _query.fetch();
    }
  }

  final QueryClient client;
  QueryOptions<TData, TError> options;

  late Query<TData, TError> _query;

  final _controller =
      StreamController<UseQueryResult<TData, TError>>.broadcast();
  Stream<UseQueryResult<TData, TError>> get onResultChange =>
      _controller.stream;

  late UseQueryResult<TData, TError> _result;
  UseQueryResult<TData, TError> get result => _result;

  /// Called by Query when its state changes.
  ///
  /// Matches TanStack Query's pattern: Query notifies observers via direct method call,
  /// and Observer pulls the current state from Query.
  void onQueryUpdate() {
    _updateResult();
  }

  void updateOptions(QueryOptions<TData, TError> newOptions) {
    final didKeyChange =
        QueryKey(newOptions.queryKey) != QueryKey(options.queryKey);
    final didEnabledChange = newOptions.enabled != options.enabled;
    final didGcDurationChange = newOptions.gcDuration != options.gcDuration;
    final didPlaceholderDataChange =
        newOptions.placeholderData != options.placeholderData;

    // Resolve staleDuration to concrete values before comparing
    final newResolvedDuration = switch (newOptions.staleDuration) {
      StaleDurationValue value => value,
      StaleDurationProvider(:final resolve) => resolve(_query),
    };
    final oldResolvedDuration = switch (options.staleDuration) {
      StaleDurationValue value => value,
      StaleDurationProvider(:final resolve) => resolve(_query),
    };
    final didStaleDurationChange = newResolvedDuration != oldResolvedDuration;

    // If nothing changed, return early
    if (!didKeyChange &&
        !didEnabledChange &&
        !didStaleDurationChange &&
        !didGcDurationChange &&
        !didPlaceholderDataChange) {
      return;
    }

    // Update options
    options = newOptions;

    // Update gcDuration if it changed
    if (didGcDurationChange) {
      _query.updateGcDuration(newOptions.gcDuration);
    }

    if (didKeyChange) {
      final oldQuery = _query;

      // Get or create query using cache.build()
      _query = client.cache.build<TData, TError>(newOptions);

      // Set options on the query (will set initialData if query has no data)
      _query.setOptions(newOptions);

      // Register with new query
      _query.addObserver(this);

      // Get optimistic result
      _result = _getOptimisticResult();
      _controller.add(_result);

      // Trigger initial fetch if enabled and (no data or data is stale)
      if (newOptions.enabled && _shouldFetchOnMount(_query.state)) {
        _query.fetch();
      }

      // Remove this observer from the old query
      // This will schedule GC if it was the last observer
      oldQuery.removeObserver(this);
    }

    if (didEnabledChange) {
      // Update enabled state - get optimistic result and notify
      _result = _getOptimisticResult();
      _controller.add(_result);

      if (newOptions.enabled && _shouldFetchOnMount(_query.state)) {
        _query.fetch();
      }
    }

    if (didStaleDurationChange) {
      // Update staleDuration - recalculate result to update isStale getter
      _result = _getOptimisticResult();
      _controller.add(_result);

      // If data becomes stale with the new staleDuration, trigger a refetch
      if (newOptions.enabled && _shouldFetchOnMount(_query.state)) {
        _query.fetch();
      }
    }

    if (didPlaceholderDataChange &&
        !didEnabledChange &&
        !didStaleDurationChange) {
      // Recalculate optimistic result to reflect new placeholder data
      _result = _getOptimisticResult();
      _controller.add(_result);
    }
  }

  void dispose() {
    _controller.close();

    // Remove this observer from the query
    // This will schedule GC if it was the last observer
    _query.removeObserver(this);
  }

  UseQueryResult<TData, TError> _getOptimisticResult() {
    final state = _query.state;

    // Check if we should fetch on mount (enabled and (no data or stale))
    final shouldFetch = options.enabled && _shouldFetchOnMount(state);

    var status = state.status;
    var data = state.data;
    var isPlaceholderData = false;

    if (options.placeholderData != null &&
        data == null &&
        status == QueryStatus.pending) {
      status = QueryStatus.success;
      data = options.placeholderData;
      isPlaceholderData = true;
    }

    // Return optimistic result with fetchStatus set to 'fetching' if we're about to fetch
    return UseQueryResult<TData, TError>(
      status: status,
      fetchStatus: shouldFetch ? FetchStatus.fetching : state.fetchStatus,
      data: data,
      dataUpdatedAt: state.dataUpdatedAt,
      error: state.error,
      errorUpdatedAt: state.errorUpdatedAt,
      errorUpdateCount: state.errorUpdateCount,
      isEnabled: options.enabled,
      staleDuration: options.staleDuration.resolve(_query),
      isPlaceholderData: isPlaceholderData,
    );
  }

  bool _shouldFetchOnMount(QueryState<TData, TError> state) {
    // No data - always fetch
    if (state.data == null) return true;

    // Has data - check if stale
    // No dataUpdatedAt - consider stale
    if (state.dataUpdatedAt == null) return true;

    final age = clock.now().difference(state.dataUpdatedAt!);
    final staleDuration = options.staleDuration.resolve(_query);

    return switch (staleDuration) {
      // Check if age exceeds or equals staleDuration (>= for zero staleDuration)
      StaleDuration duration => age >= duration,
      // If staleDuration is StaleDurationInfinity, never stale (unless invalidated)
      StaleDurationInfinity() => false,
      // If staleDuration is StaleDurationStatic, never stale
      StaleDurationStatic() => false,
    };
  }

  void _updateResult() {
    // Pull fresh state from query
    final state = _query.state;

    var status = state.status;
    var data = state.data;
    var isPlaceholderData = false;

    if (options.placeholderData != null &&
        data == null &&
        status == QueryStatus.pending) {
      status = QueryStatus.success;
      data = options.placeholderData;
      isPlaceholderData = true;
    }

    final result = UseQueryResult<TData, TError>(
      status: status,
      fetchStatus: state.fetchStatus,
      data: data,
      dataUpdatedAt: state.dataUpdatedAt,
      error: state.error,
      errorUpdatedAt: state.errorUpdatedAt,
      errorUpdateCount: state.errorUpdateCount,
      isEnabled: options.enabled,
      staleDuration: options.staleDuration.resolve(_query),
      isPlaceholderData: isPlaceholderData,
      // failureCount: state.failureCount,
      // failureReason: state.failureReason,
      // isFetchedAfterMount: state.dataUpdatedAt != null, // Simplified for now
      // isPlaceholderData: false, // Not implemented yet
    );
    _result = result;
    _controller.add(result);
  }
}

class QueryOptions<TData, TError> {
  const QueryOptions(
    this.queryKey,
    this.queryFn, {
    this.enabled = true,
    this.staleDuration = StaleDuration.zero,
    this.gcDuration = const GcDuration(minutes: 5),
    this.initialData,
    this.initialDataUpdatedAt,
    this.placeholderData,
  });

  final List<Object?> queryKey;
  final Future<TData> Function() queryFn;
  final bool enabled;
  final StaleDurationOption staleDuration;

  /// The duration that unused/inactive cache data remains in memory.
  /// When a query's cache becomes unused or inactive, that cache data will be
  /// garbage collected after this duration.
  /// When different garbage collection durations are specified, the longest one will be used.
  /// Use [GcDuration.infinity] to disable garbage collection.
  final GcDurationOption gcDuration;

  /// Initial data to use for the query.
  /// If provided, the query will start with status 'success' and this data.
  final TData? initialData;

  /// Timestamp for when the initial data was created.
  /// If not provided when initialData is set, defaults to the current time.
  final DateTime? initialDataUpdatedAt;

  /// Data to show while the query is pending and has no data.
  ///
  /// Only the direct value variant is currently supported (no function form).
  final TData? placeholderData;
}
