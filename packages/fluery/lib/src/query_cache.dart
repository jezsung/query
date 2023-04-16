import 'package:fluery/fluery.dart';

class QueryCache {
  final Map<QueryIdentifier, Query> _queries = {};

  Query<Data> build<Data>(QueryIdentifier id) {
    if (exist(id)) {
      return _queries[id] as Query<Data>;
    } else {
      return _queries[id] = Query<Data>(id);
    }
  }

  Query<Data>? get<Data>(QueryIdentifier id) {
    return _queries[id] as Query<Data>?;
  }

  bool exist(QueryIdentifier id) {
    return _queries[id] != null;
  }

  void dispose() {
    for (final query in _queries.values) {
      query.dispose();
    }
  }
}
