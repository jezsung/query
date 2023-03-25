import 'package:fluery/src/base_query.dart';
import 'package:fluery/src/query_cache_storage.dart';
import 'package:fluery/src/query_manager.dart';

class QueryClient {
  QueryClient({
    required this.cacheStorage,
  }) : manager = QueryManager(cacheStorage: cacheStorage);

  final QueryCacheStorage cacheStorage;
  final QueryManager manager;

  Future<void> refetch(QueryIdentifier id) async {
    await manager.get(id)?.fetch();
  }
}
