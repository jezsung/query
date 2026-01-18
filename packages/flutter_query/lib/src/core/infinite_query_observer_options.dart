import 'default_query_options.dart';
import 'infinite_query_function_context.dart';
import 'query_key.dart';
import 'query_observer.dart';
import 'query_options.dart';
import 'utils.dart';

/// Function type for infinite query functions.
///
/// Receives an [InfiniteQueryFunctionContext] containing the page parameter
/// and fetch direction, and returns a [Future] that resolves to the page data.
typedef InfiniteQueryFn<TData, TPageParam> = Future<TData> Function(
  InfiniteQueryFunctionContext<TPageParam> context,
);

/// Function type for extracting the next page parameter from the current data.
///
/// Returns the page parameter to use for fetching the next page, or `null`
/// if there is no next page.
///
/// Access page data via:
/// - `data.pages.last` - the last fetched page
/// - `data.pages` - all fetched pages
/// - `data.pageParams.last` - the last page parameter
/// - `data.pageParams` - all page parameters
typedef NextPageParamBuilder<TData, TPageParam> = TPageParam? Function(
  InfiniteData<TData, TPageParam> data,
);

/// Function type for extracting the previous page parameter from the current data.
///
/// Returns the page parameter to use for fetching the previous page, or `null`
/// if there is no previous page.
///
/// Access page data via:
/// - `data.pages.first` - the first fetched page
/// - `data.pages` - all fetched pages
/// - `data.pageParams.first` - the first page parameter
/// - `data.pageParams` - all page parameters
typedef PrevPageParamBuilder<TData, TPageParam> = TPageParam? Function(
  InfiniteData<TData, TPageParam> data,
);

/// Options for configuring an infinite query.
///
/// Contains all the configuration options for an infinite query including
/// the query key, query function, pagination options, and various behavioral
/// options like staleDuration, retry, etc.
///
/// Matches TanStack Query v5's InfiniteQueryObserverOptions.
class InfiniteQueryObserverOptions<TData, TError, TPageParam> {
  InfiniteQueryObserverOptions(
    List<Object?> queryKey,
    this.queryFn, {
    required this.initialPageParam,
    required this.nextPageParamBuilder,
    this.prevPageParamBuilder,
    this.maxPages,
    this.enabled,
    this.staleDuration,
    this.gcDuration,
    this.placeholder,
    this.refetchOnMount,
    this.refetchOnResume,
    this.refetchInterval,
    this.retry,
    this.retryOnMount,
    this.seed,
    this.seedUpdatedAt,
    this.meta,
  }) : queryKey = QueryKey(queryKey);

  /// The query key that uniquely identifies this query.
  final QueryKey queryKey;

  /// The function that fetches a single page of data.
  ///
  /// Receives an [InfiniteQueryFunctionContext] containing the page parameter
  /// and fetch direction.
  final InfiniteQueryFn<TData, TPageParam> queryFn;

  // ============================================================================
  // Infinite Query Specific Options
  // ============================================================================

  /// The page parameter to use when fetching the first page.
  ///
  /// This is required and will be passed to [queryFn] for the initial fetch.
  final TPageParam initialPageParam;

  /// Function to extract the next page parameter from the last fetched page.
  ///
  /// Return `null` to indicate there is no next page.
  final NextPageParamBuilder<TData, TPageParam> nextPageParamBuilder;

  /// Function to extract the previous page parameter from the first fetched page.
  ///
  /// Return `null` to indicate there is no previous page.
  /// If not provided, backward pagination is not supported.
  final PrevPageParamBuilder<TData, TPageParam>? prevPageParamBuilder;

  /// Maximum number of pages to keep in the cache.
  ///
  /// When fetching a new page would exceed this limit, the oldest page
  /// on the opposite end is removed.
  final int? maxPages;

  // ============================================================================
  // Common Query Options (same order as QueryOptions)
  // ============================================================================

  /// Whether the query is enabled and should automatically fetch.
  final bool? enabled;

  /// Duration after which data is considered stale.
  final StaleDuration? staleDuration;

  /// Duration after which the query data is garbage collected when there are
  /// no observers.
  final GcDuration? gcDuration;

  /// Placeholder data to show while the query is loading.
  final InfiniteData<TData, TPageParam>? placeholder;

  /// Whether to refetch the query when a new observer mounts.
  final RefetchOnMount? refetchOnMount;

  /// Whether to refetch the query when the app resumes from background.
  final RefetchOnResume? refetchOnResume;

  /// Interval at which the query should automatically refetch.
  final Duration? refetchInterval;

  /// Function to determine retry behavior after a failed fetch.
  final RetryResolver<TError>? retry;

  /// Whether to retry failed queries when a new observer mounts.
  final bool? retryOnMount;

  /// Initial data to populate the cache with before any fetch.
  final InfiniteData<TData, TPageParam>? seed;

  /// Timestamp when the seed data was last updated.
  final DateTime? seedUpdatedAt;

  /// Additional metadata stored on the query options.
  final Map<String, dynamic>? meta;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InfiniteQueryObserverOptions<TData, TError, TPageParam> &&
        queryKey == other.queryKey &&
        identical(queryFn, other.queryFn) &&
        deepEq.equals(initialPageParam, other.initialPageParam) &&
        identical(nextPageParamBuilder, other.nextPageParamBuilder) &&
        identical(prevPageParamBuilder, other.prevPageParamBuilder) &&
        maxPages == other.maxPages &&
        enabled == other.enabled &&
        staleDuration == other.staleDuration &&
        gcDuration == other.gcDuration &&
        deepEq.equals(placeholder, other.placeholder) &&
        refetchOnMount == other.refetchOnMount &&
        refetchOnResume == other.refetchOnResume &&
        refetchInterval == other.refetchInterval &&
        identical(retry, other.retry) &&
        retryOnMount == other.retryOnMount &&
        deepEq.equals(seed, other.seed) &&
        seedUpdatedAt == other.seedUpdatedAt &&
        deepEq.equals(meta, other.meta);
  }

  @override
  int get hashCode => Object.hash(
        queryKey,
        identityHashCode(queryFn),
        deepEq.hash(initialPageParam),
        identityHashCode(nextPageParamBuilder),
        identityHashCode(prevPageParamBuilder),
        maxPages,
        enabled,
        staleDuration,
        gcDuration,
        deepEq.hash(placeholder),
        refetchOnMount,
        refetchOnResume,
        refetchInterval,
        identityHashCode(retry),
        retryOnMount,
        deepEq.hash(seed),
        seedUpdatedAt,
        deepEq.hash(meta),
      );
}

/// Extension methods for [InfiniteQueryObserverOptions].
extension InfiniteQueryObserverOptionsWithDefaults<TData, TError, TPageParam>
    on InfiniteQueryObserverOptions<TData, TError, TPageParam> {
  /// Merges this InfiniteQueryObserverOptions with default options.
  ///
  /// Query-specific options take precedence over defaults.
  InfiniteQueryObserverOptions<TData, TError, TPageParam> withDefaults(
    DefaultQueryOptions defaults,
  ) {
    return InfiniteQueryObserverOptions<TData, TError, TPageParam>(
      queryKey.parts,
      queryFn,
      initialPageParam: initialPageParam,
      nextPageParamBuilder: nextPageParamBuilder,
      prevPageParamBuilder: prevPageParamBuilder,
      maxPages: maxPages,
      enabled: enabled ?? defaults.enabled,
      staleDuration: staleDuration ?? defaults.staleDuration,
      gcDuration: gcDuration ?? defaults.gcDuration,
      placeholder: placeholder,
      refetchOnMount: refetchOnMount ?? defaults.refetchOnMount,
      refetchOnResume: refetchOnResume ?? defaults.refetchOnResume,
      refetchInterval: refetchInterval ?? defaults.refetchInterval,
      retry: retry ?? defaults.retry as RetryResolver<TError>?,
      retryOnMount: retryOnMount ?? defaults.retryOnMount,
      seed: seed,
      seedUpdatedAt: seedUpdatedAt,
      meta: meta,
    );
  }
}

extension InfiniteQueryObserverOptionsBuildNextPageParam<TData, TError,
    TPageParam> on InfiniteQueryObserverOptions<TData, TError, TPageParam> {
  TPageParam? buildNextPageParam(InfiniteData<TData, TPageParam> data) {
    if (data.pages.isEmpty || data.pageParams.isEmpty) return null;

    return nextPageParamBuilder(data);
  }

  TPageParam? buildPrevPageParam(InfiniteData<TData, TPageParam> data) {
    if (data.pages.isEmpty || data.pageParams.isEmpty) return null;

    return prevPageParamBuilder?.call(data);
  }
}
