import 'query_state.dart';
import 'utils.dart';

/// Signature for a function that refetches the query data.
///
/// Returns a [Future] that completes with the updated [QueryResult].
///
/// If [cancelRefetch] is true, cancels any in-flight refetch before starting
/// a new one. If [throwOnError] is true, the returned future rejects on error
/// instead of returning an error result.
typedef Refetch<TData, TError> = Future<QueryResult<TData, TError>> Function({
  bool cancelRefetch,
  bool throwOnError,
});

/// The result of a query operation.
///
/// Contains the current state of a query including its data, error, and various
/// status flags. This is the primary type returned by query observers and
/// provides both the fetched data and metadata about the query's lifecycle.
///
/// The type parameters are:
/// - [TData]: The type of data returned by the query.
/// - [TError]: The type of error that may occur during fetching.
class QueryResult<TData, TError> {
  const QueryResult({
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
  });

  /// The current status of the query.
  final QueryStatus status;

  /// The current fetch status of the query.
  final FetchStatus fetchStatus;

  /// The last successfully resolved data for this query.
  final TData? data;

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

  /// Refetches the query data.
  final Refetch<TData, TError> refetch;

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

  /// Whether the query is refetching in the background with existing data.
  bool get isRefetching => isFetching && !isPending;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueryResult<TData, TError> &&
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
          isPlaceholderData == other.isPlaceholderData;

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
      );

  @override
  String toString() => 'QueryResult('
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
      'isPlaceholderData: $isPlaceholderData)';
}

/// Extension methods for [QueryResult].
extension QueryResultExt<TData, TError> on QueryResult<TData, TError> {
  /// Returns a copy of this result with the given [placeholder] data.
  ///
  /// If [placeholder] is null, or if this result already has data or is not
  /// in a pending state, returns this result unchanged.
  QueryResult<TData, TError> withPlaceholder(TData? placeholder) {
    if (placeholder == null) {
      return this;
    }
    if (data != null || status != QueryStatus.pending) {
      return this;
    }

    return QueryResult<TData, TError>(
      status: QueryStatus.success,
      fetchStatus: fetchStatus,
      data: placeholder,
      dataUpdatedAt: dataUpdatedAt,
      dataUpdateCount: dataUpdateCount,
      error: error,
      errorUpdatedAt: errorUpdatedAt,
      errorUpdateCount: errorUpdateCount,
      failureCount: failureCount,
      failureReason: failureReason,
      isEnabled: isEnabled,
      isStale: isStale,
      isFetchedAfterMount: isFetchedAfterMount,
      isPlaceholderData: true,
      refetch: refetch,
    );
  }
}
