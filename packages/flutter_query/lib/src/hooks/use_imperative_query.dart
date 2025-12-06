import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_query/flutter_query.dart';

import '../core/core.dart';

typedef ImperativeQueryFetch<T, K> = void Function(
  QueryKey<K> key, {
  QueryFetcher<T, K>? fetcher,
  T? initialData,
  DateTime? initialDataUpdatedAt,
  T? placeholder,
  Duration? staleDuration,
  Duration? gcDuration,
  RefetchBehavior? refetchOnInit,
  RefetchBehavior? refetchOnResumed,
});

class ImperativeQueryResult<T, K> {
  ImperativeQueryResult({
    required this.state,
    required this.fetch,
    required this.refetch,
    required this.cancel,
  });

  final QueryState<T>? state;
  final ImperativeQueryFetch<T, K> fetch;
  final Future<void> Function() refetch;
  final Future<void> Function() cancel;
}

ImperativeQueryResult<T, K> useImperativeQuery<T, K>({
  QueryFetcher<T, K>? fetcher,
  T? initialData,
  DateTime? initialDataUpdatedAt,
  T? placeholder,
  Duration staleDuration = Duration.zero,
  Duration gcDuration = const Duration(minutes: 5),
  RefetchBehavior refetchOnInit = RefetchBehavior.stale,
  RefetchBehavior refetchOnResumed = RefetchBehavior.stale,
}) {
  final fetcherDefault = fetcher;
  final initialDataDefault = initialData;
  final initialDataUpdatedAtDefault = initialDataUpdatedAt;
  final placeholderDefault = placeholder;
  final staleDurationDefault = staleDuration;
  final gcDurationDefault = gcDuration;
  final refetchOnInitDefault = refetchOnInit;
  final refetchOnResumedDefault = refetchOnResumed;

  final client = useQueryClient();
  final queryOptions = useState<QueryOptions<T, K>?>(null);
  final query = useState<Query<T, K>?>(null);
  final queryState = useState(query.value?.state);

  useEffect(
    () {
      final options = queryOptions.value;
      if (options == null) return null;

      final key = options.key;
      client.cache.cancelGc(key);
      return () {
        final options = client.getQueryOptions(key);
        if (options == null || options.isEmpty) {
          client.cache.scheduleGc(key, gcDuration);
        }
      };
    },
    [client, queryOptions.value?.key],
  );

  useEffect(
    () {
      final options = queryOptions.value;
      if (options == null) return null;

      client.addQueryOptions(options);
      return () {
        client.removeQueryOptions(options);
      };
    },
    [client, queryOptions.value],
  );

  useEffect(
    () {
      queryState.value = query.value?.state.copyWith(
        status: query.value!.state.status.isIdle
            ? QueryStatus.fetching
            : query.value!.state.status,
      );
      final subscription = query.value?.stream.listen((data) {
        queryState.value = data;
      });
      return () {
        subscription?.cancel();
      };
    },
    [query.value],
  );

  useOnAppLifecycleStateChange(
    (previous, current) {
      if (current == AppLifecycleState.resumed) {
        final options = queryOptions.value;
        if (query.value == null || options == null) return;
        if (query.value!.state.status.isFetching) return;

        switch (options.refetchOnResumed) {
          case RefetchBehavior.never:
            break;
          case RefetchBehavior.stale:
            query.value!.fetch(
              fetcher: options.fetcher,
              staleDuration: Duration.zero,
            );
            break;
          case RefetchBehavior.always:
            query.value!.fetch(
              fetcher: options.fetcher,
              staleDuration: Duration.zero,
            );
            break;
        }
      }
    },
  );

  final fetch = useCallback<ImperativeQueryFetch<T, K>>(
    (
      key, {
      fetcher,
      initialData,
      initialDataUpdatedAt,
      placeholder,
      staleDuration,
      gcDuration,
      refetchOnInit,
      refetchOnResumed,
    }) async {
      assert(fetcher != null || fetcherDefault != null);

      final options = QueryOptions<T, K>(
        key: key,
        fetcher: fetcher ?? fetcherDefault!,
        enabled: true,
        initialData: initialData ?? initialDataDefault,
        initialDataUpdatedAt:
            initialDataUpdatedAt ?? initialDataUpdatedAtDefault,
        placeholder: placeholder ?? placeholderDefault,
        staleDuration: staleDuration ?? staleDurationDefault,
        gcDuration: gcDuration ?? gcDurationDefault,
        refetchOnInit: refetchOnInit ?? refetchOnInitDefault,
        refetchOnResumed: refetchOnResumed ?? refetchOnResumedDefault,
      );

      queryOptions.value = options;
      query.value = client.cache.buildQuery<T, K>(key);

      if (options.initialData != null) {
        query.value!.setInitialData(
          options.initialData!,
          options.initialDataUpdatedAt,
        );
      }

      if (!query.value!.state.status.isFetching) {
        await query.value!.fetch(
          fetcher: options.fetcher,
          staleDuration: options.staleDuration,
        );
      }
    },
    [
      fetcherDefault,
      initialDataDefault,
      initialDataUpdatedAtDefault,
      placeholderDefault,
      staleDurationDefault,
      gcDurationDefault,
      refetchOnInitDefault,
      refetchOnResumedDefault,
    ],
  );
  final refetch = useCallback(
    () async {
      final options = queryOptions.value;
      if (query.value == null || options == null) return;

      await query.value!.fetch(
        fetcher: options.fetcher,
        staleDuration: options.staleDuration,
      );
    },
    [query.value],
  );
  final cancel = useCallback(
    () async {
      await query.value?.cancel();
    },
    [query.value],
  );
  final result = useMemoized(
    () => ImperativeQueryResult<T, K>(
      state: queryState.value,
      fetch: fetch,
      refetch: refetch,
      cancel: cancel,
    ),
    [
      queryState.value,
      fetch,
      refetch,
      cancel,
    ],
  );

  return result;
}
