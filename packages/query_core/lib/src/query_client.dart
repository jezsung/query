import 'package:query_core/src/options.dart';
import 'package:query_core/src/query_cache.dart';
import 'package:query_core/src/mutation_cache.dart';
import 'package:query_core/src/utils.dart';

late QueryClient queryClient;
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

  refetchOnRecconect() {
    _listeners.forEach((key, listenersList) {
      for (var listener in listenersList) {
        if (listener.refetchOnReconnect ?? defaultOptions.queries.refetchOnReconnect) {
          listener.refetchCallBack();
        }
      }
    });
  }
  // #endRegion listeners

  void invalidateQueries(List<Object> keys, {bool exact = false}) {
    if (exact) {
      final cacheKey = queryKeyToCacheKey(keys);
      cacheQuery.remove(cacheKey);
      notifyRefetch(cacheKey);
    } else {
      final cacheKey = queryKeyToCacheKey(keys);
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

  // NOTE: setQueryData and setQueryInfiniteData were intentionally removed from core.
  // The Flutter layer owns `QueryResult` / `InfiniteQueryResult` models and should
  // call into the core cache directly when mutating stored query data.

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
