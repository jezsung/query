part of 'query.dart';

class QueryCacheStorage {
  final Map<QueryId, QueryBase> _queries = <QueryId, QueryBase>{};

  List<QueryBase> get queries => _queries.values.toList();

  Query<T> buildQuery<T>(QueryId id) {
    return (_queries[id] ??= Query<T>(id)) as Query<T>;
  }

  Query<T>? getQuery<T>(QueryId id) {
    return _queries[id] as Query<T>?;
  }

  PagedQuery<T, P> buildPagedQuery<T, P>(QueryId id) {
    return (_queries[id] ??= PagedQuery<T, P>(id)) as PagedQuery<T, P>;
  }

  PagedQuery<T, P>? getPagedQuery<T, P>(QueryId id) {
    return _queries[id] as PagedQuery<T, P>?;
  }

  bool exist(QueryId id) {
    return _queries[id] != null;
  }

  void remove(QueryId id) {
    _queries.remove(id);
  }
}
