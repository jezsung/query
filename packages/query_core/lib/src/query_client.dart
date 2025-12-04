import 'package:query_core/query_core.dart';

QueryClient queryClient = QueryClient();
final cacheQuery = <String, CacheQuery<dynamic>>{};

class QueryClient {
  final DefaultOptions defaultOptions;
  final QueryCache? queryCache;
  final MutationCache? mutationCache;
  final Map<String, List<QueryCacheListener>> _listeners = {};
  static late QueryClient instance;

  QueryClient({this.defaultOptions = const DefaultOptions(), this.queryCache, this.mutationCache}) {
    instance = this;
  }

  // #region listeners
  void addListener(List<Object> keys, QueryCacheListener listener) {
    final cacheKey = queryKeyToCacheKey(keys);
    _listeners.putIfAbsent(cacheKey, () => []).add(listener);
  }

  void removeListener(List<Object> keys, QueryCacheListener listener) {
    final cacheKey = queryKeyToCacheKey(keys);
    _listeners[cacheKey]?.remove(listener);
  }

  void notifyUpdate(String cacheKey, dynamic newResult, {String? excludeCallerId}) {
    for (var listener in _listeners[cacheKey] ?? <QueryCacheListener>[]) {
      if (listener.id != excludeCallerId) {
        listener.listenUpdateCallBack(newResult);
      }
    }
  }

  void notifyRefetch(String cacheKey) {
    for (var listener in _listeners[cacheKey] ?? <QueryCacheListener>[]) {
      listener.refetchCallBack();
    }
  }

  refetchOnRestart() {
    _listeners.forEach((key, listenersList) {
      for (var listener in listenersList) {
        if (listener.refetchOnRestart ?? defaultOptions.queries.refetchOnRestart) {
          listener.refetchCallBack();
        }
      }
    });
  }

  refetchOnReconnect() {
    _listeners.forEach((key, listenersList) {
      for (var listener in listenersList) {
        if (listener.refetchOnReconnect ?? defaultOptions.queries.refetchOnReconnect) {
          listener.refetchCallBack();
        }
      }
    });
  }
  // #endRegion listeners

  void invalidateQueries({List<Object>? queryKey, bool exact = false}) {
    // If queryKey is null we invalidate everything.
    if (queryKey == null) {
      final invalidatedKeys = cacheQuery.keys.toList();
      cacheQuery.clear();
      for (var key in invalidatedKeys) {
        notifyRefetch(key);
      }
      return;
    }

    if (exact) {
      final cacheKey = queryKeyToCacheKey(queryKey);
      cacheQuery.remove(cacheKey);
      notifyRefetch(cacheKey);
    } else {
      final cacheKey = queryKeyToCacheKey(queryKey);
      final List<String> invalidatedKeys = [];

      cacheQuery.removeWhere((key, value) {
        if (key.startsWith(cacheKey)) {
          invalidatedKeys.add(key);
          return true;
        }
        return false;
      });

      for (var key in invalidatedKeys) {
        notifyRefetch(key);
      }
    }
  }

  void setQueryData<T>(List<Object> keys, T Function(T? oldData) updateFn) {
    final cacheKey = queryKeyToCacheKey(keys);
    final oldEntry = cacheQuery[cacheKey];
    final oldData = oldEntry?.result.data as T?;
    final newData = updateFn(oldData);
    final queryResult = QueryResult(cacheKey, QueryStatus.success, newData, null, isFetching: false);

    cacheQuery[cacheKey] = CacheQuery(queryResult, DateTime.now());
    notifyUpdate(cacheKey, queryResult);
  }

  void setQueryInfiniteData<T>(List<Object> keys, List<T> Function(List<T>? oldDatas) updateFn) {
    final cacheKey = queryKeyToCacheKey(keys);
    final oldEntry = cacheQuery[cacheKey];
    final oldDatas = oldEntry?.result.data as List<T>? ?? <T>[];
    final newDatas = updateFn(oldDatas);

    final queryResult = InfiniteQueryResult(
        key: cacheKey,
        status: QueryStatus.success,
        data: newDatas as List<Object>,
        isFetching: false,
        error: null,
        isFetchingNextPage: false,
        fetchNextPage: () async {});

    cacheQuery[cacheKey] = CacheQuery(queryResult, DateTime.now());
    notifyUpdate(cacheKey, queryResult);
  }

  void clear() {
    final keys = cacheQuery.keys.toList();
    cacheQuery.clear();
    for (var key in keys) {
      // Notify listeners that cache was cleared for this key. The UI layer will
      // interpret `null` or missing cache entries appropriately.
      notifyUpdate(key, null);
    }
  }
}
