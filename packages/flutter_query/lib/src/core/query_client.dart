import 'options/gc_duration.dart';
import 'options/retry.dart';
import 'options/retry_delay.dart';
import 'options/stale_duration.dart';
import 'query.dart';
import 'query_cache.dart';
import 'query_context.dart';
import 'query_observer.dart';

/// Controls which queries get refetched after invalidation.
///
/// Aligned with TanStack Query's `refetchType` option in `InvalidateQueryFilters`.
enum RefetchType {
  /// Don't refetch any queries, just mark them as invalidated
  none,

  /// Refetch all matching queries
  all,

  /// Refetch only active queries (queries with enabled observers)
  active,

  /// Refetch only inactive queries (queries without enabled observers)
  inactive,
}

class QueryClient {
  QueryClient({QueryCache? cache}) : _cache = cache ?? QueryCache() {
    _cache.setClient(this);
  }

  final QueryCache _cache;

  /// Gets the query cache
  QueryCache get cache => _cache;

  /// Disposes the query client and clears all queries from the cache
  void dispose() {
    _cache.clear();
  }

  /// Fetches a query, returning cached data if fresh or fetching new data if stale.
  ///
  /// This is an imperative alternative to the useQuery hook, useful for:
  /// - Prefetching data before navigation
  /// - Fetching data in callbacks or event handlers
  /// - Server-side data fetching
  ///
  /// Unlike useQuery, [retry] defaults to [Retry.never()] (no retries).
  ///
  /// Throws if the fetch fails.
  ///
  /// Aligned with TanStack Query's `fetchQuery` method.
  Future<TData> fetchQuery<TData, TError>({
    required List<Object?> queryKey,
    required Future<TData> Function(QueryContext context) queryFn,
    StaleDuration<TData, TError>? staleDuration,
    Retry<TError>? retry,
    RetryDelay<TError>? retryDelay,
    GcDurationOption gcDuration = const GcDuration(minutes: 5),
    TData? initialData,
    DateTime? initialDataUpdatedAt,
  }) async {
    final queryOptions = QueryOptions<TData, TError>(
      queryKey,
      queryFn,
      staleDuration: staleDuration,
      retry: retry ?? Retry<TError>.never(), // Default to no retry
      retryDelay: retryDelay,
      gcDuration: gcDuration,
      initialData: initialData,
      initialDataUpdatedAt: initialDataUpdatedAt,
    );

    final query = _cache.build<TData, TError>(queryOptions);

    // Check if data is stale
    if (query.isStaleByTime(staleDuration)) {
      return query.fetch();
    }

    // Data is fresh, return cached data
    return query.state.data as TData;
  }

  /// Prefetches a query and populates the cache.
  ///
  /// Unlike [fetchQuery], this method:
  /// - Returns `Future<void>` instead of the data
  /// - Silently ignores any errors (fire-and-forget pattern)
  ///
  /// Use this for preloading data before navigation or warming up the cache.
  ///
  /// Aligned with TanStack Query's `prefetchQuery` method.
  Future<void> prefetchQuery<TData, TError>({
    required List<Object?> queryKey,
    required Future<TData> Function(QueryContext context) queryFn,
    StaleDuration<TData, TError>? staleDuration,
    Retry<TError>? retry,
    RetryDelay<TError>? retryDelay,
    GcDurationOption gcDuration = const GcDuration(minutes: 5),
    TData? initialData,
    DateTime? initialDataUpdatedAt,
  }) async {
    try {
      await fetchQuery<TData, TError>(
        queryKey: queryKey,
        queryFn: queryFn,
        staleDuration: staleDuration,
        retry: retry,
        retryDelay: retryDelay,
        gcDuration: gcDuration,
        initialData: initialData,
        initialDataUpdatedAt: initialDataUpdatedAt,
      );
    } catch (_) {
      // Silently ignore errors - prefetch is fire-and-forget
    }
  }

  /// Returns the data for a query if it exists in the cache.
  ///
  /// This is an imperative way to retrieve cached data by exact query key.
  /// Returns `null` if the query doesn't exist or has no data yet.
  ///
  /// Use this for reading cached data in callbacks or for optimistic updates.
  /// Do not use inside widgets - use `useQuery` instead for reactive updates.
  ///
  /// Aligned with TanStack Query's `getQueryData` method.
  TData? getQueryData<TData, TError>(List<Object?> queryKey) {
    return _cache.get<TData, TError>(queryKey)?.state.data;
  }

  /// Invalidates queries matching the filters and optionally refetches them.
  ///
  /// Invalidation marks queries as stale, causing them to refetch when:
  /// - An observer mounts that subscribes to the query
  /// - The query is already mounted and [refetchType] is not [RefetchType.none]
  ///
  /// By default, only active queries are refetched after invalidation.
  ///
  /// Example:
  /// ```dart
  /// // Invalidate all queries
  /// await client.invalidateQueries();
  ///
  /// // Invalidate queries with a specific key prefix
  /// await client.invalidateQueries(queryKey: ['users']);
  ///
  /// // Invalidate but don't refetch
  /// await client.invalidateQueries(
  ///   queryKey: ['users'],
  ///   refetchType: RefetchType.none,
  /// );
  /// ```
  ///
  /// Aligned with TanStack Query's `QueryClient.invalidateQueries` method.
  Future<void> invalidateQueries({
    List<Object?>? queryKey,
    bool exact = false,
    bool Function(Query)? predicate,
    RefetchType refetchType = RefetchType.active,
  }) async {
    // Find and invalidate all matching queries
    final queries = _cache.findAll(
      queryKey: queryKey,
      exact: exact,
      predicate: predicate,
    );

    for (final query in queries) {
      query.invalidate();
    }

    // Skip refetch if none
    if (refetchType == RefetchType.none) return;

    // Refetch based on refetchType
    final effectiveType = switch (refetchType) {
      RefetchType.all => QueryTypeFilter.all,
      RefetchType.active => QueryTypeFilter.active,
      RefetchType.inactive => QueryTypeFilter.inactive,
      RefetchType.none => throw UnimplementedError(),
    };

    await refetchQueries(
      queryKey: queryKey,
      exact: exact,
      predicate: predicate,
      type: effectiveType,
    );
  }

  /// Refetches queries matching the filters.
  ///
  /// This method finds all queries matching the filters and triggers a refetch
  /// for each one. Unlike invalidation, this doesn't mark queries as stale -
  /// it immediately fetches fresh data.
  ///
  /// Skips:
  /// - Disabled queries (no enabled observers)
  /// - Static queries (staleDuration = static)
  /// - Paused queries (fetchStatus = paused)
  ///
  /// Example:
  /// ```dart
  /// // Refetch all queries
  /// await client.refetchQueries();
  ///
  /// // Refetch queries with a specific key prefix
  /// await client.refetchQueries(queryKey: ['users']);
  ///
  /// // Refetch only active queries
  /// await client.refetchQueries(type: QueryTypeFilter.active);
  /// ```
  ///
  /// Aligned with TanStack Query's `QueryClient.refetchQueries` method.
  Future<void> refetchQueries({
    List<Object?>? queryKey,
    bool exact = false,
    bool Function(Query)? predicate,
    QueryTypeFilter type = QueryTypeFilter.all,
  }) async {
    final queries = _cache
        .findAll(
          queryKey: queryKey,
          exact: exact,
          predicate: predicate,
          type: type,
        )
        .where((query) => !query.isDisabled() && !query.isStatic())
        .where((query) => query.state.fetchStatus != FetchStatus.paused);

    final futures = <Future<void>>[];

    for (final query in queries) {
      // Fetch and swallow errors
      futures.add(query.fetch().then((_) {}).catchError((_) {}));
    }

    await Future.wait(futures);
  }
}
