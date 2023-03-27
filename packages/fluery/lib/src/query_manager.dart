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

  PaginatedQuery<Data, Params> buildPaginatedQuery<Data, Params>(
    QueryIdentifier id,
  ) {
    final PaginatedQuery<Data, Params> query;

    if (_queries[id] != null) {
      query = _queries[id] as PaginatedQuery<Data, Params>;
    } else if (cacheStorage == null || cacheStorage!.get(id) == null) {
      query = _queries[id] = PaginatedQuery<Data, Params>(id: id);
    } else {
      final json = cacheStorage!.get(id)!;
      query = PaginatedQuery<Data, Params>(
        id: id,
        initialState: PaginatedQueryState<Data>.fromJson(json),
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

  PaginatedQuery<Data, Params>? getPaginatedQuery<Data, Params>(
    QueryIdentifier id,
  ) {
    return _queries[id] as PaginatedQuery<Data, Params>?;
  }

  void addControllerToQuery<Data>(
    QueryIdentifier id,
    QueryController<Data> controller,
  ) {
    buildQuery<Data>(id).addObserver<QueryController<Data>>(controller);
  }

  void removeControllerFromQuery<Data>(
    QueryIdentifier id,
    QueryController<Data> controller,
  ) {
    getQuery<Data>(id)?.removeObserver<QueryController<Data>>(controller);
  }

  void addControllerToPaginatedQuery<Data, Params>(
    QueryIdentifier id,
    PaginatedQueryController<Data, Params> controller,
  ) {
    buildPaginatedQuery<Data, Params>(id)
        .addObserver<PaginatedQueryController<Data, Params>>(controller);
  }

  void removeControllerFromPaginatedQuery<Data, Params>(
    QueryIdentifier id,
    PaginatedQueryController<Data, Params> controller,
  ) {
    getPaginatedQuery<Data, Params>(id)
        ?.removeObserver<PaginatedQueryController<Data, Params>>(controller);
  }
}
