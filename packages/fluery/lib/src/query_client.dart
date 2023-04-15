import 'package:fluery/src/query_builder.dart';
import 'package:fluery/src/query_manager.dart';

class QueryClient {
  final QueryManager manager = QueryManager();

  Future<void> refetch(QueryIdentifier id) async {
    final query = manager.build(id);
    await query.fetch();
  }

  Data? getQueryData<Data>(QueryIdentifier id) {
    final query = manager.get<Data>(id);

    return query?.state.data;
  }

  QueryState<Data>? getQueryState<Data>(QueryIdentifier id) {
    final query = manager.get<Data>(id);

    return query?.state;
  }

  void setQueryData<Data>(
    QueryIdentifier id,
    Data data, [
    DateTime? updatedAt,
  ]) {
    final query = manager.build<Data>(id);
    query.setData(data, updatedAt);
  }

  void dispose() {
    manager.dispose();
  }
}
