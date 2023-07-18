import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_query/flutter_query.dart';

enum RefetchBehavior {
  never,
  stale,
  always,
}

typedef QueryRefetch = Future<void> Function();

typedef QueryCancel = Future<void> Function();

class QueryResult<T> {
  QueryResult({
    required this.state,
    required this.refetch,
    required this.cancel,
  });

  final QueryState<T> state;
  final QueryRefetch refetch;
  final QueryCancel cancel;
}

class QueryParameter<T, K> {
  QueryParameter({
    required this.key,
    required this.fetcher,
    required this.enabled,
    required this.initialData,
    required this.initialDataUpdatedAt,
    required this.placeholder,
    required this.staleDuration,
    required this.refetchOnInit,
    required this.refetchOnResumed,
  });

  final QueryKey key;
  final QueryFetcher<T, K> fetcher;
  final bool enabled;
  final T? initialData;
  final DateTime? initialDataUpdatedAt;
  final T? placeholder;
  final Duration staleDuration;
  final RefetchBehavior refetchOnInit;
  final RefetchBehavior refetchOnResumed;
}

class QueryHandler<T, K> {
  QueryHandler({
    required this.query,
    required this.fetcher,
    required this.enabled,
    required this.initialData,
    required this.initialDataUpdatedAt,
    required this.placeholder,
    required this.staleDuration,
    required this.refetchOnInit,
    required this.refetchOnResumed,
    required this.state,
  });

  final Query<T, K> query;
  QueryKey<K> get key => query.key;

  final QueryFetcher<T, K> fetcher;
  final bool enabled;
  final T? initialData;
  final DateTime? initialDataUpdatedAt;
  final T? placeholder;
  final Duration staleDuration;
  final RefetchBehavior refetchOnInit;
  final RefetchBehavior refetchOnResumed;

  final QueryState<T> state;

  Future<void> refetch() async {
    await query.fetch(
      fetcher: fetcher,
      staleDuration: staleDuration,
    );
  }

  Future<void> cancel() async {
    await query.cancel();
  }
}

QueryHandler<T, K> useQuery<T, K>(
  QueryKey<K> key,
  QueryFetcher<T, K> fetcher, {
  bool enabled = true,
  T? initialData,
  DateTime? initialDataUpdatedAt,
  T? placeholder,
  Duration staleDuration = Duration.zero,
  RefetchBehavior refetchOnInit = RefetchBehavior.stale,
  RefetchBehavior refetchOnResumed = RefetchBehavior.stale,
}) {
  final client = useQueryClient();
  final query = useMemoized<Query<T, K>>(
    () {
      final query_ = client.cache.buildQuery<T, K>(key);

      if (initialData != null) {
        query_.setInitialData(initialData, initialDataUpdatedAt);
      }

      return query_;
    },
    [key, client],
  );
  final stateSnapshot = useStream<QueryState<T>>(
    query.stream.map(
      (state) => state.copyWith(
        data: state.hasData ? state.data : placeholder,
      ),
    ),
    initialData: query.state.copyWith(
      data: query.state.hasData ? query.state.data : placeholder,
    ),
    preserveState: false,
  );
  final queryHandler = useMemoized(
    () => QueryHandler<T, K>(
      query: query,
      fetcher: fetcher,
      enabled: enabled,
      initialData: initialData,
      initialDataUpdatedAt: initialDataUpdatedAt,
      placeholder: placeholder,
      staleDuration: staleDuration,
      refetchOnInit: refetchOnInit,
      refetchOnResumed: refetchOnResumed,
      state: stateSnapshot.requireData,
    ),
    [
      query,
      enabled,
      initialData,
      initialDataUpdatedAt,
      placeholder,
      staleDuration,
      refetchOnInit,
      refetchOnResumed,
      stateSnapshot.requireData,
    ],
  );
  useEffect(
    () {
      client.addQueryHandler(queryHandler);
      return () {
        client.removeQueryHandler(queryHandler);
      };
    },
    [client, queryHandler],
  );

  useEffect(() {
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
  }, [query, enabled]);

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

  return queryHandler;
}
