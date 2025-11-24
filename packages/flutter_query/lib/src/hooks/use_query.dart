import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:query_core/query_core.dart';
import 'package:query_core/src/query_client.dart';
import 'package:query_core/src/query_cache.dart';
import 'package:query_core/src/types.dart';
import 'package:query_core/src/utils.dart';

QueryResult<T> useQuery<T>(
    {required Future<T> Function() queryFn,
    required List<Object> queryKey,
    double? staleTime,
    bool? enabled,
    void Function(T)? onSuccess,
    void Function(dynamic)? onError,
    void Function(T?)? onUpdate,
    bool spreadCallBackLocalyOnly = false,
    bool? refetchOnRestart,
    bool? refetchOnReconnect}) {
  final cacheKey = queryKeyToCacheKey(queryKey);
  var cacheEntry = cacheQuery[cacheKey];
  var isFirstRequest = useRef(true);
  final callerId = useMemoized(() => DateTime.now().microsecondsSinceEpoch.toString(), []);
    final result = useState<QueryResult<T>>(cacheEntry != null && cacheEntry.result.isSuccess
        ? QueryResult<T>(
          cacheKey,
          cacheEntry.result.status,
        cacheEntry.result.data as T?,
        cacheEntry.result.error,
        isFetching: cacheEntry.result.isFetching)
      : QueryResult<T>(cacheKey, QueryStatus.pending, null, null, isFetching: false));
  late QueryCacheListener queryCacheListener;
  var isMounted = true;

  void updateCache(QueryResult<T> queryResult) {
    if (queryResult.data == null && cacheQuery.containsKey(cacheKey)) {
      cacheQuery.remove(cacheKey);
      return;
    }

    cacheQuery[cacheKey] = CacheQuery(queryResult, DateTime.now());
    QueryClient.instance.notifyUpdate(cacheKey, queryResult, excludeCallerId: callerId);
  }

  void fetch() {
    isFirstRequest.value = false;
    var cacheEntry = cacheQuery[cacheKey];
    var shouldUpdateTheCache = false;

    // If there's no cache entry, or there is no currently running fetch (or it finished/errored),
    // create a new fetch. This ensures we can refetch stale data even when cached data exists.
    if (cacheEntry == null ||
      (cacheEntry.queryFnRunning == null ||
        cacheEntry.queryFnRunning!.isCompleted ||
        cacheEntry.queryFnRunning!.hasError)) {
      var queryResult = QueryResult<T>(cacheKey, QueryStatus.pending, null, null, isFetching: true);

      var futureFetch = TrackedFuture(queryFn());

      cacheQuery[cacheKey] = cacheEntry = CacheQuery<T>(queryResult, DateTime.now(), queryFnRunning: futureFetch);

      shouldUpdateTheCache = true;
    }
    // Loading State: cacheEntry has a Running Function, set result to propagate the loading state
    var futureFetch = cacheEntry.queryFnRunning;
    if (isMounted) result.value = cacheEntry.result as QueryResult<T>;

    futureFetch?.then((value) {
      final queryResult = QueryResult<T>(cacheKey, QueryStatus.success, value, null, isFetching: false);
      if (isMounted) result.value = queryResult;
      if (shouldUpdateTheCache) updateCache(queryResult);

      onSuccess?.call(value);
      if (!spreadCallBackLocalyOnly) QueryClient.instance.queryCache?.config.onSuccess?.call(value);
    }).catchError((e) {
      final queryResult = QueryResult<T>(cacheKey, QueryStatus.error, null, e, isFetching: false);
      if (isMounted) result.value = queryResult;
      if (shouldUpdateTheCache) updateCache(queryResult);
      onError?.call(e);
      if (!spreadCallBackLocalyOnly) QueryClient.instance.queryCache?.config.onError?.call(e);
    });
  }

  useEffect(() {
    if ((enabled ?? QueryClient.instance.defaultOptions.queries.enabled) == false) return null;

    bool shouldFetch = result.value.data == null || result.value.isError || result.value.key != cacheKey;

    //Check StaleTime here
    if (isFirstRequest.value == true && staleTime != double.infinity && cacheEntry != null) {
      staleTime ??= 0;
      final isStale = DateTime.now().difference(cacheEntry.timestamp).inMilliseconds > staleTime!;
      shouldFetch = shouldFetch || isStale;
    }

    if (shouldFetch) {
      fetch();
    }

    // Listen to changes in QueryClient
    listenCacheUpdate(dynamic newResult) {
      try {
        if (!isMounted) return;

        // Accept dynamic payloads from core cache; convert to QueryResult as needed
        if (newResult == null) {
          result.value = QueryResult<T>(cacheKey, QueryStatus.pending, null, null, isFetching: false);
        } else {
          result.value = QueryResult<T>(cacheKey, newResult.status, newResult.data as T?, newResult.error, isFetching: newResult.isFetching);
        }
        if (onUpdate != null) onUpdate(newResult.data);
      } catch (e) {
        debugPrint(e.toString());
      }
    }

    queryCacheListener =
        QueryCacheListener(callerId, false, fetch, listenCacheUpdate, refetchOnRestart, refetchOnReconnect);
    QueryClient.instance.addListener(queryKey, queryCacheListener);

    return () {
      isMounted = false;
      QueryClient.instance.removeListener(queryKey, queryCacheListener);
    };
  }, [enabled, ...queryKey]);

  return result.value;
}
