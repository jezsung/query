import 'package:fluery/src/query.dart';
import 'package:fluery/src/query_builder.dart';
import 'package:fluery/src/query_cache_storage.dart';

class QueryClient {
  QueryClient({
    required QueryCacheStorage cacheStorage,
  }) : _cacheStorage = cacheStorage;

  final QueryCacheStorage _cacheStorage;
  
  final Map<QueryKey, Query> _queries = {};
  final Map<QueryKey, List<QueryController>> _queryControllers = {};

  Future<void> refetch(QueryKey key) async {
    final query = _queries[key];
    final controllers = _queryControllers[key];

    if (query == null) {
      return;
    }
    if (controllers == null || controllers.isEmpty) {
      return;
    }

    final effectiveFetcher = controllers.first.fetcher;
    final effectiveStaleDuration = controllers.fold(
      controllers.first.staleDuration,
      (duration, controller) => controller.staleDuration < duration
          ? controller.staleDuration
          : duration,
    );

    await query.fetch(
      fetcher: effectiveFetcher,
      staleDuration: effectiveStaleDuration,
    );
  }

  Query<Data> build<Data>(QueryKey key) {
    if (_queries[key] == null) {
      _queries[key] = Query<Data>(
        key: key,
        cacheStorage: _cacheStorage,
      );
    }
    return _queries[key] as Query<Data>;
  }

  void addController<Data>(QueryController<Data> controller) {
    _queryControllers[controller.key] = [
      ...?_queryControllers[controller.key],
      controller
    ];
  }

  bool removeController<Data>(QueryController<Data> controller) {
    return _queryControllers[controller.key]?.remove(controller) ?? false;
  }

  void dispose() {
    for (final query in _queries.values) {
      query.dispose();
    }
  }
}
