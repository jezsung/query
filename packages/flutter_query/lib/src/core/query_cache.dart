import 'package:collection/collection.dart';

import 'query.dart';
import 'query_client.dart';
import 'query_key.dart';
import 'query_options.dart';

class QueryCache {
  final Map<QueryKey, Query> _queries = {};
  QueryClient? _client;

  /// Sets the QueryClient that owns this cache.
  ///
  /// This is called by QueryClient during construction to establish
  /// a back-reference needed for passing the client to Query instances.
  void setClient(QueryClient client) {
    _client = client;
  }

  /// Builds or retrieves an existing query from the cache.
  ///
  /// This matches TanStack Query's build method - gets existing query or creates new one.
  Query<TData, TError> build<TData, TError>(
    QueryOptions<TData, TError> options,
  ) {
    final key = QueryKey(options.queryKey);
    final query = _queries[key]?.withOptions(options) as Query<TData, TError>?;
    if (query == null) {
      return _queries[key] = Query<TData, TError>(_client!, options);
    } else {
      return query;
    }
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
    final key = QueryKey(query.queryKey);
    _queries[key] = query;
  }

  /// Removes a query from the cache by Query object.
  ///
  /// This matches TanStack Query's pattern where Query.tryRemove() calls
  /// cache.remove(this) passing the Query object itself.
  ///
  /// Only removes if the query in the cache is the same instance to prevent
  /// race conditions where a query might have been replaced.
  void remove(Query query) {
    final key = QueryKey(query.queryKey);
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
    bool Function(Query)? predicate,
    QueryTypeFilter type = QueryTypeFilter.all,
  }) {
    return _queries.values.firstWhereOrNull((q) => q.matches(
          queryKey: queryKey,
          exact: exact,
          predicate: predicate,
          type: type,
        )) as Query<TData, TError>?;
  }

  /// Finds all queries matching the given filters
  /// Returns all queries if no filters are provided
  ///
  /// [type] filters by active state:
  /// - [QueryTypeFilter.all]: Return all matching queries
  /// - [QueryTypeFilter.active]: Return only queries with enabled observers
  /// - [QueryTypeFilter.inactive]: Return only queries without enabled observers
  List<Query> findAll({
    List<Object?>? queryKey,
    bool exact = false,
    bool Function(Query)? predicate,
    QueryTypeFilter type = QueryTypeFilter.all,
  }) {
    // If no filters provided, return all
    if (queryKey == null && predicate == null && type == QueryTypeFilter.all) {
      return getAll();
    }

    return _queries.values
        .where((query) => query.matches(
              queryKey: queryKey,
              exact: exact,
              predicate: predicate,
              type: type,
            ))
        .toList();
  }
}
