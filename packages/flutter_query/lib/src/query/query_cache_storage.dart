part of 'query.dart';

class QueryCacheStorage {
  final Map<QueryId, QueryBase> _queries = <QueryId, QueryBase>{};
  final Map<QueryId, Timer> _garbageCollectionTimers = <QueryId, Timer>{};

  List<QueryBase> get queries => _queries.values.toList();

  Query<T> buildQuery<T>(QueryId id) {
    assert(_queries[id] is! PagedQuery);

    Query<T>? query = _queries[id] as Query<T>?;

    if (query != null) {
      return query;
    }

    query = _queries[id] = Query<T>(id);

    scheduleGarbageCollection(id, const Duration(minutes: 5));

    return query;
  }

  Query<T>? getQuery<T>(QueryId id) {
    assert(_queries[id] is! PagedQuery);

    return _queries[id] as Query<T>?;
  }

  PagedQuery<T, P> buildPagedQuery<T, P>(QueryId id) {
    assert(_queries[id] is! Query);

    PagedQuery<T, P>? query = _queries[id] as PagedQuery<T, P>?;

    if (query != null) {
      return query;
    }

    query = _queries[id] = PagedQuery<T, P>(id);

    scheduleGarbageCollection(id, const Duration(minutes: 5));

    return query;
  }

  PagedQuery<T, P>? getPagedQuery<T, P>(QueryId id) {
    assert(_queries[id] is! Query);

    return _queries[id] as PagedQuery<T, P>?;
  }

  bool exist(QueryId id) {
    return _queries[id] != null;
  }

  void remove(QueryId id) {
    _queries.remove(id);
  }

  void scheduleGarbageCollection(QueryId id, Duration duration) {
    _garbageCollectionTimers[id] = Timer(
      duration,
      () {
        _queries[id]?.close();
        remove(id);
      },
    );
  }

  void cancelGarbageCollection(QueryId id) {
    _garbageCollectionTimers[id]?.cancel();
  }

  void dispose() {
    _garbageCollectionTimers.values.forEach((timer) => timer.cancel());
  }
}
