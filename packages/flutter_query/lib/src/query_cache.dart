import 'package:flutter_query/flutter_query.dart';

class QueryCache {
  final Map<QueryKey, Query> _queries = <QueryKey, Query>{};

  List<Query> get queries => _queries.values.toList();

  Query<T> buildQuery<T>(QueryKey key) {
    assert(_queries[key] is! PagedQuery);

    Query<T>? query = _queries[key] as Query<T>?;

    if (query != null) {
      return query;
    }

    query = _queries[key] = Query<T>(key);

    return query;
  }

  Query<T>? getQuery<T>(QueryKey key) {
    assert(_queries[key] is! PagedQuery);

    return _queries[key] as Query<T>?;
  }

  bool exist(QueryKey key) {
    return _queries[key] != null;
  }

  void remove(QueryKey key) {
    _queries.remove(key);
  }
}
