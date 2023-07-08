import 'package:flutter_query/flutter_query.dart';

class QueryClient {
  final QueryCacheStorage cacheStorage = QueryCacheStorage();

  Future close() async {
    await Future.wait(cacheStorage.queries.map((q) => q.close()));
  }
}
