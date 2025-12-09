import 'query.dart';
import 'query_key.dart';

class QueryCache {
  final Map<QueryKey, Query> _queries = {};

  Query<TData> buildQuery<TData>(
    List<Object?> queryKey,
    Future<TData> Function() queryFn,
  ) {
    final key = QueryKey(queryKey);
    final query = _queries[key] ??= Query<TData>(queryKey, queryFn);
    return query as Query<TData>;
  }

  Query<TData>? getQuery<TData>(List<Object?> queryKey) {
    final key = QueryKey(queryKey);
    return _queries[key] as Query<TData>?;
  }

  void removeQuery(List<Object?> queryKey) {
    final key = QueryKey(queryKey);
    final query = _queries[key];
    query?.dispose();
    _queries.remove(key);
  }

  void dispose() {
    for (final query in _queries.values) {
      query.dispose();
    }
    _queries.clear();
  }
}
