import 'package:fluery/src/base_query.dart';

class QueryCacheState<Data> {
  QueryCacheState({
    required this.data,
    required this.updatedAt,
  });

  final Data data;
  final DateTime updatedAt;

  bool isStale(Duration staleDuration) {
    return updatedAt.isBefore(DateTime.now().subtract(staleDuration));
  }
}

abstract class QueryCacheStorage {
  QueryCacheState<Data>? get<Data>(QueryIdentifier id);

  void set<Data>(QueryIdentifier id, Data data);
}

class MemoryQueryCacheStorage extends QueryCacheStorage {
  final Map<QueryIdentifier, QueryCacheState> queryCacheStates = {};

  @override
  QueryCacheState<Data>? get<Data>(QueryIdentifier id) {
    return queryCacheStates[id] as QueryCacheState<Data>?;
  }

  @override
  void set<Data>(QueryIdentifier id, Data data) {
    queryCacheStates[id] = QueryCacheState<Data>(
      data: data,
      updatedAt: DateTime.now(),
    );
  }
}
