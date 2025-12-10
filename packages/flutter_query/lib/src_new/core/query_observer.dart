import 'dart:async';

import 'package:clock/clock.dart';

import '../hooks/use_query.dart';
import 'query.dart';
import 'query_client.dart';
import 'query_key.dart';

class QueryObserver<TData, TError> {
  QueryObserver(this.client, this.options) {
    _query = client.cache.build<TData, TError>(
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
  QueryOptions<TData, TError> options;

  late StreamSubscription<QueryState<TData, TError>> _stateSubscription;
  late Query<TData, TError> _query;

  final _controller =
      StreamController<UseQueryResult<TData, TError>>.broadcast();
  Stream<UseQueryResult<TData, TError>> get onResultChange =>
      _controller.stream;

  late UseQueryResult<TData, TError> _result;
  UseQueryResult<TData, TError> get result => _result;

  void updateOptions(QueryOptions<TData, TError> newOptions) {
    final didKeyChange =
        QueryKey(newOptions.queryKey) != QueryKey(options.queryKey);
    final didEnabledChange = newOptions.enabled != options.enabled;

    // Resolve staleDuration to concrete values before comparing
    final newResolvedDuration = switch (newOptions.staleDuration) {
      StaleDurationValue value => value,
      StaleDurationResolver(:final resolve) => resolve(_query),
    };
    final oldResolvedDuration = switch (options.staleDuration) {
      StaleDurationValue value => value,
      StaleDurationResolver(:final resolve) => resolve(_query),
    };
    final didStaleDurationChange = newResolvedDuration != oldResolvedDuration;

    // If nothing changed, return early
    if (!didKeyChange && !didEnabledChange && !didStaleDurationChange) {
      return;
    }

    // Update options
    options = newOptions;

    if (didKeyChange) {
      // Query key changed - need to switch to a different query
      _query = client.cache.build<TData, TError>(
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

    if (didStaleDurationChange) {
      // Update staleDuration - recalculate result to update isStale getter
      _result = _getOptimisticResult();
      _controller.add(_result);

      // If data becomes stale with the new staleDuration, trigger a refetch
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

    // Resolve staleDuration to concrete value
    final staleDuration = switch (options.staleDuration) {
      StaleDurationValue value => value,
      StaleDurationResolver(:final resolve) => resolve(_query),
    };

    // Check if we should fetch on mount (enabled and (no data or stale))
    final shouldFetch = options.enabled && _shouldFetchOnMount(state);

    // Return optimistic result with fetchStatus set to 'fetching' if we're about to fetch
    return UseQueryResult<TData, TError>(
      status: state.status,
      fetchStatus: shouldFetch ? FetchStatus.fetching : state.fetchStatus,
      data: state.data,
      dataUpdatedAt: state.dataUpdatedAt,
      error: state.error,
      errorUpdatedAt: state.errorUpdatedAt,
      errorUpdateCount: state.errorUpdateCount,
      isEnabled: options.enabled,
      staleDuration: staleDuration,
    );
  }

  bool _shouldFetchOnMount(QueryState<TData, TError> state) {
    // No data - always fetch
    if (state.data == null) return true;

    // Has data - check if stale
    // No dataUpdatedAt - consider stale
    if (state.dataUpdatedAt == null) return true;

    // Resolve staleDuration to concrete value
    final staleDuration = switch (options.staleDuration) {
      StaleDurationValue value => value,
      StaleDurationResolver(:final resolve) => resolve(_query),
    };

    final age = clock.now().difference(state.dataUpdatedAt!);
    return switch (staleDuration) {
      // Check if age exceeds staleDuration
      StaleDuration duration => age > duration,
      // If staleDuration is StaleDurationInfinity, never stale (unless invalidated)
      StaleDurationInfinity() => false,
      // If staleDuration is StaleDurationStatic, never stale
      StaleDurationStatic() => false,
    };
  }

  void _updateResult(QueryState<TData, TError> state) {
    // Resolve staleDuration to concrete value
    final staleDuration = switch (options.staleDuration) {
      StaleDurationValue value => value,
      StaleDurationResolver(:final resolve) => resolve(_query),
    };

    final result = UseQueryResult<TData, TError>(
      status: state.status,
      fetchStatus: state.fetchStatus,
      data: state.data,
      dataUpdatedAt: state.dataUpdatedAt,
      error: state.error,
      errorUpdatedAt: state.errorUpdatedAt,
      errorUpdateCount: state.errorUpdateCount,
      isEnabled: options.enabled,
      staleDuration: staleDuration,
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
  const QueryOptions({
    required this.queryKey,
    required this.queryFn,
    this.enabled = true,
    this.staleDuration = StaleDuration.zero,
  });

  final List<Object?> queryKey;
  final Future<TData> Function() queryFn;
  final bool enabled;
  final StaleDurationBase staleDuration;
}
