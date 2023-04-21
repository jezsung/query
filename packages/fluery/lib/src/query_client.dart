import 'package:fluery/src/query_builder.dart';
import 'package:fluery/src/query_cache.dart';
import 'package:flutter/foundation.dart';

class QueryClient {
  final QueryCache cache = QueryCache();

  Future<void> refetch(QueryIdentifier id) async {
    final query = cache.build(id);
    await query.fetch();
  }

  Data? getQueryData<Data>(QueryIdentifier id) {
    final query = cache.get<Data>(id);

    return query?.state.data;
  }

  QueryState<Data>? getQueryState<Data>(QueryIdentifier id) {
    final query = cache.get<Data>(id);

    return query?.state;
  }

  @visibleForTesting
  Query<Data>? getQuery<Data>(QueryIdentifier id) {
    return cache.get<Data>(id);
  }

  void setQueryData<Data>(
    QueryIdentifier id,
    Data data, [
    DateTime? updatedAt,
  ]) {
    final query = cache.build<Data>(id);
    query.setData(data, updatedAt);
  }

  void dispose() {
    cache.dispose();
  }
}
