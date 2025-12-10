import 'dart:async';

import 'package:clock/clock.dart';
import 'package:equatable/equatable.dart';

enum QueryStatus { pending, error, success }

enum FetchStatus { fetching, paused, idle }

class Query<TData, TError> {
  Query(this.queryKey, this.queryFn);

  final List<Object?> queryKey;
  final Future<TData> Function() queryFn;

  final _controller = StreamController<QueryState<TData, TError>>.broadcast();
  Stream<QueryState<TData, TError>> get onStateChange => _controller.stream;

  QueryState<TData, TError> _state = QueryState<TData, TError>();
  QueryState<TData, TError> get state => _state;

  bool get hasObservers => _controller.hasListener;
  bool get isClosed => _controller.isClosed;

  void _setState(QueryState<TData, TError> newState) {
    _state = newState;
    _controller.add(newState);
  }

  Future<void> fetch() async {
    if (state.fetchStatus == FetchStatus.fetching) return;

    _setState(state.copyWith(
      fetchStatus: FetchStatus.fetching,
    ));

    try {
      final data = await queryFn();

      _setState(QueryState<TData, TError>(
        status: QueryStatus.success,
        fetchStatus: FetchStatus.idle,
        data: data,
        dataUpdatedAt: clock.now(),
        error: null,
        errorUpdatedAt: state.errorUpdatedAt,
        errorUpdateCount: state.errorUpdateCount,
        // failureCount: 0,
        // failureReason: null,
      ));
    } catch (error) {
      _setState(state.copyWith(
        status: QueryStatus.error,
        fetchStatus: FetchStatus.idle,
        error: error as TError,
        errorUpdatedAt: clock.now(),
        errorUpdateCount: state.errorUpdateCount + 1,
        // failureCount: state.failureCount + 1,
        // failureReason: error,
      ));
    }
  }

  void dispose() {
    _controller.close();
  }
}

class QueryState<TData, TError> with EquatableMixin {
  const QueryState({
    this.status = QueryStatus.pending,
    this.fetchStatus = FetchStatus.idle,
    this.data,
    this.dataUpdatedAt,
    this.error,
    this.errorUpdatedAt,
    this.errorUpdateCount = 0,
    // this.failureCount = 0,
    // this.failureReason,
  });

  final QueryStatus status;
  final FetchStatus fetchStatus;
  final TData? data;
  final DateTime? dataUpdatedAt;
  final TError? error;
  final DateTime? errorUpdatedAt;
  final int errorUpdateCount;
  // final int failureCount;
  // final TError? failureReason;

  QueryState<TData, TError> copyWith({
    QueryStatus? status,
    FetchStatus? fetchStatus,
    TData? data,
    DateTime? dataUpdatedAt,
    TError? error,
    DateTime? errorUpdatedAt,
    int? errorUpdateCount,
    // int? failureCount,
    // TError? failureReason,
  }) {
    return QueryState<TData, TError>(
      status: status ?? this.status,
      fetchStatus: fetchStatus ?? this.fetchStatus,
      data: data ?? this.data,
      dataUpdatedAt: dataUpdatedAt ?? this.dataUpdatedAt,
      error: error ?? this.error,
      errorUpdatedAt: errorUpdatedAt ?? this.errorUpdatedAt,
      errorUpdateCount: errorUpdateCount ?? this.errorUpdateCount,
      // failureCount: failureCount ?? this.failureCount,
      // failureReason: failureReason ?? this.failureReason,
    );
  }

  @override
  List<Object?> get props => [
        status,
        fetchStatus,
        data,
        dataUpdatedAt,
        error,
        errorUpdatedAt,
        errorUpdateCount,
        // failureCount,
        // failureReason,
      ];
}
