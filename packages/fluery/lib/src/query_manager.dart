import 'package:fluery/fluery.dart';

class QueryManager {
  final Map<QueryIdentifier, Query> _queries = {};

  bool exist(QueryIdentifier id) {
    return _queries[id] != null;
  }

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

  void dispose() {
    for (final query in _queries.values) {
      query.dispose();
    }
  }
}
