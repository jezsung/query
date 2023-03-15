import 'package:fluery/src/query.dart';
import 'package:fluery/src/query_cache_storage.dart';

class QueryClient {
  QueryClient({
    required this.cacheStorage,
  });

  final QueryCacheStorage cacheStorage;

  final List<Query> queries = [];

  Query<Data> build<Data>(QueryKey key) {
    return queries.singleWhere(
      (q) => q.key == key,
      orElse: () {
        final query = Query<Data>(
          key: key,
          cacheStorage: cacheStorage,
        );
        queries.add(query);
        return query;
      },
    ) as Query<Data>;
  }

  Future<void> refetch(QueryKey key) async {
    try {
      await queries.singleWhere((q) => q.key == key).fetch();
    } on StateError {
      // No matching query is found.
    }
  }

  void dispose() {
    for (final Query query in queries) {
      query.dispose();
    }
  }
}
