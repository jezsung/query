import 'package:meta/meta.dart';

import 'default_mutation_options.dart';
import 'default_query_options.dart';
import 'infinite_query_function_context.dart';
import 'infinite_query_options.dart';
import 'mutation_cache.dart';
import 'mutation_state.dart';
import 'query.dart';
import 'query_cache.dart';
import 'query_function_context.dart';
import 'query_observer.dart';
import 'query_options.dart';
import 'query_state.dart';
import 'utils.dart';

/// Provides imperative methods to fetch, prefetch, invalidate, and update
/// cached data with configurable defaults.
///
/// ```dart
/// final client = QueryClient(
///   defaultQueryOptions: DefaultQueryOptions(
///     staleDuration: StaleDuration(minutes: 5),
///     retry: (retryCount, error) {
///       if (retryCount >= 3) return null;
///       return Duration(seconds: 1 << retryCount);
///     },
///   ),
/// );
/// ```
class QueryClient {
  /// Creates a client with optional default options for queries and mutations.
  ///
  /// The [connectivityChanges] stream enables automatic refetching when network
  /// connectivity is restored. The stream should emit `true` when online and
  /// `false` when offline. If not provided, the [refetchOnReconnect] option
  /// has no effect.
  ///
  /// The stream should emit the current connectivity state immediately upon
  /// subscription. This ensures that if the app starts offline, the transition
  /// to online will correctly trigger a reconnect. Most connectivity packages
  /// (like `connectivity_plus`) emit the current state on subscribe by default.
  ///
  /// Example using connectivity_plus:
  /// ```dart
  /// final client = QueryClient(
  ///   connectivityChanges: Connectivity().onConnectivityChanged.map(
  ///     (results) => !results.contains(ConnectivityResult.none),
  ///   ),
  /// );
  /// ```
  QueryClient({
    this.defaultQueryOptions = const DefaultQueryOptions(),
    this.defaultMutationOptions = const DefaultMutationOptions(),
    Stream<bool>? connectivityChanges,
  }) {
    connectivityChanges?.listen((isOnline) {
      if (!_wasOnline && isOnline) {
        for (final observer in _cache.getAll().expand((q) => q.observers)) {
          observer.onReconnect();
        }
      }
      _wasOnline = isOnline;
    });
  }

  final QueryCache _cache = QueryCache();
  final MutationCache _mutationCache = MutationCache();
  bool _wasOnline = true;

  /// The default options applied to all new queries.
  ///
  /// Changing this property only affects queries created after the change.
  /// Existing queries continue using the options they were created with.
  DefaultQueryOptions defaultQueryOptions;

  /// The default options applied to all new mutations.
  ///
  /// Changing this property only affects mutations created after the change.
  /// Existing mutations continue using the options they were created with.
  DefaultMutationOptions defaultMutationOptions;

  /// The query cache managed by this client.
  @internal
  QueryCache get cache => _cache;

  /// The mutation cache managed by this client.
  @internal
  MutationCache get mutationCache => _mutationCache;

  /// Removes all queries and mutations from the cache.
  void clear() {
    _cache.clear();
    _mutationCache.clear();
  }

  /// Fetches a query, returning cached data if fresh or new data if stale.
  ///
  /// This is an imperative alternative to `useQuery`, useful for prefetching
  /// data before navigation, fetching in callbacks, or server-side data
  /// fetching.
  ///
  /// The [queryKey] uniquely identifies this query in the cache. The [queryFn]
  /// is called to fetch data when the cache is empty or stale.
  ///
  /// The [staleDuration] determines how long data is considered fresh. If not
  /// specified, uses the value from [defaultQueryOptions].
  ///
  /// The [retry] resolver determines retry behavior on failure. Defaults to no
  /// retries when not specified at either the query level or in
  /// [defaultQueryOptions].
  ///
  /// The [gcDuration] controls how long unused queries remain in cache before
  /// garbage collection.
  ///
  /// The [seed] provides initial data for the query, with [seedUpdatedAt]
  /// specifying when that seed was last updated.
  ///
  /// Throws if the fetch fails.
  Future<TData> fetchQuery<TData, TError>(
    List<Object?> queryKey,
    QueryFn<TData> queryFn, {
    StaleDuration? staleDuration,
    RetryResolver<TError>? retry,
    GcDuration? gcDuration,
    TData? seed,
    DateTime? seedUpdatedAt,
    Map<String, dynamic>? meta,
  }) async {
    final query = Query<TData, TError>.cached(
      this,
      queryKey,
      gcDuration: gcDuration,
      seed: seed,
      seedUpdatedAt: seedUpdatedAt,
    );

    if (query.shouldFetch(staleDuration ?? defaultQueryOptions.staleDuration)) {
      return query.fetch(
        queryFn,
        gcDuration: gcDuration,
        retry: retry ?? defaultQueryOptions.retry ?? retryNever,
        meta: meta ?? defaultQueryOptions.meta,
      );
    }

    return query.state.data as TData;
  }

  /// Prefetches a query and populates the cache without returning data.
  ///
  /// Unlike [fetchQuery], this method returns `Future<void>` and silently
  /// ignores any errors, making it suitable for preloading data before
  /// navigation or warming up the cache.
  ///
  /// See [fetchQuery] for parameter descriptions.
  Future<void> prefetchQuery<TData, TError>(
    List<Object?> queryKey,
    QueryFn<TData> queryFn, {
    StaleDuration? staleDuration,
    RetryResolver<TError>? retry,
    GcDuration? gcDuration,
    TData? seed,
    DateTime? seedUpdatedAt,
    Map<String, dynamic>? meta,
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
        meta: meta,
      );
    } catch (_) {
      // Silently ignore errors - prefetch is fire-and-forget
    }
  }

  /// The cached data for a query, or `null` if not found.
  ///
  /// The [queryKey] must exactly match a query in the cache. Use this for
  /// reading cached data in callbacks or for optimistic updates.
  ///
  /// For reactive updates in widgets, use `useQuery` instead.
  TData? getQueryData<TData>(List<Object?> queryKey) {
    return _cache.get<TData, dynamic>(queryKey)?.state.data;
  }

  /// The full state for a query, or `null` if not found.
  ///
  /// The [queryKey] must exactly match a query in the cache. Use this when you
  /// need more than just data, such as `status`, `fetchStatus`, `error`,
  /// `dataUpdatedAt`, or `isInvalidated`.
  QueryState<TData, TError>? getQueryState<TData, TError>(
    List<Object?> queryKey,
  ) {
    return _cache.get<TData, TError>(queryKey)?.state;
  }

  /// Sets or updates cached data for a query.
  ///
  /// The [queryKey] identifies which query to update. The [updater] function
  /// receives the previous data (or `null` if none exists) and returns the new
  /// data. Returns `null` if [updater] returns `null`.
  ///
  /// The optional [updatedAt] timestamp specifies when the data was updated.
  /// Defaults to the current time.
  ///
  /// If the query does not exist and [updater] provides data, a new query
  /// entry is created in the cache.
  ///
  /// ```dart
  /// // Set data directly
  /// client.setQueryData<User, Error>(['user', userId], (_) => newUser);
  ///
  /// // Update using previous value
  /// client.setQueryData<User, Error>(['user', userId], (previous) {
  ///   if (previous == null) return null;
  ///   return previous.copyWith(name: 'New Name');
  /// });
  /// ```
  TData? setQueryData<TData, TError>(
    List<Object?> queryKey,
    TData? Function(TData? previousData) updater, {
    DateTime? updatedAt,
  }) {
    final query = Query<TData, TError>.cached(this, queryKey);

    final previousData = query.state.data;
    final data = updater(previousData);

    if (data == null) {
      return null;
    }

    return query.setData(data, updatedAt: updatedAt);
  }

  /// Marks matching queries as stale.
  ///
  /// Invalidated queries refetch when a new observer subscribes to them. This
  /// method does not trigger an immediate refetch; use [refetchQueries] for
  /// that.
  ///
  /// The [queryKey] filters which queries to invalidate. When [exact] is false
  /// (default), all queries whose keys start with [queryKey] are included.
  /// When true, only queries with an exactly matching key are invalidated.
  ///
  /// The [predicate] function provides additional filtering based on query
  /// state. Only queries for which it returns true are invalidated.
  ///
  /// ```dart
  /// // Invalidate all queries
  /// client.invalidateQueries();
  ///
  /// // Invalidate queries with a specific key prefix
  /// client.invalidateQueries(queryKey: ['users']);
  /// ```
  void invalidateQueries({
    List<Object?>? queryKey,
    bool exact = false,
    bool Function(List<Object?> queryKey, QueryState state)? predicate,
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

  /// Triggers an immediate refetch for matching queries.
  ///
  /// Unlike [invalidateQueries], this fetches fresh data immediately rather
  /// than marking queries as stale.
  ///
  /// The [queryKey] filters which queries to refetch. When [exact] is false
  /// (default), all queries whose keys start with [queryKey] are included.
  /// When true, only queries with an exactly matching key are refetched.
  ///
  /// The [predicate] function provides additional filtering based on query
  /// state. Only queries for which it returns true are refetched.
  ///
  /// Queries are skipped if they are disabled, static, or paused.
  ///
  /// ```dart
  /// // Refetch all queries
  /// await client.refetchQueries();
  ///
  /// // Refetch queries with a specific key prefix
  /// await client.refetchQueries(queryKey: ['users']);
  /// ```
  Future<void> refetchQueries({
    List<Object?>? queryKey,
    bool exact = false,
    bool Function(List<Object?> queryKey, QueryState state)? predicate,
  }) async {
    final queries = _cache
        .findAll(
          queryKey: queryKey,
          exact: exact,
          predicate: predicate,
        )
        .where((q) =>
            q.isActive &&
            !q.isStatic &&
            q.state.fetchStatus != FetchStatus.paused);

    await Future.wait(queries.map((q) {
      final observer = q.observers.first;
      return q
          .fetch(
            observer.options.queryFn,
            retry: observer.options.retry,
            meta: observer.options.meta,
          )
          .suppress();
    }));
  }

  /// Fetches an infinite query, returning cached data if fresh or new data if stale.
  ///
  /// This is an imperative alternative to `useInfiniteQuery`, useful for
  /// prefetching paginated data before navigation or fetching in callbacks.
  ///
  /// The [queryKey] uniquely identifies this query in the cache. The [queryFn]
  /// is called to fetch each page of data.
  ///
  /// The [initialPageParam] is used for the first page. The
  /// [nextPageParamBuilder] derives parameters for subsequent pages from the
  /// current data. The optional [prevPageParamBuilder] enables fetching
  /// previous pages.
  ///
  /// The [maxPages] limits how many pages are kept in memory, dropping the
  /// oldest pages when exceeded. The [pages] parameter controls how many pages
  /// to fetch initially and defaults to 1.
  ///
  /// The [staleDuration] determines how long data is considered fresh. The
  /// [retry] resolver determines retry behavior on failure and defaults to no
  /// retries. The [gcDuration] controls how long unused queries remain in
  /// cache.
  ///
  /// The [seed] provides initial data, with [seedUpdatedAt] specifying when
  /// that seed was last updated. The [meta] map stores arbitrary metadata
  /// accessible in [queryFn].
  ///
  /// Throws if the fetch fails.
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

    final query = Query<InfiniteData<TData, TPageParam>, TError>.cached(
      this,
      queryKey,
      gcDuration: gcDuration ?? defaultQueryOptions.gcDuration,
      seed: seed,
      seedUpdatedAt: seedUpdatedAt,
    );

    if (query.shouldFetch(staleDuration ?? defaultQueryOptions.staleDuration)) {
      return query.fetch(
        wrappedQueryFn,
        gcDuration: gcDuration ?? defaultQueryOptions.gcDuration,
        retry: retry ?? defaultQueryOptions.retry ?? retryNever,
        meta: meta,
      );
    }

    return query.state.data!;
  }

  /// Prefetches an infinite query and populates the cache without returning data.
  ///
  /// Unlike [fetchInfiniteQuery], this method returns `Future<void>` and
  /// silently ignores any errors, making it suitable for preloading paginated
  /// data before navigation.
  ///
  /// See [fetchInfiniteQuery] for parameter descriptions.
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

  /// The cached data for an infinite query, or `null` if not found.
  ///
  /// The [queryKey] must exactly match a query in the cache. Use this for
  /// reading cached paginated data in callbacks or for optimistic updates.
  ///
  /// For reactive updates in widgets, use `useInfiniteQuery` instead.
  InfiniteData<TData, TPageParam>? getInfiniteQueryData<TData, TPageParam>(
    List<Object?> queryKey,
  ) {
    return _cache
        .get<InfiniteData<TData, TPageParam>, dynamic>(queryKey)
        ?.state
        .data;
  }

  /// Removes matching queries from the cache.
  ///
  /// Removed queries are disposed and their resources freed. Unlike
  /// [invalidateQueries], removed queries must be fetched from scratch when
  /// accessed again.
  ///
  /// The [queryKey] filters which queries to remove. When [exact] is false
  /// (default), all queries whose keys start with [queryKey] are included.
  /// When true, only queries with an exactly matching key are removed.
  ///
  /// The [predicate] function provides additional filtering based on query
  /// state. Only queries for which it returns true are removed.
  ///
  /// ```dart
  /// // Remove all queries
  /// client.removeQueries();
  ///
  /// // Remove queries with a specific key prefix
  /// client.removeQueries(queryKey: ['users']);
  ///
  /// // Remove only a specific query
  /// client.removeQueries(queryKey: ['users', '123'], exact: true);
  /// ```
  void removeQueries({
    List<Object?>? queryKey,
    bool exact = false,
    bool Function(List<Object?> queryKey, QueryState state)? predicate,
  }) {
    final queries = _cache.findAll(
      queryKey: queryKey,
      exact: exact,
      predicate: predicate,
    );

    for (final query in queries) {
      _cache.remove(query);
    }
  }

  /// Resets matching queries to their initial state.
  ///
  /// Queries with seed data are reset to that seed; queries without seed have
  /// their data cleared to `null` with pending status.
  ///
  /// Unlike [invalidateQueries], this completely resets query state rather than
  /// just marking it stale.
  ///
  /// The [queryKey] filters which queries to reset. When [exact] is false
  /// (default), all queries whose keys start with [queryKey] are included.
  /// When true, only queries with an exactly matching key are reset.
  ///
  /// The [predicate] function provides additional filtering based on query
  /// state. Only queries for which it returns true are reset.
  ///
  /// Active queries are automatically refetched after resetting.
  ///
  /// ```dart
  /// // Reset all queries
  /// await client.resetQueries();
  ///
  /// // Reset queries with a specific key prefix
  /// await client.resetQueries(queryKey: ['users']);
  /// ```
  Future<void> resetQueries({
    List<Object?>? queryKey,
    bool exact = false,
    bool Function(List<Object?> queryKey, QueryState state)? predicate,
  }) async {
    final queries = _cache.findAll(
      queryKey: queryKey,
      exact: exact,
      predicate: predicate,
    );

    // Reset all matching queries to their initial state
    for (final query in queries) {
      query.reset();
    }

    // Refetch only active, non-static, non-paused queries that have observers
    final queriesToRefetch = queries.where(
      (q) =>
          q.isActive &&
          !q.isStatic &&
          q.state.fetchStatus != FetchStatus.paused,
    );

    await Future.wait(queriesToRefetch.map((q) {
      final observer = q.observers.first;
      return q
          .fetch(
            observer.options.queryFn,
            retry: observer.options.retry,
            meta: observer.options.meta,
          )
          .suppress();
    }));
  }

  /// Cancels in-progress fetches for matching queries.
  ///
  /// Completes when all matching queries have been cancelled. Queries that are
  /// not currently fetching complete immediately.
  ///
  /// The [queryKey] filters which queries to cancel. When [exact] is false
  /// (default), all queries whose keys start with [queryKey] are included.
  /// When true, only queries with an exactly matching key are cancelled.
  ///
  /// The [predicate] function provides additional filtering based on query
  /// state. Only queries for which it returns true are cancelled.
  ///
  /// When [revert] is true (default), cancelled queries restore their state to
  /// what it was before the fetch started. When [silent] is true, cancellation
  /// does not trigger error callbacks or update the query's error state.
  ///
  /// ```dart
  /// // Cancel all queries
  /// await client.cancelQueries();
  ///
  /// // Cancel queries with a specific key prefix
  /// await client.cancelQueries(queryKey: ['users']);
  /// ```
  Future<void> cancelQueries({
    List<Object?>? queryKey,
    bool exact = false,
    bool Function(List<Object?> queryKey, QueryState state)? predicate,
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

  /// Returns the count of queries currently fetching.
  ///
  /// Use this to determine if any queries are in a fetching state, useful for
  /// showing global loading indicators.
  ///
  /// The [queryKey] filters which queries to count. When [exact] is false
  /// (default), all queries whose keys start with [queryKey] are included.
  /// When true, only queries with an exactly matching key are counted.
  ///
  /// The [predicate] function provides additional filtering based on query key
  /// and state. Only queries for which it returns true are counted.
  ///
  /// ```dart
  /// // Count all fetching queries
  /// final count = client.isFetching();
  ///
  /// // Count fetching queries with a specific key prefix
  /// final usersFetching = client.isFetching(queryKey: ['users']);
  /// ```
  int isFetching({
    List<Object?>? queryKey,
    bool exact = false,
    bool Function(List<Object?> queryKey, QueryState state)? predicate,
  }) {
    return _cache
        .findAll(
          queryKey: queryKey,
          exact: exact,
          predicate: (key, state) {
            if (state.fetchStatus != FetchStatus.fetching) return false;
            return predicate == null || predicate(key, state);
          },
        )
        .length;
  }

  /// Returns the count of mutations currently pending.
  ///
  /// Use this to determine if any mutations are in progress, useful for showing
  /// global saving or loading indicators.
  ///
  /// The [mutationKey] filters which mutations to count. When [exact] is false
  /// (default), all mutations whose keys start with [mutationKey] are included.
  /// When true, only mutations with an exactly matching key are counted.
  ///
  /// The [predicate] function provides additional filtering based on mutation
  /// key and state. Only mutations for which it returns true are counted.
  ///
  /// ```dart
  /// // Count all pending mutations
  /// final count = client.isMutating();
  ///
  /// // Count pending mutations with a specific key prefix
  /// final savingUsers = client.isMutating(mutationKey: ['users']);
  /// ```
  int isMutating({
    List<Object?>? mutationKey,
    bool exact = false,
    bool Function(List<Object?>? mutationKey, MutationState state)? predicate,
  }) {
    return _mutationCache
        .findAll(
          mutationKey: mutationKey,
          exact: exact,
          status: MutationStatus.pending,
          predicate: predicate,
        )
        .length;
  }
}
