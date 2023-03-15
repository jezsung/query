import 'package:fluery/src/query.dart';

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
  QueryCacheState? get(QueryKey key);

  void set<Data>(QueryKey key, Data data);
}

class MemoryQueryCacheStorage extends QueryCacheStorage {
  final Map<QueryKey, QueryCacheState> queryCacheStates = {};

  @override
  QueryCacheState? get(QueryKey key) {
    return queryCacheStates[key];
  }

  @override
  void set<Data>(QueryKey key, Data data) {
    queryCacheStates[key] = QueryCacheState(
      data: data,
      updatedAt: DateTime.now(),
    );
  }
}
