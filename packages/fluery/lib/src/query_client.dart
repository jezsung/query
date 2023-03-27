import 'package:fluery/src/base_query.dart';
import 'package:fluery/src/query_cache_storage.dart';
import 'package:fluery/src/query_manager.dart';

class QueryClient {
  QueryClient({
    this.cacheStorage,
  }) : manager = QueryManager(cacheStorage: cacheStorage);

  final QueryManager manager;
  final QueryCacheStorage? cacheStorage;

  Future<void> refetch(QueryIdentifier id) async {
    final query = manager.buildQuery(id);
    final controllers = query.controllers;

    if (controllers.isEmpty) {
      return;
    }

    final fetcher = controllers.first.fetcher;
    final staleDuration = controllers.fold(
      controllers.first.staleDuration,
      (duration, controller) => controller.staleDuration < duration
          ? controller.staleDuration
          : duration,
    );

    await query.fetch(
      fetcher: fetcher,
      staleDuration: staleDuration,
    );
  }
}
