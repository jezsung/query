import 'dart:async';

import 'package:clock/clock.dart';

import '../hooks/use_query.dart';
import 'query.dart';
import 'query_client.dart';
import 'query_key.dart';

class QueryObserver<TData, TError> {
  QueryObserver(this.client, this.options) {
    _query = client.cache.buildQuery<TData>(
      options.queryKey,
      options.queryFn,
    );
    // Subscribe to query state changes
    _stateSubscription = _query.onStateChange.listen((state) {
      _updateResult(state);
    });

    // Get initial optimistic result
    _result = _getOptimisticResult();

    // Trigger initial fetch if enabled and (no data or data is stale)
    if (options.enabled && _shouldFetchOnMount(_query.state)) {
      _query.fetch();
    }
  }

  final QueryClient client;
  QueryOptions<TData> options;

  late StreamSubscription<QueryState<TData>> _stateSubscription;
  late Query<TData> _query;

  final _controller =
      StreamController<UseQueryResult<TData, TError>>.broadcast();
  Stream<UseQueryResult<TData, TError>> get onResultChange =>
      _controller.stream;

  late UseQueryResult<TData, TError> _result;
  UseQueryResult<TData, TError> get result => _result;

  void updateOptions(QueryOptions<TData> newOptions) {
    final didKeyChange =
        QueryKey(newOptions.queryKey) != QueryKey(options.queryKey);
    final didEnabledChange = newOptions.enabled != options.enabled;
    final didStaleTimeChange = newOptions.staleTime != options.staleTime;

    // If nothing changed, return early
    if (!didKeyChange && !didEnabledChange && !didStaleTimeChange) {
      return;
    }

    // Update options
    options = newOptions;

    if (didKeyChange) {
      // Query key changed - need to switch to a different query
      _query = client.cache.buildQuery<TData>(
        newOptions.queryKey,
        newOptions.queryFn,
      );

      // Subscribe to new query state changes
      _stateSubscription.cancel();
      _stateSubscription = _query.onStateChange.listen((state) {
        _updateResult(state);
      });

      // Get optimistic result
      _result = _getOptimisticResult();
      _controller.add(_result);

      // Trigger initial fetch if enabled and (no data or data is stale)
      if (newOptions.enabled && _shouldFetchOnMount(_query.state)) {
        _query.fetch();
      }
    }

    if (didEnabledChange) {
      // Update enabled state - get optimistic result and notify
      _result = _getOptimisticResult();
      _controller.add(_result);

      if (newOptions.enabled && _shouldFetchOnMount(_query.state)) {
        _query.fetch();
      }
    }

    if (didStaleTimeChange) {
      // Update staleTime - recalculate result to update isStale getter
      _result = _getOptimisticResult();
      _controller.add(_result);

      // If data becomes stale with the new staleTime, trigger a refetch
      if (newOptions.enabled && _shouldFetchOnMount(_query.state)) {
        _query.fetch();
      }
    }
  }

  void dispose() {
    _stateSubscription.cancel();
    _controller.close();
  }

  UseQueryResult<TData, TError> _getOptimisticResult() {
    final state = _query.state;

    // Check if we should fetch on mount (enabled and (no data or stale))
    final shouldFetch = options.enabled && _shouldFetchOnMount(state);

    // Return optimistic result with fetchStatus set to 'fetching' if we're about to fetch
    return UseQueryResult<TData, TError>(
      status: state.status,
      fetchStatus: shouldFetch ? FetchStatus.fetching : state.fetchStatus,
      data: state.data,
      dataUpdatedAt: state.dataUpdatedAt,
      error: state.error as TError?,
      errorUpdatedAt: state.errorUpdatedAt,
      errorUpdateCount: state.errorUpdateCount,
      isEnabled: options.enabled,
      staleTime: options.staleTime,
    );
  }

  bool _shouldFetchOnMount(QueryState<TData> state) {
    // No data - always fetch
    if (state.data == null) return true;

    // Has data - check if stale
    // No dataUpdatedAt - consider stale
    if (state.dataUpdatedAt == null) return true;

    // Check if data age exceeds staleTime
    final age = clock.now().difference(state.dataUpdatedAt!);
    return age > options.staleTime;
  }

  void _updateResult(QueryState<TData> state) {
    final result = UseQueryResult<TData, TError>(
      status: state.status,
      fetchStatus: state.fetchStatus,
      data: state.data,
      dataUpdatedAt: state.dataUpdatedAt,
      error: state.error as TError?,
      errorUpdatedAt: state.errorUpdatedAt,
      errorUpdateCount: state.errorUpdateCount,
      isEnabled: options.enabled,
      staleTime: options.staleTime,
      // failureCount: state.failureCount,
      // failureReason: state.failureReason as TError?,
      // isFetchedAfterMount: state.dataUpdatedAt != null, // Simplified for now
      // isPlaceholderData: false, // Not implemented yet
    );
    _result = result;
    _controller.add(result);
  }
}

class QueryOptions<TData> {
  const QueryOptions({
    required this.queryKey,
    required this.queryFn,
    this.enabled = true,
    this.staleTime = Duration.zero,
  });

  final List<Object?> queryKey;
  final Future<TData> Function() queryFn;
  final bool enabled;
  final Duration staleTime;
}
