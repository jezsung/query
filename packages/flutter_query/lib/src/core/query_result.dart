import 'package:collection/collection.dart';

import 'query.dart';

const DeepCollectionEquality _equality = DeepCollectionEquality();

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

  /// Manually refetch the query.
  ///
  /// Returns a [Future] that resolves to the updated [QueryResult].
  ///
  /// Options:
  /// - [cancelRefetch]: If true (default), cancels any in-progress fetch.
  /// - [throwOnError]: If true, rethrows errors instead of capturing in state.
  final Future<QueryResult<TData, TError>> Function({
    bool cancelRefetch, // Defaults to true
    bool throwOnError, // Defaults to false
  }) refetch;

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
        _equality.equals(data, other.data) &&
        dataUpdatedAt == other.dataUpdatedAt &&
        dataUpdateCount == other.dataUpdateCount &&
        _equality.equals(error, other.error) &&
        errorUpdatedAt == other.errorUpdatedAt &&
        errorUpdateCount == other.errorUpdateCount &&
        failureCount == other.failureCount &&
        _equality.equals(failureReason, other.failureReason) &&
        isEnabled == other.isEnabled &&
        isStale == other.isStale &&
        isFetchedAfterMount == other.isFetchedAfterMount &&
        isPlaceholderData == other.isPlaceholderData;
  }

  @override
  int get hashCode => Object.hash(
        status,
        fetchStatus,
        _equality.hash(data),
        dataUpdatedAt,
        dataUpdateCount,
        _equality.hash(error),
        errorUpdatedAt,
        errorUpdateCount,
        failureCount,
        _equality.hash(failureReason),
        isEnabled,
        isStale,
        isFetchedAfterMount,
        isPlaceholderData,
      );
}
