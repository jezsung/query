import 'default_mutation_options.dart';
import 'default_query_options.dart';
import 'mutation_cache.dart';
import 'options/expiry.dart';
import 'options/gc_duration.dart';
import 'options/retry.dart';
import 'query.dart';
import 'query_cache.dart';
import 'query_function_context.dart';
import 'query_options.dart';
import 'query_state.dart';

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
  /// Creates a QueryClient with optional cache and default options.
  ///
  /// Example:
  /// ```dart
  /// final client = QueryClient(
  ///   defaultQueryOptions: DefaultQueryOptions(
  ///     expiresIn: Expiry(minutes: 5),
  ///     retry: (retryCount, error) {
  ///       if (retryCount >= 3) return null;
  ///       return Duration(seconds: 1 << retryCount);
  ///     },
  ///   ),
  ///   defaultMutationOptions: DefaultMutationOptions(
  ///     retry: (retryCount, error) {
  ///       if (retryCount >= 1) return null;
  ///       return Duration(seconds: 1);
  ///     },
  ///   ),
  /// );
  /// ```
  QueryClient({
    QueryCache? cache,
    MutationCache? mutationCache,
    this.defaultQueryOptions = const DefaultQueryOptions(),
    this.defaultMutationOptions = const DefaultMutationOptions(),
  })  : _cache = cache ?? QueryCache(),
        _mutationCache = mutationCache ?? MutationCache() {
    _cache.setClient(this);
    _mutationCache.client = this;
  }

  final QueryCache _cache;
  final MutationCache _mutationCache;

  /// Default options applied to all queries.
  ///
  /// Note: Changing this only affects new queries. Existing queries will
  /// continue to use the options they were created with.
  DefaultQueryOptions defaultQueryOptions;

  /// Default options applied to all mutations.
  ///
  /// Note: Changing this only affects new mutations. Existing mutations will
  /// continue to use the options they were created with.
  DefaultMutationOptions defaultMutationOptions;

  /// Gets the query cache
  QueryCache get cache => _cache;

  /// Gets the mutation cache
  MutationCache get mutationCache => _mutationCache;

  /// Disposes the query client and clears all queries and mutations from the cache
  void dispose() {
    _cache.clear();
    _mutationCache.clear();
  }

  /// Fetches a query, returning cached data if fresh or fetching new data if stale.
  ///
  /// This is an imperative alternative to the useQuery hook, useful for:
  /// - Prefetching data before navigation
  /// - Fetching data in callbacks or event handlers
  /// - Server-side data fetching
  ///
  /// Unlike useQuery, [retry] defaults to no retries when not specified
  /// at either the query level or client default level.
  ///
  /// Throws if the fetch fails.
  ///
  /// Aligned with TanStack Query's `fetchQuery` method.
  Future<TData> fetchQuery<TData, TError>({
    required List<Object?> queryKey,
    required Future<TData> Function(QueryFunctionContext context) queryFn,
    Expiry? expiresIn,
    RetryResolver<TError>? retry,
    GcDuration? gcDuration,
    TData? seed,
    DateTime? seedUpdatedAt,
  }) async {
    // Create base query options (cache-level)
    final options = QueryOptions<TData, TError>(
      queryKey,
      queryFn,
      retry: retry,
      gcDuration: gcDuration,
      seed: seed,
      seedUpdatedAt: seedUpdatedAt,
    );

    // Merge with client defaults
    final mergedOptions = options.withDefaults(defaultQueryOptions);

    // fetchQuery defaults to no retry if not specified
    final effectiveOptions = QueryOptions<TData, TError>(
      mergedOptions.queryKey.parts,
      mergedOptions.queryFn,
      retry: mergedOptions.retry ?? (_, __) => null,
      gcDuration: mergedOptions.gcDuration,
      seed: mergedOptions.seed,
      seedUpdatedAt: mergedOptions.seedUpdatedAt,
    );

    final query = _cache.build<TData, TError>(effectiveOptions);

    // Use expiresIn for staleness check (observer-level concept, but used here imperatively)
    final expiresInValue =
        expiresIn ?? defaultQueryOptions.expiresIn ?? const Expiry();

    // Check if data is stale
    if (query.shouldFetch(expiresInValue)) {
      // Pass options to fetch so query updates its stored options
      // This matches TanStack Query's behavior where fetch(options) calls setOptions
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
    required Future<TData> Function(QueryFunctionContext context) queryFn,
    Expiry? expiresIn,
    RetryResolver<TError>? retry,
    GcDuration? gcDuration,
    TData? seed,
    DateTime? seedUpdatedAt,
  }) async {
    try {
      await fetchQuery<TData, TError>(
        queryKey: queryKey,
        queryFn: queryFn,
        expiresIn: expiresIn,
        retry: retry,
        gcDuration: gcDuration,
        seed: seed,
        seedUpdatedAt: seedUpdatedAt,
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
  /// - Static queries (expiresIn = never)
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
        .where((q) =>
            q.state.hasFetched &&
            q.observers.every((ob) => ob.options.expiresIn != Expiry.never) &&
            q.state.fetchStatus != FetchStatus.paused);

    await Future.wait(
      queries.map((q) => q.fetch().then((_) {}).catchError((_) {})),
    );
  }

  /// Cancels all in-progress fetches for queries matching the filters.
  ///
  /// Returns a Future that completes when all matching queries have been
  /// cancelled. Queries that are not currently fetching complete immediately.
  ///
  /// When [revert] is true (default), cancelled queries will restore their
  /// state to what it was before the fetch started.
  ///
  /// When [silent] is true, the cancellation will not trigger error callbacks
  /// or update the query's error state.
  ///
  /// Example:
  /// ```dart
  /// // Cancel all queries and wait
  /// await client.cancelQueries();
  ///
  /// // Cancel queries with a specific key prefix
  /// await client.cancelQueries(queryKey: ['users']);
  ///
  /// // Cancel silently without reverting
  /// await client.cancelQueries(queryKey: ['users'], revert: false, silent: true);
  /// ```
  ///
  /// Aligned with TanStack Query's `QueryClient.cancelQueries` method.
  Future<void> cancelQueries({
    List<Object?>? queryKey,
    bool exact = false,
    bool Function(Query)? predicate,
    bool revert = true,
    bool silent = false,
  }) async {
    final queries = _cache.findAll(
      queryKey: queryKey,
      exact: exact,
      predicate: predicate,
    );

    final futures = queries.map(
      (query) => query.cancel(revert: revert, silent: silent),
    );

    await Future.wait(futures);
  }
}
