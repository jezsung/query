import 'dart:async';

import 'package:clock/clock.dart';
import 'package:equatable/equatable.dart';

import 'query_cache.dart';
import 'query_observer.dart';
import 'removable.dart';

enum QueryStatus { pending, error, success }

enum FetchStatus { fetching, paused, idle }

class Query<TData, TError> with Removable {
  Query(this.queryKey, this.queryFn, QueryCache cache) : _cache = cache;

  final List<Object?> queryKey;
  final Future<TData> Function() queryFn;
  final QueryCache _cache;

  final _controller = StreamController<QueryState<TData, TError>>.broadcast();
  Stream<QueryState<TData, TError>> get onStateChange => _controller.stream;

  QueryState<TData, TError> _state = QueryState<TData, TError>();
  QueryState<TData, TError> get state => _state;

  // Track observers explicitly to match TanStack Query's pattern
  final List<QueryObserver> _observers = [];

  bool get hasObservers => _observers.isNotEmpty;
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

  /// Adds an observer to this query.
  ///
  /// Matches TanStack Query's pattern: clear GC timeout when an observer subscribes.
  void addObserver(QueryObserver observer) {
    if (!_observers.contains(observer)) {
      _observers.add(observer);

      // Stop the query from being garbage collected
      cancelGc();
    }
  }

  /// Removes an observer from this query.
  ///
  /// Matches TanStack Query's pattern: schedule GC only when the last observer is removed.
  void removeObserver(QueryObserver observer) {
    if (_observers.contains(observer)) {
      _observers.remove(observer);

      // Schedule GC only if there are no more observers
      if (_observers.isEmpty) {
        scheduleGc();
      }
    }
  }

  /// Attempts to remove the query if it has no observers and is idle.
  ///
  /// This is called by the Removable mixin when the GC timer expires.
  /// Matches TanStack Query's behavior: remove when no observers and fetchStatus is idle.
  @override
  void tryRemove() {
    if (!hasObservers && state.fetchStatus == FetchStatus.idle) {
      _cache.remove(this);
    }
  }

  void dispose() {
    cancelGc();
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
