import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'query.dart';
import 'query_client.dart';
import 'query_key.dart';
import 'query_options.dart';
import 'query_state.dart';

class QueryCache {
  late final QueryClient _client;
  final Map<QueryKey, Query> _queries = {};

  /// Sets the QueryClient that owns this cache.
  ///
  /// This is called by QueryClient during construction to establish
  /// a back-reference needed for passing the client to Query instances.
  @internal
  set client(QueryClient client) => _client = client;

  /// Builds or retrieves an existing query from the cache.
  ///
  /// This matches TanStack Query's build method - gets existing query or creates new one.
  Query<TData, TError> build<TData, TError>(
    QueryOptions<TData, TError> options,
  ) {
    final key = options.queryKey;
    final query = _queries[key] as Query<TData, TError>?;

    return switch (query) {
      final query? => query..options = options,
      null => _queries[key] = Query<TData, TError>(_client, options),
    };
  }

  /// Gets a query from the cache by key
  Query<TData, TError>? get<TData, TError>(List<Object?> queryKey) {
    final key = QueryKey(queryKey);
    return _queries[key] as Query<TData, TError>?;
  }

  /// Returns all queries in the cache
  List<Query> getAll() {
    return _queries.values.toList();
  }

  /// Adds a query to the cache
  void add(Query query) {
    _queries[query.key] = query;
  }

  /// Removes a query from the cache by Query object.
  ///
  /// This matches TanStack Query's pattern where Query.tryRemove() calls
  /// cache.remove(this) passing the Query object itself.
  ///
  /// Only removes if the query in the cache is the same instance to prevent
  /// race conditions where a query might have been replaced.
  void remove(Query query) {
    final key = query.key;
    final cachedQuery = _queries[key];

    // Only remove if the query in the cache is the same instance
    if (cachedQuery == query) {
      query.dispose();
      _queries.remove(key);
    }
  }

  /// Removes a query from the cache by query key.
  ///
  /// This is a convenience method for external API usage where you want to
  /// remove a query without having a reference to the Query object.
  void removeByKey(List<Object?> queryKey) {
    final key = QueryKey(queryKey);
    final query = _queries[key];
    query?.dispose();
    _queries.remove(key);
  }

  /// Clears all queries from the cache
  void clear() {
    for (final query in _queries.values) {
      query.dispose();
    }
    _queries.clear();
  }

  /// Finds a single query matching the given query key
  /// Returns null if no matching query is found
  /// [exact] defaults to true for exact key matching
  Query<TData, TError>? find<TData, TError>(
    List<Object?> queryKey, {
    bool exact = true,
    bool Function(QueryState)? predicate,
  }) {
    return _queries.values.firstWhereOrNull((q) {
      if (!q.matches(queryKey, exact: exact)) return false;
      if (predicate != null && !q.matchesWhere(predicate)) return false;
      return true;
    }) as Query<TData, TError>?;
  }

  /// Finds all queries matching the given filters
  /// Returns all queries if no filters are provided
  List<Query> findAll({
    List<Object?>? queryKey,
    bool exact = false,
    bool Function(QueryState)? predicate,
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
}
