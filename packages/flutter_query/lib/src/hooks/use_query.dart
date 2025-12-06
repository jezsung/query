import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_query/flutter_query.dart';

import '../core/core.dart';

enum RefetchBehavior {
  never,
  stale,
  always,
}

class QueryResult<T> {
  QueryResult({
    required this.state,
    required this.refetch,
    required this.cancel,
  });

  final QueryState<T> state;
  final Future<void> Function() refetch;
  final Future<void> Function() cancel;
}

class QueryOptions<T, K> {
  QueryOptions({
    required this.key,
    required this.fetcher,
    required this.enabled,
    required this.initialData,
    required this.initialDataUpdatedAt,
    required this.placeholder,
    required this.staleDuration,
    required this.gcDuration,
    required this.refetchOnInit,
    required this.refetchOnResumed,
  });

  final QueryKey<K> key;
  final QueryFetcher<T, K> fetcher;
  final bool enabled;
  final T? initialData;
  final DateTime? initialDataUpdatedAt;
  final T? placeholder;
  final Duration staleDuration;
  final Duration gcDuration;
  final RefetchBehavior refetchOnInit;
  final RefetchBehavior refetchOnResumed;
}

QueryResult<T> useQuery<T, K>(
  QueryKey<K> key,
  QueryFetcher<T, K> fetcher, {
  bool enabled = true,
  T? initialData,
  DateTime? initialDataUpdatedAt,
  T? placeholder,
  Duration staleDuration = Duration.zero,
  Duration gcDuration = const Duration(minutes: 5),
  RefetchBehavior refetchOnInit = RefetchBehavior.stale,
  RefetchBehavior refetchOnResumed = RefetchBehavior.stale,
}) {
  final client = useQueryClient();
  final query = useMemoized(
    () {
      final query_ = client.cache.buildQuery<T, K>(key);

      if (initialData != null) {
        query_.setInitialData(initialData, initialDataUpdatedAt);
      }

      return query_;
    },
    [key, client],
  );
  final queryOptions = useMemoized(
    () => QueryOptions<T, K>(
      key: key,
      fetcher: fetcher,
      enabled: enabled,
      initialData: initialData,
      initialDataUpdatedAt: initialDataUpdatedAt,
      placeholder: placeholder,
      staleDuration: staleDuration,
      gcDuration: gcDuration,
      refetchOnInit: refetchOnInit,
      refetchOnResumed: refetchOnResumed,
    ),
    [
      key,
      fetcher,
      enabled,
      initialData,
      initialDataUpdatedAt,
      placeholder,
      staleDuration,
      gcDuration,
      refetchOnInit,
      refetchOnResumed,
    ],
  );
  final stateSnapshot = useStream(
    useMemoized(
      () => query.stream.map(
        (state) => state.copyWith(
          data: state.hasData ? state.data : placeholder,
        ),
      ),
      [query],
    ),
    initialData: query.state.copyWith(
      status: query.state.status.isIdle && enabled
          ? QueryStatus.fetching
          : query.state.status,
      data: query.state.hasData ? query.state.data : placeholder,
    ),
    preserveState: false,
  );

  useEffect(
    () {
      client.cache.cancelGc(key);
      return () {
        final options = client.getQueryOptions(key);
        if (options == null || options.isEmpty) {
          client.cache.scheduleGc(key, gcDuration);
        }
      };
    },
    [client, key],
  );

  useEffect(
    () {
      client.addQueryOptions(queryOptions);
      return () {
        client.removeQueryOptions(queryOptions);
      };
    },
    [client, queryOptions],
  );

  useEffect(
    () {
      if (!enabled || query.state.status.isFetching) return;

      if (query.state.status.isIdle) {
        query.fetch(
          fetcher: fetcher,
          staleDuration: staleDuration,
        );
      } else {
        switch (refetchOnInit) {
          case RefetchBehavior.never:
            break;
          case RefetchBehavior.stale:
            query.fetch(
              fetcher: fetcher,
              staleDuration: staleDuration,
            );
            break;
          case RefetchBehavior.always:
            query.fetch(
              fetcher: fetcher,
              staleDuration: Duration.zero,
            );
            break;
        }
      }

      return;
    },
    [query, enabled],
  );

  useOnAppLifecycleStateChange(
    (previous, current) {
      if (!enabled) return;

      if (current == AppLifecycleState.resumed) {
        switch (refetchOnResumed) {
          case RefetchBehavior.never:
            break;
          case RefetchBehavior.stale:
            query.fetch(
              fetcher: fetcher,
              staleDuration: staleDuration,
            );
            break;
          case RefetchBehavior.always:
            query.fetch(
              fetcher: fetcher,
              staleDuration: Duration.zero,
            );
            break;
        }
      }
    },
  );

  final refetch = useCallback(
    () async {
      await query.fetch(
        fetcher: fetcher,
        staleDuration: staleDuration,
      );
    },
    [query],
  );
  final cancel = useCallback(
    () async {
      await query.cancel();
    },
    [query],
  );
  final result = useMemoized(
    () => QueryResult<T>(
      state: stateSnapshot.requireData,
      refetch: refetch,
      cancel: cancel,
    ),
    [
      stateSnapshot.requireData,
      refetch,
      cancel,
    ],
  );

  return result;
}
