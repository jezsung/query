import 'package:flutter_query/flutter_query.dart';
import 'package:flutter_query/src/hooks/use_paged_query.dart';

class QueryClient {
  final QueryCache cache = QueryCache();

  final List<QueryParameter> parameters = [];
  final List<PagedQueryParameter> pagedQueryParameters = [];

  final Map<QueryKey, Set<QueryHandler>> _queryHandlers = {};

  Future refetch(QueryKey key) async {
    final query = cache.getQuery(key);
    final pagedQuery = cache.getPagedQuery(key);

    assert(
      !(query != null && pagedQuery != null),
      'Duplicate keys are found for both $Query and $PagedQuery',
    );

    if (query != null) {
      final handlers = _queryHandlers[key] ?? {};
      if (handlers.isEmpty) return;

      final fetcher = handlers.first.fetcher;
      final staleDuration = handlers.fold<Duration>(
        handlers.first.staleDuration,
        (staleDuration, param) => param.staleDuration < staleDuration
            ? param.staleDuration
            : staleDuration,
      );

      await query.fetch(
        fetcher: fetcher,
        staleDuration: staleDuration,
      );

      return;
    }

    if (pagedQuery != null) {
      final paramsByKey =
          pagedQueryParameters.where((param) => param.key == key).toList();
      if (paramsByKey.isEmpty) return;

      final fetcher = paramsByKey.first.fetcher;
      final nextPageParamBuilder = paramsByKey.first.nextPageParamBuilder;
      final previousPageParamBuilder =
          paramsByKey.first.previousPageParamBuilder;
      final staleDuration = paramsByKey.fold<Duration>(
        paramsByKey.first.staleDuration,
        (staleDuration, param) => param.staleDuration < staleDuration
            ? param.staleDuration
            : staleDuration,
      );

      await pagedQuery.fetch(
        fetcher: fetcher,
        nextPageParamBuilder: nextPageParamBuilder,
        previousPageParamBuilder: previousPageParamBuilder,
        staleDuration: staleDuration,
      );

      return;
    }
  }

  Future cancel(QueryKey key) async {
    final query = cache.getQuery(key);
    final pagedQuery = cache.getPagedQuery(key);

    assert(
      !(query != null && pagedQuery != null),
      'Duplicate keys are found for both $Query and $PagedQuery',
    );

    if (query != null) {
      await query.cancel();
    } else if (pagedQuery != null) {
      await pagedQuery.cancel();
    }
  }

  void addQueryHandler(QueryHandler handler) {
    _queryHandlers[handler.key] = {...?_queryHandlers[handler.key], handler};
  }

  void removeQueryHandler(QueryHandler handler) {
    _queryHandlers[handler.key]?.remove(handler);
  }

  Set<QueryHandler>? getQueryHandlers(QueryKey key) {
    return _queryHandlers[key];
  }

  Future close() async {
    await Future.wait(cache.queries.map((q) => q.close()));
  }
}
