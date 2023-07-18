import 'package:flutter_query/flutter_query.dart';
import 'package:flutter_query/src/hooks/use_paged_query.dart';

class QueryClient {
  final QueryCache cache = QueryCache();

  final List<PagedQueryParameter> pagedQueryParameters = [];

  final Map<QueryKey, Set<QueryOptions>> _queryOptions = {};

  Future refetch(QueryKey key) async {
    final query = cache.getQuery(key);
    final pagedQuery = cache.getPagedQuery(key);

    assert(
      !(query != null && pagedQuery != null),
      'Duplicate keys are found for both $Query and $PagedQuery',
    );

    if (query != null) {
      final options = _queryOptions[key] ?? {};
      if (options.isEmpty) return;

      final fetcher = options.first.fetcher;
      final staleDuration = options.fold<Duration>(
        options.first.staleDuration,
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

  void addQueryOptions(QueryOptions options) {
    _queryOptions[options.key] = {...?_queryOptions[options.key], options};
  }

  void removeQueryOptions(QueryOptions options) {
    _queryOptions[options.key]?.remove(options);
  }

  Set<QueryOptions>? getQueryOptions(QueryKey key) {
    return _queryOptions[key];
  }
}
