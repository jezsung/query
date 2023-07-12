import 'package:flutter_query/flutter_query.dart';

class QueryCache {
  final Map<QueryKey, Query> _queries = <QueryKey, Query>{};
  final Map<QueryKey, PagedQuery> _pagedQueries = <QueryKey, PagedQuery>{};

  List<Query> get queries => _queries.values.toList();

  Query<T> buildQuery<T>(QueryKey key) {
    assert(
      _pagedQueries[key] == null,
      'The key $key is already used by a $PagedQuery',
    );

    Query<T>? query = _queries[key] as Query<T>?;

    if (query != null) {
      return query;
    }

    query = _queries[key] = Query<T>(key);

    return query;
  }

  PagedQuery<T, P> buildPagedQuery<T extends Object, P>(QueryKey key) {
    assert(
      _queries[key] == null,
      'The key $key is already used by a $PagedQuery',
    );

    PagedQuery<T, P>? query = _pagedQueries[key] as PagedQuery<T, P>?;

    if (query != null) {
      return query;
    }

    query = _pagedQueries[key] = PagedQuery<T, P>(key);

    return query;
  }

  Query<T>? getQuery<T>(QueryKey key) {
    assert(_queries[key] is! PagedQuery);

    return _queries[key] as Query<T>?;
  }

  PagedQuery<T, P>? getPagedQuery<T extends Object, P>(QueryKey key) {
    return _pagedQueries[key] as PagedQuery<T, P>?;
  }

  bool exist(QueryKey key) {
    return _queries[key] != null;
  }

  void remove(QueryKey key) {
    _queries.remove(key);
  }
}
