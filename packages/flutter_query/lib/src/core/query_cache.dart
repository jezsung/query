import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'query.dart';
import 'query_cache_event.dart';
import 'query_key.dart';
import 'query_state.dart';
import 'subscribable.dart';

@internal
typedef QueryCacheListener = void Function(QueryCacheEvent event);

@internal
class QueryCache with Subscribable<QueryCacheListener> {
  final Map<QueryKey, Query> _queries = {};

  Query<TData, TError>? get<TData, TError>(List<Object?> queryKey) {
    final key = QueryKey(queryKey);
    return _queries[key] as Query<TData, TError>?;
  }

  List<Query> getAll() {
    return _queries.values.toList();
  }

  void add(Query query) {
    _queries[query.key] = query;
    dispatch(QueryAddedEvent(query));
  }

  void remove(Query query) {
    final key = query.key;
    final cachedQuery = _queries[key];

    // Only remove if the query in the cache is the same instance
    if (cachedQuery == query) {
      query.dispose();
      _queries.remove(key);
      dispatch(QueryRemovedEvent(query));
    }
  }

  void removeByKey(List<Object?> queryKey) {
    final key = QueryKey(queryKey);
    final query = _queries[key];
    if (query != null) {
      query.dispose();
      _queries.remove(key);
      dispatch(QueryRemovedEvent(query));
    }
  }

  void clear() {
    if (_queries.isEmpty) return;
    final queriesToRemove = _queries.values.toList();
    _queries.clear();
    for (final query in queriesToRemove) {
      query.dispose();
      dispatch(QueryRemovedEvent(query));
    }
  }

  Query<TData, TError>? find<TData, TError>(
    List<Object?> queryKey, {
    bool exact = true,
    bool Function(List<Object?> queryKey, QueryState state)? predicate,
  }) {
    return _queries.values.firstWhereOrNull((q) {
      if (!q.matches(queryKey, exact: exact)) return false;
      if (predicate != null && !q.matchesWhere(predicate)) return false;
      return true;
    }) as Query<TData, TError>?;
  }

  List<Query> findAll({
    List<Object?>? queryKey,
    bool exact = false,
    bool Function(List<Object?> queryKey, QueryState state)? predicate,
  }) {
    // If no filters provided, return all
    if (queryKey == null && predicate == null) {
      return getAll();
    }

    return _queries.values.where((query) {
      if (queryKey != null && !query.matches(queryKey, exact: exact)) {
        return false;
      }
      if (predicate != null && !query.matchesWhere(predicate)) {
        return false;
      }
      return true;
    }).toList();
  }

  void dispatch(QueryCacheEvent event) {
    notify((listener) => listener(event));
  }
}
