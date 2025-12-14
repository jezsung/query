import 'dart:async';

import 'package:clock/clock.dart';

import '../hooks/use_query.dart';
import 'options/gc_duration.dart';
import 'options/placeholder_data.dart';
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

    // Track last query with defined data
    if (_query.state.data != null) {
      _lastQueryWithDefinedData = _query;
    }

    // Get initial optimistic result
    _result = _getResult(optimistic: true);

    // Trigger initial fetch if enabled and (no data or data is stale)
    if (_shouldFetchOnMount(options, _query.state)) {
      _query.fetch();
    }
  }

  final QueryClient client;
  QueryOptions<TData, TError> options;

  late Query<TData, TError> _query;
  late UseQueryResult<TData, TError> _result;

  /// Tracks the last query that had non-null data for placeholder data resolution.
  /// This is used when calling PlaceholderData.resolveWith() callbacks.
  Query<TData, TError>? _lastQueryWithDefinedData;

  final _controller =
      StreamController<UseQueryResult<TData, TError>>.broadcast();
  Stream<UseQueryResult<TData, TError>> get onResultChange =>
      _controller.stream;
  UseQueryResult<TData, TError> get result => _result;

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

  void updateOptions(final QueryOptions<TData, TError> newOptions) {
    final oldOptions = options;
    options = newOptions;

    final didKeyChange =
        QueryKey(newOptions.queryKey) != QueryKey(oldOptions.queryKey);
    final didGcDurationChange = newOptions.gcDuration != oldOptions.gcDuration;
    final didEnabledChange = newOptions.enabled != oldOptions.enabled;
    final didPlaceholderDataChange =
        newOptions.placeholderData != oldOptions.placeholderData;
    // Resolve staleDuration to concrete values before comparing
    final newStaleDuration = newOptions.staleDuration.resolve(_query);
    final oldStaleDuration = oldOptions.staleDuration.resolve(_query);
    final didStaleDurationChange = newStaleDuration != oldStaleDuration;

    // If nothing changed, return early
    if (!didKeyChange &&
        !didEnabledChange &&
        !didStaleDurationChange &&
        !didGcDurationChange &&
        !didPlaceholderDataChange) {
      return;
    }

    if (didKeyChange) {
      final oldQuery = _query;

      // Get or create query using cache.build()
      _query = client.cache.build<TData, TError>(newOptions);

      // Set options on the query (will set initialData if query has no data)
      _query.setOptions(newOptions);

      // Register with new query
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
        _query.fetch();
      }

      // Remove this observer from the old query
      // This will schedule GC if it was the last observer
      oldQuery.removeObserver(this);

      return;
    }

    // Update gcDuration if it changed
    if (didGcDurationChange) {
      _query.updateGcDuration(newOptions.gcDuration);
    }

    if (didEnabledChange) {
      // Update enabled state - get optimistic result and notify
      final result = _getResult(optimistic: true);
      _setResult(result);

      if (_shouldFetchOnMount(newOptions, _query.state)) {
        _query.fetch();
      }
    }

    if (didPlaceholderDataChange) {
      // Recalculate optimistic result to reflect new placeholder data
      final result = _getResult(optimistic: true);
      _setResult(result);
    }

    if (didStaleDurationChange) {
      // Update staleDuration - recalculate result to update isStale getter
      final result = _getResult(optimistic: true);
      _setResult(result);

      // If data becomes stale with the new staleDuration, trigger refetch
      if (_shouldFetchOnMount(newOptions, _query.state)) {
        _query.fetch();
      }
    }
  }

  void dispose() {
    _controller.close();

    // Remove this observer from the query
    // This will schedule GC if it was the last observer
    _query.removeObserver(this);
  }

  void _setResult(UseQueryResult<TData, TError> newResult) {
    // Only emit if the result actually changed, preventing infinite loops
    if (newResult != _result) {
      _result = newResult;
      _controller.add(_result);
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

    return UseQueryResult<TData, TError>(
      status: status,
      fetchStatus: fetchStatus,
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
    );
  }

  bool _shouldFetchOnMount(
    QueryOptions<TData, TError> options,
    QueryState<TData, TError> state,
  ) {
    if (!options.enabled) {
      return false;
    }
    if (state.data == null || state.dataUpdatedAt == null) {
      return true;
    }

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
}

class QueryOptions<TData, TError> {
  const QueryOptions(
    this.queryKey,
    this.queryFn, {
    this.enabled = true,
    this.gcDuration = const GcDuration(minutes: 5),
    this.initialData,
    this.initialDataUpdatedAt,
    this.placeholderData,
    this.staleDuration = StaleDuration.zero,
  });

  final List<Object?> queryKey;
  final Future<TData> Function() queryFn;
  final GcDurationOption gcDuration;
  final bool enabled;
  final TData? initialData;
  final DateTime? initialDataUpdatedAt;
  final PlaceholderData<TData, TError>? placeholderData;
  final StaleDurationOption staleDuration;
}
