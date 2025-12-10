import 'query.dart';
import 'query_key.dart';

class QueryCache {
  final Map<QueryKey, Query> _queries = {};

  /// Builds or retrieves an existing query from the cache
  Query<TData, TError> build<TData, TError>(
    List<Object?> queryKey,
    Future<TData> Function() queryFn,
  ) {
    final key = QueryKey(queryKey);
    final query = _queries[key] ??= Query<TData, TError>(queryKey, queryFn);
    return query as Query<TData, TError>;
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

  /// Removes a query from the cache
  void remove(List<Object?> queryKey) {
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
  }) {
    for (final query in _queries.values) {
      if (!_matchesFilters(query, queryKey, exact, predicate)) {
        continue;
      }
      return query as Query<TData, TError>;
    }
    return null;
  }

  /// Finds all queries matching the given filters
  /// Returns all queries if no filters are provided
  List<Query> findAll({
    List<Object?>? queryKey,
    bool exact = false,
    bool Function(Query)? predicate,
  }) {
    // If no filters provided, return all
    if (queryKey == null && predicate == null) {
      return getAll();
    }

    return _queries.values
        .where((query) => _matchesFilters(query, queryKey, exact, predicate))
        .toList();
  }

  bool _matchesFilters(
    Query query,
    List<Object?>? queryKey,
    bool exact,
    bool Function(Query)? predicate,
  ) {
    // Check predicate first if provided
    if (predicate != null && !predicate(query)) {
      return false;
    }

    // Check query key if provided
    if (queryKey != null) {
      final key = QueryKey(query.queryKey);
      final filterKey = QueryKey(queryKey);
      if (exact) {
        // Exact match
        if (key != filterKey) {
          return false;
        }
      } else {
        // Prefix match
        if (!key.startsWith(filterKey)) {
          return false;
        }
      }
    }

    return true;
  }
}
