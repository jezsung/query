import 'dart:async';

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

    // Trigger initial fetch if enabled and no data
    if (options.enabled && _query.state.data == null) {
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

    // If nothing changed, return early
    if (!didKeyChange && !didEnabledChange) {
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

      // Trigger initial fetch if enabled and no data
      if (newOptions.enabled && _query.state.data == null) {
        _query.fetch();
      }
    }

    if (didEnabledChange) {
      // Update enabled state - get optimistic result and notify
      _result = _getOptimisticResult();
      _controller.add(_result);

      if (newOptions.enabled && _query.state.data == null) {
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

    // Check if we should fetch on mount (enabled and no data)
    final shouldFetch = options.enabled && state.data == null;

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
    );
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
      // failureCount: state.failureCount,
      // failureReason: state.failureReason as TError?,
      // isFetchedAfterMount: state.dataUpdatedAt != null, // Simplified for now
      // isPlaceholderData: false, // Not implemented yet
      // isStale: false, // Not implemented yet
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
  });

  final List<Object?> queryKey;
  final Future<TData> Function() queryFn;
  final bool enabled;
}
