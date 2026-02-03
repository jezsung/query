import 'query_observer.dart';
import 'query_state.dart';
import 'utils.dart';

/// Signature for a function that refetches all pages of an infinite query.
///
/// Returns a [Future] that completes with the updated [InfiniteQueryResult].
///
/// If [cancelRefetch] is true, cancels any in-flight refetch before starting
/// a new one. If [throwOnError] is true, the returned future rejects on error
/// instead of returning an error result.
typedef InfiniteRefetch<TData, TError, TPageParam>
    = Future<InfiniteQueryResult<TData, TError, TPageParam>> Function({
  bool cancelRefetch,
  bool throwOnError,
});

/// Signature for a function that fetches the next page of an infinite query.
///
/// Returns a [Future] that completes with the updated [InfiniteQueryResult].
///
/// If [cancelRefetch] is true, cancels any in-flight fetch before starting
/// a new one. If [throwOnError] is true, the returned future rejects on error
/// instead of returning an error result.
typedef FetchNextPage<TData, TError, TPageParam>
    = Future<InfiniteQueryResult<TData, TError, TPageParam>> Function({
  bool cancelRefetch,
  bool throwOnError,
});

/// Signature for a function that fetches the previous page of an infinite query.
///
/// Returns a [Future] that completes with the updated [InfiniteQueryResult].
///
/// If [cancelRefetch] is true, cancels any in-flight fetch before starting
/// a new one. If [throwOnError] is true, the returned future rejects on error
/// instead of returning an error result.
typedef FetchPreviousPage<TData, TError, TPageParam>
    = Future<InfiniteQueryResult<TData, TError, TPageParam>> Function({
  bool cancelRefetch,
  bool throwOnError,
});

/// The result of an infinite query operation.
///
/// Contains the current state of an infinite query including its paginated data,
/// error, and various status flags. This extends the standard query result with
/// pagination-specific functionality like fetching next/previous pages.
///
/// The type parameters are:
/// - [TData]: The type of data returned by each page.
/// - [TError]: The type of error that may occur during fetching.
/// - [TPageParam]: The type of the page parameter used for pagination.
class InfiniteQueryResult<TData, TError, TPageParam> {
  /// Creates an infinite query result.
  const InfiniteQueryResult({
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
    required this.fetchNextPage,
    required this.fetchPreviousPage,
    required this.hasNextPage,
    required this.hasPreviousPage,
    required this.isFetchingNextPage,
    required this.isFetchingPreviousPage,
    required this.isFetchNextPageError,
    required this.isFetchPreviousPageError,
  });

  /// The current status of the query.
  final QueryStatus status;

  /// The current fetch status of the query.
  final FetchStatus fetchStatus;

  /// The paginated data containing all fetched pages and their parameters.
  final InfiniteData<TData, TPageParam>? data;

  /// The timestamp when the data was last updated.
  final DateTime? dataUpdatedAt;

  /// The number of times the data has been updated.
  final int dataUpdateCount;

  /// The error thrown by the last failed fetch, if any.
  final TError? error;

  /// The timestamp when the error was last updated.
  final DateTime? errorUpdatedAt;

  /// The number of times the error has been updated.
  final int errorUpdateCount;

  /// The number of times the current fetch has failed.
  ///
  /// Resets to zero when a new fetch starts or when the fetch succeeds.
  final int failureCount;

  /// The error from the most recent failed fetch attempt.
  ///
  /// Resets to null when a new fetch starts or when the fetch succeeds.
  final TError? failureReason;

  /// Whether this query is enabled and can fetch.
  final bool isEnabled;

  /// Whether this query's data is considered stale.
  final bool isStale;

  /// Whether this query has been fetched after the observer mounted.
  final bool isFetchedAfterMount;

  /// Whether the current data is placeholder data.
  final bool isPlaceholderData;

  /// Refetches all pages of the query.
  final InfiniteRefetch<TData, TError, TPageParam> refetch;

  /// Fetches the next page of data.
  ///
  /// Uses `nextPageParamBuilder` to determine the page parameter for the next
  /// page. Does nothing if [hasNextPage] is false.
  final FetchNextPage<TData, TError, TPageParam> fetchNextPage;

  /// Fetches the previous page of data.
  ///
  /// Uses `prevPageParamBuilder` to determine the page parameter for the
  /// previous page. Does nothing if [hasPreviousPage] is false.
  final FetchPreviousPage<TData, TError, TPageParam> fetchPreviousPage;

  /// Whether there is a next page available.
  ///
  /// Determined by calling `nextPageParamBuilder` on the last page. Returns
  /// true if the result is non-null.
  final bool hasNextPage;

  /// Whether there is a previous page available.
  ///
  /// Determined by calling `prevPageParamBuilder` on the first page. Returns
  /// true if the result is non-null. Always false if `prevPageParamBuilder`
  /// is not provided.
  final bool hasPreviousPage;

  /// Whether this query is currently fetching the next page.
  final bool isFetchingNextPage;

  /// Whether this query is currently fetching the previous page.
  final bool isFetchingPreviousPage;

  /// Whether the last fetch of the next page resulted in an error.
  final bool isFetchNextPageError;

  /// Whether the last fetch of the previous page resulted in an error.
  final bool isFetchPreviousPageError;

  /// Whether the query is in an error state.
  bool get isError => status == QueryStatus.error;

  /// Whether the query completed successfully.
  bool get isSuccess => status == QueryStatus.success;

  /// Whether the query has no data yet.
  bool get isPending => status == QueryStatus.pending;

  /// Whether the query is currently fetching data.
  bool get isFetching => fetchStatus == FetchStatus.fetching;

  /// Whether the query fetch is paused.
  bool get isPaused => fetchStatus == FetchStatus.paused;

  /// Whether the query has fetched at least once.
  bool get isFetched => dataUpdateCount > 0 || errorUpdateCount > 0;

  /// Whether the query is fetching for the first time with no data.
  bool get isLoading => isPending && isFetching;

  /// Whether the query failed on its initial load with no prior data.
  bool get isLoadingError => isError && data == null;

  /// Whether the query failed while refetching with existing data.
  bool get isRefetchError => isError && data != null;

  /// Whether the query is refetching all pages in the background.
  bool get isRefetching =>
      isFetching &&
      !isPending &&
      !isFetchingNextPage &&
      !isFetchingPreviousPage;

  /// The list of all fetched pages.
  List<TData> get pages => data?.pages ?? const [];

  /// The list of page parameters for all fetched pages.
  List<TPageParam> get pageParams => data?.pageParams ?? const [];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InfiniteQueryResult<TData, TError, TPageParam> &&
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

  @override
  String toString() => 'InfiniteQueryResult('
      'status: $status, '
      'fetchStatus: $fetchStatus, '
      'data: $data, '
      'dataUpdatedAt: $dataUpdatedAt, '
      'dataUpdateCount: $dataUpdateCount, '
      'error: $error, '
      'errorUpdatedAt: $errorUpdatedAt, '
      'errorUpdateCount: $errorUpdateCount, '
      'failureCount: $failureCount, '
      'failureReason: $failureReason, '
      'isEnabled: $isEnabled, '
      'isStale: $isStale, '
      'isFetchedAfterMount: $isFetchedAfterMount, '
      'isPlaceholderData: $isPlaceholderData, '
      'hasNextPage: $hasNextPage, '
      'hasPreviousPage: $hasPreviousPage, '
      'isFetchingNextPage: $isFetchingNextPage, '
      'isFetchingPreviousPage: $isFetchingPreviousPage, '
      'isFetchNextPageError: $isFetchNextPageError, '
      'isFetchPreviousPageError: $isFetchPreviousPageError)';
}
