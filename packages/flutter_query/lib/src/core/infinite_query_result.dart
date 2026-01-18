import 'query_observer.dart';
import 'query_state.dart';
import 'utils.dart';

/// Typedef for the refetch function on infinite query results.
typedef InfiniteRefetch<TData, TError, TPageParam>
    = Future<InfiniteQueryResult<TData, TError, TPageParam>> Function({
  bool cancelRefetch,
  bool throwOnError,
});

/// Typedef for the fetchNextPage function on infinite query results.
typedef FetchNextPage<TData, TError, TPageParam>
    = Future<InfiniteQueryResult<TData, TError, TPageParam>> Function({
  bool cancelRefetch,
  bool throwOnError,
});

/// Typedef for the fetchPreviousPage function on infinite query results.
typedef FetchPreviousPage<TData, TError, TPageParam>
    = Future<InfiniteQueryResult<TData, TError, TPageParam>> Function({
  bool cancelRefetch,
  bool throwOnError,
});

/// Result of an infinite query, extending [QueryResult] with pagination state.
///
/// Contains all standard query result fields plus:
/// - [fetchNextPage] / [fetchPreviousPage] - Methods to fetch more pages
/// - [hasNextPage] / [hasPreviousPage] - Whether more pages are available
/// - [isFetchingNextPage] / [isFetchingPreviousPage] - Loading state for pagination
/// - [isFetchNextPageError] / [isFetchPreviousPageError] - Error state for pagination
///
/// Matches TanStack Query v5's InfiniteQueryObserverResult.
class InfiniteQueryResult<TData, TError, TPageParam> {
  const InfiniteQueryResult({
    // Standard query result fields
    required this.status,
    required this.fetchStatus,
    required this.data,
    required this.dataUpdatedAt,
    required this.dataUpdateCount,
    required this.error,
    required this.errorUpdatedAt,
    required this.errorUpdateCount,
    required this.failureCount,
    required this.failureReason,
    required this.isEnabled,
    required this.isStale,
    required this.isFetchedAfterMount,
    required this.isPlaceholderData,
    required this.refetch,
    // Infinite query specific fields
    required this.fetchNextPage,
    required this.fetchPreviousPage,
    required this.hasNextPage,
    required this.hasPreviousPage,
    required this.isFetchingNextPage,
    required this.isFetchingPreviousPage,
    required this.isFetchNextPageError,
    required this.isFetchPreviousPageError,
  });

  // ============================================================================
  // Standard Query Result Fields
  // ============================================================================

  final QueryStatus status;
  final FetchStatus fetchStatus;
  final InfiniteData<TData, TPageParam>? data;
  final DateTime? dataUpdatedAt;
  final int dataUpdateCount;
  final TError? error;
  final DateTime? errorUpdatedAt;
  final int errorUpdateCount;
  final int failureCount;
  final TError? failureReason;
  final bool isEnabled;
  final bool isStale;
  final bool isFetchedAfterMount;
  final bool isPlaceholderData;

  /// Manually refetch all pages.
  ///
  /// Returns a [Future] that resolves to the updated [InfiniteQueryResult].
  ///
  /// Options:
  /// - [cancelRefetch]: If true (default), cancels any in-progress fetch.
  /// - [throwOnError]: If true, rethrows errors instead of capturing in state.
  final InfiniteRefetch<TData, TError, TPageParam> refetch;

  // ============================================================================
  // Infinite Query Specific Fields
  // ============================================================================

  /// Fetch the next page of data.
  ///
  /// Uses [getNextPageParam] to determine the page parameter for the next page.
  /// No-op if [hasNextPage] is false.
  ///
  /// Options:
  /// - [cancelRefetch]: If true (default), cancels any in-progress fetch.
  /// - [throwOnError]: If true, rethrows errors instead of capturing in state.
  final FetchNextPage<TData, TError, TPageParam> fetchNextPage;

  /// Fetch the previous page of data.
  ///
  /// Uses [getPreviousPageParam] to determine the page parameter for the previous page.
  /// No-op if [hasPreviousPage] is false.
  ///
  /// Options:
  /// - [cancelRefetch]: If true (default), cancels any in-progress fetch.
  /// - [throwOnError]: If true, rethrows errors instead of capturing in state.
  final FetchPreviousPage<TData, TError, TPageParam> fetchPreviousPage;

  /// Whether there is a next page available.
  ///
  /// Determined by calling [getNextPageParam] on the last page - returns true
  /// if the result is non-null.
  final bool hasNextPage;

  /// Whether there is a previous page available.
  ///
  /// Determined by calling [getPreviousPageParam] on the first page - returns true
  /// if the result is non-null. Always false if [getPreviousPageParam] is not provided.
  final bool hasPreviousPage;

  /// Whether we are currently fetching the next page.
  final bool isFetchingNextPage;

  /// Whether we are currently fetching the previous page.
  final bool isFetchingPreviousPage;

  /// Whether the last fetch of the next page resulted in an error.
  final bool isFetchNextPageError;

  /// Whether the last fetch of the previous page resulted in an error.
  final bool isFetchPreviousPageError;

  // ============================================================================
  // Computed Getters (same as QueryResult)
  // ============================================================================

  bool get isError => status == QueryStatus.error;
  bool get isSuccess => status == QueryStatus.success;
  bool get isPending => status == QueryStatus.pending;
  bool get isFetching => fetchStatus == FetchStatus.fetching;
  bool get isPaused => fetchStatus == FetchStatus.paused;
  bool get isFetched => dataUpdateCount > 0 || errorUpdateCount > 0;
  bool get isLoading => isPending && isFetching;
  bool get isLoadingError => isError && data == null;
  bool get isRefetchError => isError && data != null;

  /// Whether we are refetching (but not fetching next/previous page).
  bool get isRefetching =>
      isFetching &&
      !isPending &&
      !isFetchingNextPage &&
      !isFetchingPreviousPage;

  /// All fetched pages. Returns an empty list if no data.
  List<TData> get pages => data?.pages ?? const [];

  /// All page parameters. Returns an empty list if no data.
  List<TPageParam> get pageParams => data?.pageParams ?? const [];

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InfiniteQueryResult<TData, TError, TPageParam> &&
        status == other.status &&
        fetchStatus == other.fetchStatus &&
        deepEq.equals(data, other.data) &&
        dataUpdatedAt == other.dataUpdatedAt &&
        dataUpdateCount == other.dataUpdateCount &&
        deepEq.equals(error, other.error) &&
        errorUpdatedAt == other.errorUpdatedAt &&
        errorUpdateCount == other.errorUpdateCount &&
        failureCount == other.failureCount &&
        deepEq.equals(failureReason, other.failureReason) &&
        isEnabled == other.isEnabled &&
        isStale == other.isStale &&
        isFetchedAfterMount == other.isFetchedAfterMount &&
        isPlaceholderData == other.isPlaceholderData &&
        hasNextPage == other.hasNextPage &&
        hasPreviousPage == other.hasPreviousPage &&
        isFetchingNextPage == other.isFetchingNextPage &&
        isFetchingPreviousPage == other.isFetchingPreviousPage &&
        isFetchNextPageError == other.isFetchNextPageError &&
        isFetchPreviousPageError == other.isFetchPreviousPageError;
  }

  @override
  int get hashCode => Object.hash(
        status,
        fetchStatus,
        deepEq.hash(data),
        dataUpdatedAt,
        dataUpdateCount,
        deepEq.hash(error),
        errorUpdatedAt,
        errorUpdateCount,
        failureCount,
        deepEq.hash(failureReason),
        isEnabled,
        isStale,
        isFetchedAfterMount,
        isPlaceholderData,
        hasNextPage,
        hasPreviousPage,
        isFetchingNextPage,
        isFetchingPreviousPage,
        isFetchNextPageError,
        isFetchPreviousPageError,
      );
}
