part of 'query.dart';

class QueryClient {
  final QueryCache cache = QueryCache();

  Future<void> refetch(QueryIdentifier id) async {
    await cache.get(id)?.fetch();
  }

  Data? getQueryData<Data>(QueryIdentifier id) {
    return cache.get<Data>(id)?.state.data;
  }

  QueryState<Data>? getQueryState<Data>(QueryIdentifier id) {
    return cache.get<Data>(id)?.state;
  }

  Query<Data>? getQuery<Data>(QueryIdentifier id) {
    return cache.get<Data>(id);
  }

  void setQueryData<Data>(
    QueryIdentifier id,
    Data data, [
    DateTime? updatedAt,
  ]) {
    cache.build<Data>(id).setData(data, updatedAt);
  }

  Future cancelQuery<T>(
    QueryIdentifier id, {
    T? data,
    Exception? error,
  }) async {
    await cache.get<T>(id)?.cancel(data: data, error: error);
  }

  void dispose() {
    cache.dispose();
  }
}
