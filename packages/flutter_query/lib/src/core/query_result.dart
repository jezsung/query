import 'query_state.dart';
import 'utils.dart';

typedef Refetch<TData, TError> = Future<QueryResult<TData, TError>> Function({
  bool cancelRefetch,
  bool throwOnError,
});

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

  final QueryStatus status;
  final FetchStatus fetchStatus;
  final TData? data;
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
  final Refetch<TData, TError> refetch;

  bool get isError => status == QueryStatus.error;
  bool get isSuccess => status == QueryStatus.success;
  bool get isPending => status == QueryStatus.pending;
  bool get isFetching => fetchStatus == FetchStatus.fetching;
  bool get isPaused => fetchStatus == FetchStatus.paused;
  bool get isFetched => dataUpdateCount > 0 || errorUpdateCount > 0;
  bool get isLoading => isPending && isFetching;
  bool get isLoadingError => isError && data == null;
  bool get isRefetchError => isError && data != null;
  bool get isRefetching => isFetching && !isPending;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QueryResult<TData, TError> &&
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
      );
}

extension QueryResultExt<TData, TError> on QueryResult<TData, TError> {
  QueryResult<TData, TError> copyWithPlaceholder(TData? placeholder) {
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
