import 'package:query/query.dart';

class QueryCacheStorage {
  final Map<QueryId, Query> _queries = <QueryId, Query>{};

  List<Query> get queries => _queries.values.toList();

  Query<T> build<T>(QueryId id) {
    return (_queries[id] ??= Query<T>(id)) as Query<T>;
  }

  Query<T>? get<T>(QueryId id) {
    return _queries[id] as Query<T>?;
  }

  bool exist(QueryId id) {
    return _queries[id] != null;
  }

  void remove(QueryId id) {
    _queries.remove(id);
  }
}
