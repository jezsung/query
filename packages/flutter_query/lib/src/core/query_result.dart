import 'package:clock/clock.dart';
import 'package:equatable/equatable.dart';

import 'options/stale_duration.dart';
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
    required StaleDuration staleDuration,
    required this.isFetchedAfterMount,
    required this.isPlaceholderData,
    required this.refetch,
  }) : _staleDuration = staleDuration;

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
  final bool isFetchedAfterMount;
  final bool isPlaceholderData;
  final StaleDuration _staleDuration;

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
  bool get isStale {
    // Data is stale if there's no dataUpdatedAt
    if (dataUpdatedAt == null) return true;

    final age = clock.now().difference(dataUpdatedAt!);

    return switch (_staleDuration) {
      // Check if age exceeds or equals staleDuration (>= for zero staleDuration)
      StaleDurationDuration duration => age >= duration,
      // If staleDuration is StaleDurationInfinity, never stale (unless invalidated)
      StaleDurationInfinity() => false,
      // If staleDuration is StaleDurationStatic, never stale
      StaleDurationStatic() => false,
    };
  }

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
        isFetchedAfterMount,
        isPlaceholderData,
        _staleDuration,
      ];
}
