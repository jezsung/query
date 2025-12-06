import 'dart:async';

import 'core/core.dart';

class QueryCache {
  final Map<QueryKey, Query> _queries = <QueryKey, Query>{};
  final Map<QueryKey, PagedQuery> _pagedQueries = <QueryKey, PagedQuery>{};
  final Map<QueryKey, Timer> _gcTimers = {};

  List<Query> get queries => _queries.values.toList();

  Query<T, K> buildQuery<T, K>(QueryKey<K> key) {
    assert(
      _pagedQueries[key] == null,
      'The key $key is already used by a $PagedQuery',
    );

    Query<T, K>? query = _queries[key] as Query<T, K>?;

    if (query != null) {
      return query;
    }

    query = _queries[key] = Query<T, K>(key);

    return query;
  }

  PagedQuery<T, K, P> buildPagedQuery<T extends Object, K, P>(
    QueryKey<K> key,
  ) {
    assert(
      _queries[key] == null,
      'The key $key is already used by a $PagedQuery',
    );

    PagedQuery<T, K, P>? query = _pagedQueries[key] as PagedQuery<T, K, P>?;

    if (query != null) {
      return query;
    }

    query = _pagedQueries[key] = PagedQuery<T, K, P>(key);

    return query;
  }

  Query<T, K>? getQuery<T, K>(QueryKey<K> key) {
    assert(_queries[key] is! PagedQuery);

    return _queries[key] as Query<T, K>?;
  }

  PagedQuery<T, K, P>? getPagedQuery<T extends Object, K, P>(
    QueryKey<K> key,
  ) {
    return _pagedQueries[key] as PagedQuery<T, K, P>?;
  }

  bool exist(QueryKey key) {
    return _queries[key] != null;
  }

  Future<void> remove(QueryKey key) async {
    await Future.wait([
      _queries[key]?.close(),
      _pagedQueries[key]?.close(),
    ].whereType<Future>());
    _queries.remove(key);
    _pagedQueries.remove(key);
  }

  void scheduleGc(QueryKey key, Duration duration) {
    if (_queries[key] == null && _pagedQueries[key] == null) return;

    if (duration == Duration.zero) {
      remove(key);
    } else {
      _gcTimers[key] = Timer(duration, () {
        remove(key);
      });
    }
  }

  void cancelGc(QueryKey key) {
    _gcTimers[key]?.cancel();
    _gcTimers.remove(key);
  }

  Future<void> close() async {
    for (final timer in _gcTimers.values) {
      timer.cancel();
    }
    await Future.wait([
      ..._queries.values.map((e) => e.close()),
      ..._pagedQueries.values.map((e) => e.close()),
    ]);
  }
}
