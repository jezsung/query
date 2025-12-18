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
  }) async {
    final queryOptions = QueryOptions<TData, TError>(
      queryKey,
      queryFn,
      staleDuration: staleDuration,
      retry: retry ?? Retry<TError>.never(), // Default to no retry
      retryDelay: retryDelay,
      gcDuration: gcDuration,
    );

    final query = _cache.build<TData, TError>(queryOptions);

    // Check if data is stale
    if (query.isStaleByTime(staleDuration)) {
      return query.fetch();
    }

    // Data is fresh, return cached data
    return query.state.data as TData;
  }
}
