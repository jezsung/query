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
  final client = useQueryClient();

  final parameter = useState<QueryOptions<T, K>?>(null);

  final fetcherDefault = fetcher;
  final initialDataDefault = initialData;
  final initialDataUpdatedAtDefault = initialDataUpdatedAt;
  final placeholderDefault = placeholder;
  final staleDurationDefault = staleDuration;
  final refetchOnInitDefault = refetchOnInit;
  final refetchOnResumedDefault = refetchOnResumed;

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

      parameter.value = QueryOptions<T, K>(
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
  );

  useEffect(
    () {
      if (parameter.value == null) return null;

      client.parameters.add(parameter.value!);

      return () {
        client.parameters.remove(parameter.value);
      };
    },
    [client, parameter],
  );

  final query = useMemoized<Query<T, K>?>(
    () {
      final param = parameter.value;
      if (param == null) return null;

      final query_ = client.cache.buildQuery<T, K>(param.key);

      if (param.initialData != null) {
        query_.setInitialData(
          param.initialData!,
          param.initialDataUpdatedAt,
        );
      }

      return query_;
    },
    [parameter.value, client],
  );
  final refetch = useCallback(
    ({
      Duration? staleDuration,
    }) async {
      final param = parameter.value;
      if (query == null || param == null) return;

      await query.fetch(
        fetcher: param.fetcher,
        staleDuration: staleDuration ?? param.staleDuration,
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

  final queryState = useState(query?.state);
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

  useEffect(() {
    final param = parameter.value;
    if (query == null || param == null) return;
    if (query.state.status.isFetching) return;

    if (query.state.status.isIdle) {
      query.fetch(
        fetcher: parameter.value!.fetcher,
        staleDuration: parameter.value!.staleDuration,
      );
    } else {
      switch (param.refetchOnInit) {
        case RefetchBehavior.never:
          break;
        case RefetchBehavior.stale:
          refetch();
          break;
        case RefetchBehavior.always:
          refetch(staleDuration: Duration.zero);
          break;
      }
    }

    return;
  }, [query]);

  useOnAppLifecycleStateChange(
    (previous, current) {
      if (current == AppLifecycleState.resumed) {
        final param = parameter.value;

        if (param == null) return;

        switch (param.refetchOnInit) {
          case RefetchBehavior.never:
            break;
          case RefetchBehavior.stale:
            refetch();
            break;
          case RefetchBehavior.always:
            refetch(staleDuration: Duration.zero);
            break;
        }
      }
    },
  );

  return ImperativeQueryResult<T, K>(
    state: queryState.value,
    fetch: fetch,
    refetch: refetch,
    cancel: cancel,
  );
}
