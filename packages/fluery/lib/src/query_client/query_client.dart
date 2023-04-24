import 'package:fluery/src/fluery_error.dart';
import 'package:fluery/src/query/query.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

part 'query_cache.dart';
part 'query_client_provider.dart';

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
