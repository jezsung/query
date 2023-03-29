import 'package:fluery/fluery.dart';

class QueryManager {
  QueryManager({
    this.cacheStorage,
  });

  final QueryCacheStorage? cacheStorage;

  final Map<QueryIdentifier, BaseQuery> _queries = {};

  Query<Data> buildQuery<Data>(QueryIdentifier id) {
    final Query<Data> query;

    if (_queries[id] != null) {
      query = _queries[id] as Query<Data>;
    } else if (cacheStorage == null || cacheStorage!.get(id) == null) {
      query = _queries[id] = Query<Data>(id: id);
    } else {
      final json = cacheStorage!.get(id)!;
      query = Query<Data>(
        id: id,
        initialState: QueryState<Data>.fromJson(json),
      );
    }

    if (cacheStorage != null) {
      query.addObserver(cacheStorage!);
    }

    return query;
  }

  PagedQuery<Data, Params> buildPagedQuery<Data, Params>(
    QueryIdentifier id,
  ) {
    final PagedQuery<Data, Params> query;

    if (_queries[id] != null) {
      query = _queries[id] as PagedQuery<Data, Params>;
    } else if (cacheStorage == null || cacheStorage!.get(id) == null) {
      query = _queries[id] = PagedQuery<Data, Params>(id: id);
    } else {
      final json = cacheStorage!.get(id)!;
      query = PagedQuery<Data, Params>(
        id: id,
        initialState: PagedQueryState<Data>.fromJson(json),
      );
    }

    if (cacheStorage != null) {
      query.addObserver(cacheStorage!);
    }

    return query;
  }

  Query<Data>? getQuery<Data>(QueryIdentifier id) {
    return _queries[id] as Query<Data>?;
  }

  PagedQuery<Data, Params>? getPagedQuery<Data, Params>(
    QueryIdentifier id,
  ) {
    return _queries[id] as PagedQuery<Data, Params>?;
  }
}
