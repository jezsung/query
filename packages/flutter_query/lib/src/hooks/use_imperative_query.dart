import 'package:flutter/scheduler.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_query/flutter_query.dart';

typedef ImperativeQueryFetch<T, K> = void Function(
  QueryKey<K> key, {
  QueryFetcher<T, K>? fetcher,
  T? initialData,
  DateTime? initialDataUpdatedAt,
  T? placeholder,
  Duration? staleDuration,
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
  RefetchBehavior refetchOnInit = RefetchBehavior.stale,
  RefetchBehavior refetchOnResumed = RefetchBehavior.stale,
}) {
  final fetcherDefault = fetcher;
  final initialDataDefault = initialData;
  final initialDataUpdatedAtDefault = initialDataUpdatedAt;
  final placeholderDefault = placeholder;
  final staleDurationDefault = staleDuration;
  final refetchOnInitDefault = refetchOnInit;
  final refetchOnResumedDefault = refetchOnResumed;

  final client = useQueryClient();
  final queryOptions = useState<QueryOptions<T, K>?>(null);
  final query = useMemoized(
    () {
      final options = queryOptions.value;
      if (options == null) return null;

      final query_ = client.cache.buildQuery<T, K>(options.key);

      if (options.initialData != null) {
        query_.setInitialData(
          options.initialData!,
          options.initialDataUpdatedAt,
        );
      }

      return query_;
    },
    [client, queryOptions.value],
  );
  final queryState = useState(query?.state);

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
      queryState.value = query?.state;
      final subscription = query?.stream.listen((data) {
        queryState.value = data;
      });
      return () {
        subscription?.cancel();
      };
    },
    [query],
  );

  useEffect(
    () {
      final options = queryOptions.value;
      if (query == null || options == null) return;
      if (query.state.status.isFetching) return;

      if (query.state.status.isIdle) {
        query.fetch(
          fetcher: options.fetcher,
          staleDuration: options.staleDuration,
        );
      } else {
        switch (options.refetchOnInit) {
          case RefetchBehavior.never:
            break;
          case RefetchBehavior.stale:
            query.fetch(
              fetcher: options.fetcher,
              staleDuration: options.staleDuration,
            );
            break;
          case RefetchBehavior.always:
            query.fetch(
              fetcher: options.fetcher,
              staleDuration: Duration.zero,
            );
            break;
        }
      }

      return;
    },
    [query],
  );

  useOnAppLifecycleStateChange(
    (previous, current) {
      if (current == AppLifecycleState.resumed) {
        final options = queryOptions.value;
        if (query == null || options == null) return;
        if (query.state.status.isFetching) return;

        switch (options.refetchOnInit) {
          case RefetchBehavior.never:
            break;
          case RefetchBehavior.stale:
            query.fetch(
              fetcher: options.fetcher,
              staleDuration: Duration.zero,
            );
            break;
          case RefetchBehavior.always:
            query.fetch(
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
      refetchOnInit,
      refetchOnResumed,
    }) {
      assert(fetcher != null || fetcherDefault != null);

      queryOptions.value = QueryOptions<T, K>(
        key: key,
        fetcher: fetcher ?? fetcherDefault!,
        enabled: true,
        initialData: initialData ?? initialDataDefault,
        initialDataUpdatedAt:
            initialDataUpdatedAt ?? initialDataUpdatedAtDefault,
        placeholder: placeholder ?? placeholderDefault,
        staleDuration: staleDuration ?? staleDurationDefault,
        refetchOnInit: refetchOnInit ?? refetchOnInitDefault,
        refetchOnResumed: refetchOnResumed ?? refetchOnResumedDefault,
      );
    },
    [
      fetcherDefault,
      initialDataDefault,
      initialDataUpdatedAtDefault,
      placeholderDefault,
      staleDurationDefault,
      refetchOnInitDefault,
      refetchOnResumedDefault,
    ],
  );
  final refetch = useCallback(
    () async {
      final options = queryOptions.value;
      if (query == null || options == null) return;

      await query.fetch(
        fetcher: options.fetcher,
        staleDuration: options.staleDuration,
      );
    },
    [query],
  );
  final cancel = useCallback(
    () async {
      await query?.cancel();
    },
    [query],
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
