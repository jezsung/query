import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_query/flutter_query.dart';

class PagedQueryResult<T, P> {
  PagedQueryResult({
    required this.state,
    required this.refetch,
    required this.fetchNextPage,
    required this.fetchPreviousPage,
  });

  final PagedQueryState<T> state;
  final Future<void> Function() refetch;
  final Future<void> Function() fetchNextPage;
  final Future<void> Function() fetchPreviousPage;
}

class PagedQueryParameter<T extends Object, P> {
  PagedQueryParameter({
    required this.key,
    required this.fetcher,
    required this.nextPageParamBuilder,
    required this.previousPageParamBuilder,
    required this.enabled,
    required this.initialData,
    required this.initialDataUpdatedAt,
    required this.placeholder,
    required this.staleDuration,
    required this.refetchOnInit,
    required this.refetchOnResumed,
  });

  final QueryKey key;
  final PagedQueryFetcher<T, P> fetcher;
  final PagedQueryParamBuilder<T, P>? nextPageParamBuilder;
  final PagedQueryParamBuilder<T, P>? previousPageParamBuilder;
  final bool enabled;
  final Pages<T>? initialData;
  final DateTime? initialDataUpdatedAt;
  final Pages<T>? placeholder;
  final Duration staleDuration;
  final RefetchBehavior refetchOnInit;
  final RefetchBehavior refetchOnResumed;
}

PagedQueryResult<T, P> usePagedQuery<T extends Object, P>(
  QueryKey key,
  PagedQueryFetcher<T, P> fetcher, {
  PagedQueryParamBuilder<T, P>? nextPageParamBuilder,
  PagedQueryParamBuilder<T, P>? previousPageParamBuilder,
  bool enabled = true,
  Pages<T>? initialData,
  DateTime? initialDataUpdatedAt,
  Pages<T>? placeholder,
  Duration staleDuration = Duration.zero,
  RefetchBehavior refetchOnInit = RefetchBehavior.stale,
  RefetchBehavior refetchOnResumed = RefetchBehavior.stale,
}) {
  final client = useQueryClient();
  final query = useMemoized<PagedQuery<T, P>>(
    () {
      final query_ = client.cache.buildPagedQuery<T, P>(key);
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
        nextPageParamBuilder: nextPageParamBuilder,
        previousPageParamBuilder: previousPageParamBuilder,
        staleDuration: ignoreStaleness ? Duration.zero : staleDuration,
      );
    },
    [query],
  );
  final fetchNextPage = useCallback(
    () async {
      assert(nextPageParamBuilder != null);

      await query.fetchNextPage(
        fetcher: fetcher,
        nextPageParamBuilder: nextPageParamBuilder!,
        previousPageParamBuilder: previousPageParamBuilder,
      );
    },
    [query],
  );
  final fetchPreviousPage = useCallback(
    () async {
      assert(previousPageParamBuilder != null);

      await query.fetchPreviousPage(
        fetcher: fetcher,
        nextPageParamBuilder: nextPageParamBuilder,
        previousPageParamBuilder: previousPageParamBuilder!,
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

  final parameter = useMemoized<PagedQueryParameter<T, P>>(
    () => PagedQueryParameter<T, P>(
      key: key,
      fetcher: fetcher,
      nextPageParamBuilder: nextPageParamBuilder,
      previousPageParamBuilder: previousPageParamBuilder,
      enabled: enabled,
      initialData: initialData,
      initialDataUpdatedAt: initialDataUpdatedAt,
      placeholder: placeholder,
      staleDuration: staleDuration,
      refetchOnInit: refetchOnInit,
      refetchOnResumed: refetchOnResumed,
    ),
    [
      key,
      fetcher,
      nextPageParamBuilder,
      previousPageParamBuilder,
      enabled,
      initialData,
      initialDataUpdatedAt,
      placeholder,
      staleDuration,
      refetchOnInit,
      refetchOnResumed,
    ],
  );
  useEffect(
    () {
      client.pagedQueryParameters.add(parameter);
      return () {
        client.pagedQueryParameters.remove(parameter);
      };
    },
    [client, parameter],
  );

  final stateSnapshot = useStream<PagedQueryState<T>>(
    query.stream.map(
      (state) => state.copyWith(
        data: state.hasData ? state.pages : placeholder,
      ),
    ),
    initialData: query.state.copyWith(
      data: query.state.hasData ? query.state.pages : placeholder,
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

  return PagedQueryResult<T, P>(
    state: stateSnapshot.requireData,
    refetch: fetch,
    fetchNextPage: fetchNextPage,
    fetchPreviousPage: fetchPreviousPage,
  );
}
