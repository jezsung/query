import 'package:clock/clock.dart';
import 'package:collection/collection.dart';

enum QueryStatus { pending, error, success }

enum FetchStatus { fetching, paused, idle }

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
        _equality.equals(data, other.data) &&
        dataUpdatedAt == other.dataUpdatedAt &&
        dataUpdateCount == other.dataUpdateCount &&
        _equality.equals(error, other.error) &&
        errorUpdatedAt == other.errorUpdatedAt &&
        errorUpdateCount == other.errorUpdateCount &&
        failureCount == other.failureCount &&
        _equality.equals(failureReason, other.failureReason) &&
        isInvalidated == other.isInvalidated;
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
        isInvalidated,
      );
}

extension QueryStateCopyWith<TData, TError> on QueryState<TData, TError> {
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

const DeepCollectionEquality _equality = DeepCollectionEquality();
