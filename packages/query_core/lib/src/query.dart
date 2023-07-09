import 'dart:async';

import 'package:async/async.dart';
import 'package:clock/clock.dart';
import 'package:equatable/equatable.dart';

part 'paged_query.dart';
part 'paged_query_state.dart';
part 'query_state.dart';

enum QueryStatus {
  idle,
  fetching,
  success,
  failure,
}

extension QueryStatusExtension on QueryStatus {
  bool get isIdle => this == QueryStatus.idle;

  bool get isFetching => this == QueryStatus.fetching;

  bool get isSuccess => this == QueryStatus.success;

  bool get isFailure => this == QueryStatus.failure;
}

typedef QueryKey = String;

typedef QueryFetcher<Data> = Future<Data> Function(QueryKey key);

class Query<T> {
  Query(this.key) : _state = QueryState<T>();

  final QueryKey key;

  final _stateController = StreamController<QueryState<T>>.broadcast();
  Stream<QueryState<T>> get stream => _stateController.stream;

  QueryState<T> _state;
  QueryState<T> get state => _state;
  set state(QueryState<T> value) {
    _state = value;
    _stateController.add(value);
  }

  CancelableOperation<T>? _cancelableOperation;

  Future fetch({
    required QueryFetcher<T> fetcher,
    Duration staleDuration = Duration.zero,
  }) async {
    if (state.status.isFetching) return;

    if (!isStale(staleDuration) && !state.isInvalidated) return;

    _stateBeforeFetching = state.copyWith();

    state = state.copyWith(
      status: QueryStatus.fetching,
      isInvalidated: false,
    );

    try {
      _cancelableOperation = CancelableOperation<T>.fromFuture(fetcher(key));

      final data = await _cancelableOperation!.valueOrCancellation();

      if (!_cancelableOperation!.isCanceled) {
        state = state.copyWith(
          status: QueryStatus.success,
          data: data,
          dataUpdatedAt: clock.now(),
        );
      }
    } on Exception catch (error) {
      state = state.copyWith(
        status: QueryStatus.failure,
        error: error,
        errorUpdatedAt: clock.now(),
      );
    }
  }

  QueryState<T>? _stateBeforeFetching;

  Future cancel() async {
    if (!state.status.isFetching) return;
    state = _stateBeforeFetching!;

    _stateBeforeFetching = null;

    await _cancelableOperation?.cancel();
  }

  void setInitialData(
    T data, [
    DateTime? updatedAt,
  ]) {
    if (state.hasData) {
      return;
    }

    state = state.copyWith(
      status: QueryStatus.success,
      data: data,
      dataUpdatedAt: updatedAt ?? clock.now(),
    );
  }

  void setData(
    T data, [
    DateTime? updatedAt,
  ]) {
    if (updatedAt != null &&
        state.dataUpdatedAt != null &&
        !updatedAt.isAfter(state.dataUpdatedAt!)) {
      return;
    }

    state = state.copyWith(
      status: QueryStatus.success,
      data: data,
      dataUpdatedAt: updatedAt ?? clock.now(),
    );
  }

  void invalidate() {
    state = state.copyWith(isInvalidated: true);
  }

  bool isStale(Duration duration) {
    if (!state.hasData || state.dataUpdatedAt == null) return true;

    final now = clock.now();
    final staleAt = state.dataUpdatedAt!.add(duration);

    return now.isAfter(staleAt) || now.isAtSameMomentAs(staleAt);
  }

  Future close() async {
    await _cancelableOperation?.cancel();
    await _stateController.close();
  }
}
