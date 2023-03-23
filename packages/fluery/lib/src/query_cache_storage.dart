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
  QueryCacheState<Data>? get<Data>(QueryKey key);

  void set<Data>(QueryKey key, Data data);
}

class MemoryQueryCacheStorage extends QueryCacheStorage {
  final Map<QueryKey, QueryCacheState> queryCacheStates = {};

  @override
  QueryCacheState<Data>? get<Data>(QueryKey key) {
    return queryCacheStates[key] as QueryCacheState<Data>?;
  }

  @override
  void set<Data>(QueryKey key, Data data) {
    queryCacheStates[key] = QueryCacheState(
      data: data,
      updatedAt: DateTime.now(),
    );
  }
}
