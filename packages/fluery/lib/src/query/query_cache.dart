part of 'index.dart';

class QueryCache {
  final Map<QueryIdentifier, QueryBase> _queries = {};

  Query<T> build<T>(
    QueryIdentifier id, {
    QueryState<T>? initialState,
  }) {
    if (_queries[id] != null) {
      return _queries[id] as Query<T>;
    } else {
      return _queries[id] = Query<T>(
        id: id,
        cache: this,
        initialState: initialState,
      );
    }
  }

  PagedQuery<T, P> buildPagedQuery<T, P>(
    QueryIdentifier id, {
    PagedQueryState<T, P>? initialState,
  }) {
    return (_queries[id] as PagedQuery<T, P>?) ??
        PagedQuery<T, P>(
          id: id,
          cache: this,
          initialState: initialState,
        );
  }

  Query<T>? get<T>(QueryIdentifier id) {
    return _queries[id] as Query<T>?;
  }

  bool exist(QueryIdentifier id) {
    return _queries[id] != null;
  }

  void remove(QueryIdentifier id) {
    _queries.remove(id);
  }

  Future<void> close() async {
    await Future.wait([for (final query in _queries.values) query.close()]);
  }
}
