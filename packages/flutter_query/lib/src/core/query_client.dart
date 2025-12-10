import 'query_cache.dart';

class QueryClient {
  QueryClient({QueryCache? cache}) : _cache = cache ?? QueryCache();

  final QueryCache _cache;

  /// Gets the query cache
  QueryCache get cache => _cache;

  /// Disposes the query client and clears all queries from the cache
  void dispose() {
    _cache.clear();
  }
}
