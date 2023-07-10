import 'package:flutter_query/flutter_query.dart';
import 'package:flutter_query/src/hooks/use_query.dart';

class QueryClient {
  final QueryCacheStorage cacheStorage = QueryCacheStorage();

  final List<QueryParameter> parameters = [];

  Future refetch(QueryKey key) async {
    final query = cacheStorage.getQuery(key);
    if (query == null) return;

    final paramsByKey = parameters.where((param) => param.key == key).toList();
    if (paramsByKey.isEmpty) return;

    final fetcher = paramsByKey.first.fetcher;
    final staleDuration = paramsByKey.fold<Duration>(
      paramsByKey.first.staleDuration,
      (staleDuration, param) => param.staleDuration < staleDuration
          ? param.staleDuration
          : staleDuration,
    );

    await query.fetch(
      fetcher: fetcher,
      staleDuration: staleDuration,
    );
  }

  Future close() async {
    await Future.wait(cacheStorage.queries.map((q) => q.close()));
  }
}
