import 'package:flutter_query/flutter_query.dart';

class QueryCache {
  final Map<QueryKey, Query> _queries = <QueryKey, Query>{};
  final Map<QueryKey, PagedQuery> _pagedQueries = <QueryKey, PagedQuery>{};

  List<Query> get queries => _queries.values.toList();

  Query<T, K> buildQuery<T, K>(QueryKey<K> key) {
    assert(
      _pagedQueries[key] == null,
      'The key $key is already used by a $PagedQuery',
    );

    Query<T, K>? query = _queries[key] as Query<T, K>?;

    if (query != null) {
      return query;
    }

    query = _queries[key] = Query<T, K>(key);

    return query;
  }

  PagedQuery<T, K, P> buildPagedQuery<T extends Object, K, P>(
    QueryKey<K> key,
  ) {
    assert(
      _queries[key] == null,
      'The key $key is already used by a $PagedQuery',
    );

    PagedQuery<T, K, P>? query = _pagedQueries[key] as PagedQuery<T, K, P>?;

    if (query != null) {
      return query;
    }

    query = _pagedQueries[key] = PagedQuery<T, K, P>(key);

    return query;
  }

  Query<T, K>? getQuery<T, K>(QueryKey<K> key) {
    assert(_queries[key] is! PagedQuery);

    return _queries[key] as Query<T, K>?;
  }

  PagedQuery<T, K, P>? getPagedQuery<T extends Object, K, P>(
    QueryKey<K> key,
  ) {
    return _pagedQueries[key] as PagedQuery<T, K, P>?;
  }

  bool exist(QueryKey key) {
    return _queries[key] != null;
  }

  void remove(QueryKey key) {
    _queries.remove(key);
  }
}
