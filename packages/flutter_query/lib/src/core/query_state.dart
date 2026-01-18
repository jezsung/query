import 'package:clock/clock.dart';

import 'utils.dart';

/// The status of a query's data.
///
/// This represents whether the query has successfully fetched data,
/// encountered an error, or is still waiting for its first fetch.
enum QueryStatus {
  /// The query has no data yet.
  ///
  /// This is the initial status before any fetch completes.
  pending,

  /// The query encountered an error.
  error,

  /// The query has successfully fetched data.
  success,
}

/// The status of the query's fetch operation.
///
/// This represents the current network activity state, independent of
/// whether the query has data or not.
enum FetchStatus {
  /// A fetch is currently in progress.
  fetching,

  /// The fetch is paused, typically due to network unavailability.
  paused,

  /// No fetch is in progress.
  idle,
}

class QueryState<TData, TError> {
  const QueryState({
    this.status = QueryStatus.pending,
    this.fetchStatus = FetchStatus.idle,
    this.data,
    this.dataUpdatedAt,
    this.dataUpdateCount = 0,
    this.error,
    this.errorUpdatedAt,
    this.errorUpdateCount = 0,
    this.failureCount = 0,
    this.failureReason,
    this.isInvalidated = false,
  });

  factory QueryState.fromSeed(TData seed, DateTime? seedUpdatedAt) {
    return QueryState<TData, TError>(
      status: QueryStatus.success,
      fetchStatus: FetchStatus.idle,
      data: seed,
      dataUpdatedAt: seedUpdatedAt ?? clock.now(),
      error: null,
      errorUpdatedAt: null,
      errorUpdateCount: 0,
      failureCount: 0,
      failureReason: null,
    );
  }

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
  final bool isInvalidated;

  bool get hasFetched => dataUpdateCount > 0 || errorUpdateCount > 0;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QueryState<TData, TError> &&
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
        isInvalidated == other.isInvalidated;
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
        isInvalidated,
      );

  @override
  String toString() => 'QueryState('
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
      'isInvalidated: $isInvalidated)';
}

extension QueryStateExt<TData, TError> on QueryState<TData, TError> {
  QueryState<TData, TError> copyWith({
    QueryStatus? status,
    FetchStatus? fetchStatus,
    TData? data,
    DateTime? dataUpdatedAt,
    int? dataUpdateCount,
    TError? error,
    DateTime? errorUpdatedAt,
    int? errorUpdateCount,
    int? failureCount,
    TError? failureReason,
    bool? isInvalidated,
  }) {
    return QueryState<TData, TError>(
      status: status ?? this.status,
      fetchStatus: fetchStatus ?? this.fetchStatus,
      data: data ?? this.data,
      dataUpdatedAt: dataUpdatedAt ?? this.dataUpdatedAt,
      dataUpdateCount: dataUpdateCount ?? this.dataUpdateCount,
      error: error ?? this.error,
      errorUpdatedAt: errorUpdatedAt ?? this.errorUpdatedAt,
      errorUpdateCount: errorUpdateCount ?? this.errorUpdateCount,
      failureCount: failureCount ?? this.failureCount,
      failureReason: failureReason ?? this.failureReason,
      isInvalidated: isInvalidated ?? this.isInvalidated,
    );
  }

  QueryState<TData, TError> copyWithNull({
    bool data = false,
    bool dataUpdatedAt = false,
    bool error = false,
    bool errorUpdatedAt = false,
    bool failureReason = false,
  }) {
    return QueryState<TData, TError>(
      status: status,
      fetchStatus: fetchStatus,
      data: data ? null : this.data,
      dataUpdatedAt: dataUpdatedAt ? null : this.dataUpdatedAt,
      dataUpdateCount: dataUpdateCount,
      error: error ? null : this.error,
      errorUpdatedAt: errorUpdatedAt ? null : this.errorUpdatedAt,
      errorUpdateCount: errorUpdateCount,
      failureCount: failureCount,
      failureReason: failureReason ? null : this.failureReason,
      isInvalidated: isInvalidated,
    );
  }
}
