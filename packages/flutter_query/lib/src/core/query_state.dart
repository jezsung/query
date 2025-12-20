import 'package:clock/clock.dart';
import 'package:equatable/equatable.dart';

import 'query.dart';
import 'query_options.dart';

class QueryState<TData, TError> with EquatableMixin {
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

  /// Creates a QueryState from QueryOptions, handling initialData.
  ///
  /// This matches TanStack Query's getDefaultState function behavior.
  factory QueryState.fromOptions(QueryOptions<TData, TError> options) {
    if (options.initialData != null) {
      return QueryState<TData, TError>(
        status: QueryStatus.success,
        fetchStatus: FetchStatus.idle,
        data: options.initialData,
        dataUpdatedAt: options.initialDataUpdatedAt ?? clock.now(),
        error: null,
        errorUpdatedAt: null,
        errorUpdateCount: 0,
        failureCount: 0,
        failureReason: null,
      );
    }

    return QueryState<TData, TError>();
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
    bool faliureReason = false,
  }) {
    return QueryState<TData, TError>(
      status: this.status,
      fetchStatus: this.fetchStatus,
      data: this.data,
      dataUpdatedAt: this.dataUpdatedAt,
      dataUpdateCount: this.dataUpdateCount,
      error: this.error,
      errorUpdatedAt: this.errorUpdatedAt,
      errorUpdateCount: this.errorUpdateCount,
      failureCount: this.failureCount,
      failureReason: faliureReason ? null : this.failureReason,
      isInvalidated: this.isInvalidated,
    );
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
        isInvalidated,
      ];
}
