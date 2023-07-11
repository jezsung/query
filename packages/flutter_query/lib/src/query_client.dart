import 'package:flutter_query/flutter_query.dart';

class QueryClient {
  final QueryCache cache = QueryCache();

  final List<QueryParameter> parameters = [];

  Future refetch(QueryKey key) async {
    final query = cache.getQuery(key);
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

  Future cancel(QueryKey key) async {
    final query = cache.getQuery(key);
    if (query == null) return;

    await query.cancel();
  }

  Future close() async {
    await Future.wait(cache.queries.map((q) => q.close()));
  }
}
