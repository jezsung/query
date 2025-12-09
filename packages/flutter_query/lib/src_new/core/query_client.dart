import 'query_cache.dart';

class QueryClient {
  QueryClient({QueryCache? cache}) : cache = cache ?? QueryCache();

  final QueryCache cache;

  void dispose() {
    cache.dispose();
  }
}
