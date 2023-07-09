import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_query/flutter_query.dart';
import 'package:flutter_query/src/hooks/use_query_client.dart';

enum RefetchBehavior {
  never,
  stale,
  always,
}

typedef Refetch = Future Function();

typedef Cancel = Future Function();

class UseQueryResult<T> {
  UseQueryResult({
    required this.state,
    required this.refetch,
    required this.cancel,
  });

  final QueryState<T> state;
  final Refetch refetch;
  final Cancel cancel;
}

class QueryOptions<T> {
  QueryOptions({
    required this.key,
    required this.fetcher,
    required this.placeholder,
    required this.staleDuration,
    required this.cacheDuration,
    required this.refetchOnInit,
    required this.refetchOnResumed,
  });

  final QueryKey key;
  final QueryFetcher<T> fetcher;
  final T? placeholder;
  final Duration staleDuration;
  final Duration cacheDuration;
  final RefetchBehavior refetchOnInit;
  final RefetchBehavior refetchOnResumed;
}

UseQueryResult<T> useQuery<T>(
  QueryKey key,
  QueryFetcher<T> fetcher, {
  T? placeholder,
  Duration staleDuration = Duration.zero,
  RefetchBehavior refetchOnInit = RefetchBehavior.stale,
  RefetchBehavior refetchOnResumed = RefetchBehavior.stale,
}) {
  final client = useQueryClient();
  final query = useMemoized<Query<T>>(
    () => client.cacheStorage.buildQuery<T>(key),
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
  final stateSnapshot = useStream<QueryState<T>>(
    query.stream,
    initialData: query.state,
    preserveState: false,
  );

  useEffect(() {
    if (query.state.status.isFetching) return;

    if (query.state.status.isIdle) {
      fetch();
    } else {
      refetch(refetchOnInit);
    }

    return;
  }, [query]);

  useOnAppLifecycleStateChange(
    (previous, current) {
      if (current == AppLifecycleState.resumed) {
        refetch(refetchOnResumed);
      }
    },
  );

  return UseQueryResult(
    state: stateSnapshot.requireData.copyWith(
      data: stateSnapshot.requireData.data ?? placeholder,
    ),
    refetch: fetch,
    cancel: query.cancel,
  );
}
