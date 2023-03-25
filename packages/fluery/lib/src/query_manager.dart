import 'package:fluery/fluery.dart';
import 'package:fluery/src/base_query.dart';
import 'package:fluery/src/infinite_query_builder.dart';

class QueryManager {
  QueryManager({
    required this.cacheStorage,
  });

  final QueryCacheStorage cacheStorage;

  final Map<QueryIdentifier, BaseQuery> _queries = {};

  Query<Data> createQueryIfAbsent<Data>(QueryIdentifier id) {
    return _queries.putIfAbsent(
      id,
      () => Query<Data>(id: id, cacheStorage: cacheStorage),
    ) as Query<Data>;
  }

  InfiniteQuery<Data, Params> createInfiniteQueryIfAbsent<Data, Params>(
    QueryIdentifier id,
  ) {
    return _queries.putIfAbsent(
      id,
      () => InfiniteQuery<Data, Params>(id: id, cacheStorage: cacheStorage),
    ) as InfiniteQuery<Data, Params>;
  }

  BaseQuery? get(QueryIdentifier id) {
    return _queries[id];
  }

  void subscribeToQuery<Data>(
    QueryIdentifier id,
    QueryController<Data> controller,
  ) {
    createQueryIfAbsent<Data>(id).subscribe(controller);
  }

  void subscribeToInfiniteQuery<Data, Params>(
    QueryIdentifier id,
    InfiniteQueryController<Data, Params> controller,
  ) {
    createInfiniteQueryIfAbsent<Data, Params>(id).subscribe(controller);
  }

  void unsubscribe(
    QueryIdentifier id,
    BaseQueryController controller,
  ) {
    get(id)?.unsubscribe(controller);
  }
}
