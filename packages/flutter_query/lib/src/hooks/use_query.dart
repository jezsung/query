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

class QueryParameter<T> {
  QueryParameter({
    required this.key,
    required this.fetcher,
    required this.placeholder,
    required this.staleDuration,
    required this.refetchOnInit,
    required this.refetchOnResumed,
  });

  final QueryKey key;
  final QueryFetcher<T> fetcher;
  final T? placeholder;
  final Duration staleDuration;
  final RefetchBehavior refetchOnInit;
  final RefetchBehavior refetchOnResumed;
}

QueryResult<T> useQuery<T>(
  QueryKey key,
  QueryFetcher<T> fetcher, {
  bool enabled = true,
  T? initialData,
  DateTime? initialDataUpdatedAt,
  T? placeholder,
  Duration staleDuration = Duration.zero,
  RefetchBehavior refetchOnInit = RefetchBehavior.stale,
  RefetchBehavior refetchOnResumed = RefetchBehavior.stale,
}) {
  final client = useQueryClient();
  final query = useMemoized<Query<T>>(
    () {
      final query_ = client.cache.buildQuery<T>(key);
      if (initialData != null) {
        query_.setInitialData(initialData, initialDataUpdatedAt);
      }
      return query_;
    },
    [key, client],
  );
  final fetch = useCallback(
    ({bool ignoreStaleness = false}) async {
      await query.fetch(
        fetcher: fetcher,
        staleDuration: ignoreStaleness ? Duration.zero : staleDuration,
      );
    },
    [query],
  );
  final refetch = useCallback(
    (RefetchBehavior behavior) async {
      switch (behavior) {
        case RefetchBehavior.never:
          break;
        case RefetchBehavior.stale:
          await fetch();
          break;
        case RefetchBehavior.always:
          await fetch(ignoreStaleness: true);
          break;
      }
    },
    [fetch],
  );

  final parameter = useMemoized<QueryParameter<T>>(
    () => QueryParameter<T>(
      key: key,
      fetcher: fetcher,
      placeholder: placeholder,
      staleDuration: staleDuration,
      refetchOnInit: refetchOnInit,
      refetchOnResumed: refetchOnResumed,
    ),
    [
      key,
      fetcher,
      placeholder,
      staleDuration,
      refetchOnInit,
      refetchOnResumed,
    ],
  );
  useEffect(
    () {
      client.parameters.add(parameter);
      return () {
        client.parameters.remove(parameter);
      };
    },
    [client, parameter],
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

  useEffect(() {
    if (!enabled || query.state.status.isFetching) return;

    if (query.state.status.isIdle) {
      fetch();
    } else {
      refetch(refetchOnInit);
    }

    return;
  }, [query, enabled]);

  useOnAppLifecycleStateChange(
    (previous, current) {
      if (current == AppLifecycleState.resumed) {
        refetch(refetchOnResumed);
      }
    },
  );

  return QueryResult(
    state: stateSnapshot.requireData,
    refetch: fetch,
    cancel: query.cancel,
  );
}
