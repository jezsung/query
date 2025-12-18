import 'options/gc_duration.dart';
import 'options/retry.dart';
import 'options/retry_delay.dart';
import 'options/stale_duration.dart';
import 'query_cache.dart';
import 'query_context.dart';
import 'query_observer.dart';

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
}
