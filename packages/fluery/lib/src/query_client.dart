import 'package:fluery/src/base_query.dart';
import 'package:fluery/src/query_cache_storage.dart';
import 'package:fluery/src/query_manager.dart';

class QueryClient {
  QueryClient({
    this.cacheStorage,
  }) : manager = QueryManager(cacheStorage: cacheStorage);

  final QueryManager manager;
  final QueryCacheStorage? cacheStorage;

  Future<void> refetch(QueryIdentifier id) async {
    final query = manager.buildQuery(id);
    await query.fetch();
  }

  void dispose() {
    manager.dispose();
  }
}
