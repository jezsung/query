import 'package:fluery/src/base_query.dart';
import 'package:fluery/src/query_builder.dart';
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

  Data? getQueryData<Data>(QueryIdentifier id) {
    final query = manager.getQuery<Data>(id);

    return query?.state.data;
  }

  QueryState<Data>? getQueryState<Data>(QueryIdentifier id) {
    final query = manager.getQuery<Data>(id);

    return query?.state;
  }

  void setQueryData<Data>(
    QueryIdentifier id,
    Data data, [
    DateTime? updatedAt,
  ]) {
    final query = manager.buildQuery<Data>(id);
    query.setData(data, updatedAt);
  }

  void dispose() {
    manager.dispose();
  }
}
