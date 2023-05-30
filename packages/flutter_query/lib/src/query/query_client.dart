part of 'query.dart';

class QueryClient {
  final QueryCacheStorage cacheStorage = QueryCacheStorage();

  Future refetch(QueryId id) async {
    final query = cacheStorage.getQuery(id);

    if (query == null) return;

    final controllers = query.observers as List<QueryController>;

    if (controllers.isEmpty) return;

    final fetcher = controllers.map((c) => c.fetcher).first;
    final staleDuration = controllers
        .map((c) => c.staleDuration)
        .reduce((curr, next) => curr < next ? curr : next);

    await query.fetch(
      fetcher: fetcher,
      staleDuration: staleDuration,
    );
  }

  Future cancel(QueryId id) async {
    final query = cacheStorage.getQuery(id);

    await query?.cancel();
  }

  void setQueryData<T>(
    QueryId id,
    T data, [
    DateTime? updatedAt,
  ]) {
    final query = cacheStorage.buildQuery<T>(id);

    query.setData(data, updatedAt);
  }

  Future close() async {
    await Future.wait(cacheStorage.queries.map((q) => q.close()));
  }
}
