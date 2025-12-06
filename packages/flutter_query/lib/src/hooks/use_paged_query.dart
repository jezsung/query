import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../core/core.dart';
import 'use_query_client.dart' show useQueryClient;
import 'use_query.dart' show RefetchBehavior;

class PagedQueryResult<T, P> {
  PagedQueryResult({
    required this.refetch,
    required this.fetchNextPage,
    required this.fetchPreviousPage,
    required this.state,
  });

  final Future<void> Function() refetch;
  final Future<void> Function() fetchNextPage;
  final Future<void> Function() fetchPreviousPage;
  final PagedQueryState<T> state;
}

class PagedQueryOptions<T extends Object, K, P> {
  PagedQueryOptions({
    required this.key,
    required this.fetcher,
    required this.nextPageParamBuilder,
    required this.previousPageParamBuilder,
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
  final PagedQueryFetcher<T, K, P> fetcher;
  final PagedQueryParamBuilder<T, P>? nextPageParamBuilder;
  final PagedQueryParamBuilder<T, P>? previousPageParamBuilder;
  final bool enabled;
  final Pages<T>? initialData;
  final DateTime? initialDataUpdatedAt;
  final Pages<T>? placeholder;
  final Duration staleDuration;
  final Duration gcDuration;
  final RefetchBehavior refetchOnInit;
  final RefetchBehavior refetchOnResumed;
}

PagedQueryResult<T, P> usePagedQuery<T extends Object, K, P>(
  QueryKey key,
  PagedQueryFetcher<T, K, P> fetcher, {
  PagedQueryParamBuilder<T, P>? nextPageParamBuilder,
  PagedQueryParamBuilder<T, P>? previousPageParamBuilder,
  bool enabled = true,
  Pages<T>? initialData,
  DateTime? initialDataUpdatedAt,
  Pages<T>? placeholder,
  Duration staleDuration = Duration.zero,
  Duration gcDuration = const Duration(minutes: 5),
  RefetchBehavior refetchOnInit = RefetchBehavior.stale,
  RefetchBehavior refetchOnResumed = RefetchBehavior.stale,
}) {
  final client = useQueryClient();
  final query = useMemoized(
    () {
      final query_ = client.cache.buildPagedQuery<T, K, P>(key);
      if (initialData != null) {
        query_.setInitialData(initialData, initialDataUpdatedAt);
      }
      return query_;
    },
    [key, client],
  );
  final queryOptions = useMemoized(
    () => PagedQueryOptions<T, K, P>(
      key: key,
      fetcher: fetcher,
      nextPageParamBuilder: nextPageParamBuilder,
      previousPageParamBuilder: previousPageParamBuilder,
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
      nextPageParamBuilder,
      previousPageParamBuilder,
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

  useEffect(
    () {
      client.cache.cancelGc(key);
      return () {
        final options = client.getPagedQueryOptions(key);
        if (options == null || options.isEmpty) {
          client.cache.scheduleGc(key, gcDuration);
        }
      };
    },
    [client],
  );

  useEffect(
    () {
      client.addPagedQueryOptions(queryOptions);
      return () {
        client.removePagedQueryOptions(queryOptions);
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
          nextPageParamBuilder: nextPageParamBuilder,
          previousPageParamBuilder: previousPageParamBuilder,
          staleDuration: staleDuration,
        );
      } else {
        switch (refetchOnInit) {
          case RefetchBehavior.never:
            break;
          case RefetchBehavior.stale:
            query.fetch(
              fetcher: fetcher,
              nextPageParamBuilder: nextPageParamBuilder,
              previousPageParamBuilder: previousPageParamBuilder,
              staleDuration: staleDuration,
            );
            break;
          case RefetchBehavior.always:
            query.fetch(
              fetcher: fetcher,
              nextPageParamBuilder: nextPageParamBuilder,
              previousPageParamBuilder: previousPageParamBuilder,
              staleDuration: Duration.zero,
            );
            break;
        }
      }

      return;
    },
    [query, enabled],
  );

  useOnAppLifecycleStateChange((previous, current) {
    if (!enabled) return;

    if (current == AppLifecycleState.resumed) {
      switch (refetchOnResumed) {
        case RefetchBehavior.never:
          break;
        case RefetchBehavior.stale:
          query.fetch(
            fetcher: fetcher,
            nextPageParamBuilder: nextPageParamBuilder,
            previousPageParamBuilder: previousPageParamBuilder,
            staleDuration: staleDuration,
          );
          break;
        case RefetchBehavior.always:
          query.fetch(
            fetcher: fetcher,
            nextPageParamBuilder: nextPageParamBuilder,
            previousPageParamBuilder: previousPageParamBuilder,
            staleDuration: Duration.zero,
          );
          break;
      }
    }
  });

  final refetch = useCallback(
    () async {
      await query.fetch(
        fetcher: fetcher,
        nextPageParamBuilder: nextPageParamBuilder,
        previousPageParamBuilder: previousPageParamBuilder,
        staleDuration: staleDuration,
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
  final result = useMemoized(
    () => PagedQueryResult<T, P>(
      refetch: refetch,
      fetchNextPage: fetchNextPage,
      fetchPreviousPage: fetchPreviousPage,
      state: stateSnapshot.requireData,
    ),
    [
      refetch,
      fetchNextPage,
      fetchPreviousPage,
      stateSnapshot.requireData,
    ],
  );

  return result;
}
