import 'default_mutation_options.dart';
import 'default_query_options.dart';
import 'infinite_query_function_context.dart';
import 'infinite_query_observer_options.dart';
import 'mutation_cache.dart';
import 'query_cache.dart';
import 'query_function_context.dart';
import 'query_observer.dart';
import 'query_options.dart';
import 'query_state.dart';

class QueryClient {
  /// Creates a QueryClient with optional cache and default options.
  ///
  /// Example:
  /// ```dart
  /// final client = QueryClient(
  ///   defaultQueryOptions: DefaultQueryOptions(
  ///     staleDuration: StaleDuration(minutes: 5),
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
    _cache.client = this;
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

  /// Clears all queries and mutations from the cache.
  void clear() {
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
  Future<TData> fetchQuery<TData, TError>(
    List<Object?> queryKey,
    QueryFn<TData> queryFn, {
    StaleDuration? staleDuration,
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

    // Use staleDuration for staleness check (observer-level concept, but used here imperatively)
    final staleDurationValue =
        staleDuration ?? defaultQueryOptions.staleDuration;

    // Check if data is stale
    if (query.shouldFetch(staleDurationValue)) {
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
  Future<void> prefetchQuery<TData, TError>(
    List<Object?> queryKey,
    QueryFn<TData> queryFn, {
    StaleDuration? staleDuration,
    RetryResolver<TError>? retry,
    GcDuration? gcDuration,
    TData? seed,
    DateTime? seedUpdatedAt,
  }) async {
    try {
      await fetchQuery<TData, TError>(
        queryKey,
        queryFn,
        staleDuration: staleDuration,
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

  /// Returns the state for a query if it exists in the cache.
  ///
  /// This is an imperative way to retrieve the full query state by exact query key.
  /// Returns `null` if the query doesn't exist in the cache.
  ///
  /// Use this when you need access to more than just the data, such as:
  /// - `status` - whether the query is pending, success, or error
  /// - `fetchStatus` - whether a fetch is in progress
  /// - `error` - the error if the query failed
  /// - `dataUpdatedAt` - when the data was last updated
  /// - `isInvalidated` - whether the query has been invalidated
  QueryState<TData, TError>? getQueryState<TData, TError>(
    List<Object?> queryKey,
  ) {
    return _cache.get<TData, TError>(queryKey)?.state;
  }

  /// Sets or updates the data for a query in the cache.
  ///
  /// This is an imperative way to update cached data by exact query key.
  /// The [updater] can be either a new value or a function that receives
  /// the previous data and returns the new data.
  ///
  /// Returns `null` if the updater function returns `null`.
  ///
  /// If the query doesn't exist and the updater provides data, a new query
  /// entry is created in the cache.
  ///
  /// Use this for optimistic updates in mutation callbacks or for manually
  /// populating the cache.
  ///
  /// Example:
  /// ```dart
  /// // Set data directly
  /// client.setQueryData<User, Error>(['user', userId], (_) => newUser);
  ///
  /// // Update data using previous value
  /// client.setQueryData<User, Error>(['user', userId], (previous) {
  ///   if (previous == null) return null;
  ///   return previous.copyWith(name: 'New Name');
  /// });
  ///
  /// // Optimistic update in a mutation
  /// onMutate: (newTodo) async {
  ///   await client.cancelQueries(queryKey: ['todos']);
  ///   final previousTodos = client.getQueryData<List<Todo>, Error>(['todos']);
  ///   client.setQueryData<List<Todo>, Error>(
  ///     ['todos'],
  ///     (previous) => [...?previous, newTodo],
  ///   );
  ///   return previousTodos;
  /// }
  /// ```
  TData? setQueryData<TData, TError>(
    List<Object?> queryKey,
    TData? Function(TData? previousData) updater, {
    DateTime? updatedAt,
  }) {
    final query = _cache.get<TData, TError>(queryKey);
    final previousData = query?.state.data;
    final data = updater(previousData);

    if (data == null) {
      return null;
    }

    if (query != null) {
      return query.setData(data, updatedAt: updatedAt);
    }

    return _cache
        .build<TData, TError>(QueryOptions<TData, TError>(
          queryKey,
          (_) => throw UnsupportedError(
            'Query was created via setQueryData and has no queryFn. '
            'Use fetchQuery or useQuery with a queryFn to fetch data.',
          ),
        )..withDefaults(defaultQueryOptions))
        .setData(data, updatedAt: updatedAt);
  }

  /// Invalidates queries matching the filters.
  ///
  /// Invalidation marks queries as stale, causing them to refetch when an
  /// observer mounts that subscribes to the query. This method does not
  /// automatically refetch queries - use [refetchQueries] if you need to
  /// trigger an immediate refetch.
  ///
  /// Example:
  /// ```dart
  /// // Invalidate all queries
  /// await client.invalidateQueries();
  ///
  /// // Invalidate queries with a specific key prefix
  /// await client.invalidateQueries(queryKey: ['users']);
  ///
  /// // Invalidate and refetch active queries
  /// await client.invalidateQueries(queryKey: ['users']);
  /// await client.refetchQueries(
  ///   queryKey: ['users'],
  ///   predicate: (state) => state.isActive,
  /// );
  /// ```
  ///
  /// Aligned with TanStack Query's `QueryClient.invalidateQueries` method.
  void invalidateQueries({
    List<Object?>? queryKey,
    bool exact = false,
    bool Function(QueryState)? predicate,
  }) {
    final queries = _cache.findAll(
      queryKey: queryKey,
      exact: exact,
      predicate: predicate,
    );

    for (final query in queries) {
      query.invalidate();
    }
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
  /// // Refetch only active queries using predicate
  /// await client.refetchQueries(predicate: (q) => q.isActive);
  /// ```
  ///
  /// Aligned with TanStack Query's `QueryClient.refetchQueries` method.
  Future<void> refetchQueries({
    List<Object?>? queryKey,
    bool exact = false,
    bool Function(QueryState)? predicate,
  }) async {
    final queries = _cache
        .findAll(
          queryKey: queryKey,
          exact: exact,
          predicate: predicate,
        )
        .where((q) =>
            q.state.hasFetched &&
            q.observers.every(
                (ob) => ob.options.staleDuration != StaleDuration.static) &&
            q.state.fetchStatus != FetchStatus.paused);

    await Future.wait(
      queries.map((q) => q.fetch().then((_) {}).catchError((_) {})),
    );
  }

  // ============================================================================
  // Infinite Query Methods
  // ============================================================================

  /// Fetches an infinite query, returning cached data if fresh or fetching new data if stale.
  ///
  /// This is an imperative alternative to the useInfiniteQuery hook, useful for:
  /// - Prefetching paginated data before navigation
  /// - Fetching paginated data in callbacks or event handlers
  ///
  /// The [pages] parameter controls how many pages to fetch initially. Defaults to 1.
  ///
  /// Unlike useInfiniteQuery, [retry] defaults to no retries when not specified.
  ///
  /// Throws if the fetch fails.
  ///
  /// Aligned with TanStack Query's `fetchInfiniteQuery` method.
  Future<InfiniteData<TData, TPageParam>>
      fetchInfiniteQuery<TData, TError, TPageParam>(
    List<Object?> queryKey,
    InfiniteQueryFn<TData, TPageParam> queryFn, {
    required TPageParam initialPageParam,
    required NextPageParamBuilder<TData, TPageParam> nextPageParamBuilder,
    PrevPageParamBuilder<TData, TPageParam>? prevPageParamBuilder,
    int? maxPages,
    int pages = 1,
    StaleDuration? staleDuration,
    RetryResolver<TError>? retry,
    GcDuration? gcDuration,
    InfiniteData<TData, TPageParam>? seed,
    DateTime? seedUpdatedAt,
    Map<String, dynamic>? meta,
  }) async {
    // Create wrapped queryFn that handles page accumulation
    Future<InfiniteData<TData, TPageParam>> wrappedQueryFn(
      QueryFunctionContext context,
    ) async {
      // Get existing query to check current data
      final existingQuery =
          _cache.get<InfiniteData<TData, TPageParam>, TError>(queryKey);
      final currentData = existingQuery?.state.data;
      final oldPages = currentData?.pages ?? <TData>[];
      final oldPageParams = currentData?.pageParams ?? <TPageParam>[];

      // Determine how many pages to fetch
      final remainingPages = oldPages.isNotEmpty ? oldPages.length : pages;

      var result = InfiniteData<TData, TPageParam>(
        <TData>[],
        <TPageParam>[],
      );
      var currentPage = 0;

      while (currentPage < remainingPages) {
        TPageParam param;
        if (currentPage == 0) {
          param =
              oldPageParams.isNotEmpty ? oldPageParams[0] : initialPageParam;
        } else {
          final nextParam =
              result.pages.isNotEmpty ? nextPageParamBuilder(result) : null;
          if (nextParam == null) break;
          param = nextParam;
        }

        final infiniteContext = InfiniteQueryFunctionContext<TPageParam>(
          queryKey: context.queryKey,
          client: context.client,
          signal: context.signal,
          meta: context.meta,
          pageParam: param,
          direction: FetchDirection.forward,
        );

        final page = await queryFn(infiniteContext);

        var newPages = [...result.pages, page];
        var newPageParams = [...result.pageParams, param];

        // Respect maxPages limit
        if (maxPages != null && newPages.length > maxPages) {
          newPages = newPages.sublist(1);
          newPageParams = newPageParams.sublist(1);
        }

        result = InfiniteData(newPages, newPageParams);
        currentPage++;
      }

      return result;
    }

    // Create options with wrapped queryFn
    final options = QueryOptions<InfiniteData<TData, TPageParam>, TError>(
      queryKey,
      wrappedQueryFn,
      retry: retry,
      gcDuration: gcDuration,
      seed: seed,
      seedUpdatedAt: seedUpdatedAt,
      meta: meta,
    );

    // Merge with client defaults
    final mergedOptions = options.withDefaults(defaultQueryOptions);

    // fetchInfiniteQuery defaults to no retry if not specified
    final effectiveOptions =
        QueryOptions<InfiniteData<TData, TPageParam>, TError>(
      mergedOptions.queryKey.parts,
      mergedOptions.queryFn,
      retry: mergedOptions.retry ?? (_, __) => null,
      gcDuration: mergedOptions.gcDuration,
      seed: mergedOptions.seed,
      seedUpdatedAt: mergedOptions.seedUpdatedAt,
      meta: mergedOptions.meta,
    );

    final query =
        _cache.build<InfiniteData<TData, TPageParam>, TError>(effectiveOptions);

    // Use staleDuration for staleness check
    final staleDurationValue =
        staleDuration ?? defaultQueryOptions.staleDuration;

    // Check if data is stale
    if (query.shouldFetch(staleDurationValue)) {
      return query.fetch();
    }

    // Data is fresh, return cached data
    return query.state.data!;
  }

  /// Prefetches an infinite query and populates the cache.
  ///
  /// Unlike [fetchInfiniteQuery], this method:
  /// - Returns `Future<void>` instead of the data
  /// - Silently ignores any errors (fire-and-forget pattern)
  ///
  /// Use this for preloading paginated data before navigation.
  ///
  /// Aligned with TanStack Query's `prefetchInfiniteQuery` method.
  Future<void> prefetchInfiniteQuery<TData, TError, TPageParam>(
    List<Object?> queryKey,
    InfiniteQueryFn<TData, TPageParam> queryFn, {
    required TPageParam initialPageParam,
    required NextPageParamBuilder<TData, TPageParam> nextPageParamBuilder,
    PrevPageParamBuilder<TData, TPageParam>? prevPageParamBuilder,
    int? maxPages,
    int pages = 1,
    StaleDuration? staleDuration,
    RetryResolver<TError>? retry,
    GcDuration? gcDuration,
    InfiniteData<TData, TPageParam>? seed,
    DateTime? seedUpdatedAt,
    Map<String, dynamic>? meta,
  }) async {
    try {
      await fetchInfiniteQuery<TData, TError, TPageParam>(
        queryKey,
        queryFn,
        initialPageParam: initialPageParam,
        nextPageParamBuilder: nextPageParamBuilder,
        prevPageParamBuilder: prevPageParamBuilder,
        maxPages: maxPages,
        pages: pages,
        staleDuration: staleDuration,
        retry: retry,
        gcDuration: gcDuration,
        seed: seed,
        seedUpdatedAt: seedUpdatedAt,
        meta: meta,
      );
    } catch (_) {
      // Silently ignore errors - prefetch is fire-and-forget
    }
  }

  /// Returns the data for an infinite query if it exists in the cache.
  ///
  /// Returns `null` if the query doesn't exist or has no data yet.
  ///
  /// Use this for reading cached paginated data in callbacks or for optimistic updates.
  /// Do not use inside widgets - use `useInfiniteQuery` instead for reactive updates.
  ///
  /// Aligned with TanStack Query's `getQueryData` method for infinite queries.
  InfiniteData<TData, TPageParam>?
      getInfiniteQueryData<TData, TError, TPageParam>(List<Object?> queryKey) {
    return _cache
        .get<InfiniteData<TData, TPageParam>, TError>(queryKey)
        ?.state
        .data;
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
    bool Function(QueryState)? predicate,
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
