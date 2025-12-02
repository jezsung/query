import 'dart:async';

import 'package:query_core/query_core.dart';
import 'package:query_core/src/query_client.dart';
import 'package:query_core/src/query_cache.dart';
import 'package:query_core/src/query_types.dart';
import 'package:query_core/src/utils.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter/material.dart';

InfiniteQueryResult<T> useInfiniteQuery<T>({
  required List<Object> queryKey,
  required Future<T?> Function(int pageParam) queryFn,
  bool? enabled,
  required int initialPageParam,
  int Function(T lastResult)? getNextPageParam,
  Duration? debounceTime,
  void Function(T)? onSuccess,
  void Function(dynamic)? onError,
  bool spreadCallBackLocalyOnly = false,
  bool? refetchOnRestart,
  bool? refetchOnReconnect,
}) {
  final cacheKey = queryKeyToCacheKey(queryKey);
  final currentPage = useRef<int>(initialPageParam);
  var isFirstRequest = useRef(true);
  final callerId = useMemoized(() => DateTime.now().microsecondsSinceEpoch.toString(), []);
  var cacheEntry = cacheQuery[cacheKey];
  final result = useState<InfiniteQueryResult<T>>(cacheEntry != null && cacheEntry.result.isSuccess
      ? InfiniteQueryResult(
          key: cacheKey,
          status: cacheEntry.result.status,
          data: cacheEntry.result.data as List<T>,
          isFetching: cacheEntry.result.isFetching,
          error: cacheEntry.result.error,
          isFetchingNextPage: false)
      : InfiniteQueryResult(
          key: cacheKey,
          status: QueryStatus.pending,
          data: [],
          isFetching: false,
          error: null,
          isFetchingNextPage: false));
  late QueryCacheListener queryCacheListener;

  var isMounted = true;
  Timer? timer;

  void updateCache(InfiniteQueryResult<T> queryResult, {TrackedFuture<dynamic>? queryFnRunning}) {
    if (queryResult.data == null && cacheQuery.containsKey(cacheKey)) {
      cacheQuery.remove(cacheKey);
      return;
    }

    cacheQuery[cacheKey] = CacheQuery(queryResult, DateTime.now(), queryFnRunning: queryFnRunning);
    QueryClient.instance.notifyUpdate(cacheKey, queryResult, excludeCallerId: callerId);
  }

  // Safe setter to avoid updating the ValueNotifier after it has been disposed.
  void safeSetResult(InfiniteQueryResult<T> newValue) {
    if (!isMounted) return;
    try {
      result.value = newValue;
    } catch (e) {
      // In fetchNextPage the ValueNotifier may be disposed before
      // his async callback runs. Swallow the error to prevent an app crash.
    }
  }

  void fetchNextPage(InfiniteQueryResult<T> resultPreviousPage) {
    final nextPage = getNextPageParam != null ? getNextPageParam(resultPreviousPage.data!.last) : currentPage.value;

    if (!isMounted) return;
    if (nextPage <= currentPage.value || resultPreviousPage.isFetchingNextPage) return;

    currentPage.value = nextPage;

    var queryLoadingMore = resultPreviousPage.copyWith(
        isFetching: true, status: resultPreviousPage.status, error: null, isFetchingNextPage: true);

    var futureFetch = TrackedFuture(queryFn(nextPage));
    if (isMounted) result.value = queryLoadingMore;
    updateCache(queryLoadingMore, queryFnRunning: futureFetch);

    futureFetch.then((value) {
      if (value is! T) return;
      var pageData = value;

      final data = [...?resultPreviousPage.data, value];

      final queryResult = InfiniteQueryResult<T>(
        key: cacheKey,
        status: QueryStatus.success,
        data: data,
        isFetching: false,
        error: null,
        isFetchingNextPage: false,
      );
      queryResult.fetchNextPage = () => fetchNextPage(queryResult);

      safeSetResult(queryResult);
      updateCache(queryResult);

      onSuccess?.call(pageData);
      if (!spreadCallBackLocalyOnly) QueryClient.instance.queryCache?.config.onSuccess?.call(pageData);
    }).catchError((e) {
      final queryResult = InfiniteQueryResult<T>(
        key: cacheKey,
        status: QueryStatus.error,
        data: <T>[],
        isFetching: false,
        error: e,
        isFetchingNextPage: false,
      );
      queryResult.fetchNextPage = () => fetchNextPage(queryResult);
      safeSetResult(queryResult);
      updateCache(queryResult);
      onError?.call(e);
      if (!spreadCallBackLocalyOnly) QueryClient.instance.queryCache?.config.onError?.call(e);
    });
  }

  void fetch() {
    isFirstRequest.value = false;
    var cacheEntry = cacheQuery[cacheKey];
    var shouldUpdateTheCache = false;

    if (cacheEntry == null ||
        cacheEntry.queryFnRunning == null ||
        cacheEntry.queryFnRunning!.isCompleted ||
        cacheEntry.queryFnRunning!.hasError) {
      var queryResult = InfiniteQueryResult<T>(
          key: cacheKey,
          status: QueryStatus.pending,
          data: [],
          isFetching: true,
          error: null,
          isFetchingNextPage: false);
      queryResult.fetchNextPage = () => fetchNextPage(queryResult);

      shouldUpdateTheCache = true;
      var futureFetch = TrackedFuture(queryFn(initialPageParam));

      //create CacheEntry
      cacheQuery[cacheKey] = cacheEntry = CacheQuery(queryResult, DateTime.now(), queryFnRunning: futureFetch);
    }
    // Loading State: cacheEntry has a Running Function, set result to propagate the loading state
    var futureFetch = cacheEntry.queryFnRunning!;
    if (isMounted) result.value = cacheEntry.result as InfiniteQueryResult<T>;

    futureFetch.then((value) {
      if (value is! T) return;
      var pageData = value;

      final data = [pageData];
      final queryResult = InfiniteQueryResult<T>(
        key: cacheKey,
        status: QueryStatus.success,
        data: data,
        isFetching: false,
        error: null,
        isFetchingNextPage: false,
      );
      queryResult.fetchNextPage = () => fetchNextPage(queryResult);

      if (isMounted) result.value = queryResult;
      if (shouldUpdateTheCache) updateCache(queryResult);

      onSuccess?.call(pageData);
      if (!spreadCallBackLocalyOnly) QueryClient.instance.queryCache?.config.onSuccess?.call(pageData);
    }).catchError((e) {
      final queryResult = InfiniteQueryResult<T>(
        key: cacheKey,
        status: QueryStatus.error,
        data: <T>[],
        isFetching: false,
        error: e,
        isFetchingNextPage: false,
      );
      queryResult.fetchNextPage = () => fetchNextPage(queryResult);
      if (isMounted) result.value = queryResult;
      if (shouldUpdateTheCache) updateCache(queryResult);
      onError?.call(e);
      if (!spreadCallBackLocalyOnly) QueryClient.instance.queryCache?.config.onError?.call(e);
    });
  }

  void refetchPagesUpToCurrent() async {
    final List<T> data = [];
    try {
      //Loading...
      var queryResult = InfiniteQueryResult<T>(
          key: cacheKey,
          status: QueryStatus.pending,
          data: [],
          isFetching: true,
          error: null,
          isFetchingNextPage: false);
      queryResult.fetchNextPage = () => fetchNextPage(queryResult);
      if (isMounted) result.value = queryResult;

      for (int page = initialPageParam; page <= currentPage.value; page++) {
        final pageData = await queryFn(page);
        if (pageData == null || !isMounted) return;
        data.add(pageData);
      }

      queryResult = InfiniteQueryResult(
        key: cacheKey,
        status: QueryStatus.success,
        data: data,
        isFetching: false,
        error: null,
        isFetchingNextPage: false,
      );
      queryResult.fetchNextPage = () => fetchNextPage(queryResult);
      if (isMounted) result.value = queryResult;

      updateCache(queryResult);
    } catch (e) {
      debugPrint("An error occurred while refetching pages up to current: $e");
    }
  }

  useEffect(() {
    if ((enabled ?? QueryClient.instance.defaultOptions.queries.enabled) == false) return null;

    if (debounceTime == null || isFirstRequest.value) {
      resetValues(currentPage, initialPageParam, result);
      fetch();
    } else {
      if (timer == null) {
        resetValues(currentPage, initialPageParam, result, isLoading: true);
      }
      if (timer != null) {
        timer!.cancel();
      }
      timer = Timer(debounceTime, () {
        fetch();
      });
    }

    // Listen to changes in QueryClient
    listenCacheUpdate(dynamic queryResult) {
      if (queryResult is InfiniteQueryResult) {
        try {
          if (!isMounted) return;
          //We need to cast it with T, cause Flutter take it as Object only..
          var queryResultT = InfiniteQueryResult<T>(
              key: cacheKey,
              status: queryResult.status,
              data: queryResult.data as List<T>,
              isFetching: queryResult.isFetching,
              error: queryResult.error,
              isFetchingNextPage: queryResult.isFetchingNextPage);
          // fetchNextPage should be set
          queryResultT.fetchNextPage = () => fetchNextPage(queryResultT);
          result.value = queryResultT;
        } catch (e) {
          debugPrint(e.toString());
        }
      } else {
        // Handle the case where newResult is not an InfiniteQueryResult
        debugPrint("newResult is not an InfiniteQueryResult");
      }
    }

    queryCacheListener = QueryCacheListener(
        callerId, true, refetchPagesUpToCurrent, listenCacheUpdate, refetchOnRestart, refetchOnReconnect);
    QueryClient.instance.addListener(queryKey, queryCacheListener);

    return () {
      isMounted = false;
      QueryClient.instance.removeListener(queryKey, queryCacheListener);
      if (timer != null) {
        timer!.cancel();
      }
    };
  }, [enabled, ...queryKey]);

  result.value.fetchNextPage = () => fetchNextPage(result.value);
  return result.value;
}

void resetValues<T>(ObjectRef<int> currentPage, int initialPageParam, ValueNotifier<InfiniteQueryResult<T>> result,
    {bool isLoading = false}) {
  currentPage.value = initialPageParam;
  result.value.status = QueryStatus.pending;
  result.value.data = [];
}
