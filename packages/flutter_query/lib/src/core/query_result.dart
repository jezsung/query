import 'package:equatable/equatable.dart';

import 'query.dart';

class QueryResult<TData, TError> with EquatableMixin {
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
  List<Object?> get props => [
        status,
        fetchStatus,
        data,
        dataUpdatedAt,
        dataUpdateCount,
        error,
        errorUpdatedAt,
        errorUpdateCount,
        failureCount,
        failureReason,
        isEnabled,
        isStale,
        isFetchedAfterMount,
        isPlaceholderData,
      ];
}
