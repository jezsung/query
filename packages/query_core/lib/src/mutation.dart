import 'dart:async';

import 'package:async/async.dart';
import 'package:clock/clock.dart';
import 'package:equatable/equatable.dart';

part 'mutation_state.dart';

typedef Mutator<T, A> = Future<T> Function(A? arg);

enum MutationStatus {
  idle,
  mutating,
  success,
  failure,
}

extension MutationStatusExtension on MutationStatus {
  bool get isIdle => this == MutationStatus.idle;

  bool get isMutating => this == MutationStatus.mutating;

  bool get isSuccess => this == MutationStatus.success;

  bool get isFailure => this == MutationStatus.failure;
}

class Mutation<T, A> {
  Mutation() : _state = MutationState<T>();

  final _stateController = StreamController<MutationState<T>>.broadcast();
  Stream<MutationState<T>> get stream => _stateController.stream;

  MutationState<T> _state;
  MutationState<T> get state => _state;
  set state(MutationState<T> value) {
    _state = value;
    _stateController.add(value);
  }

  CancelableOperation<T>? _cancelableOperation;

  Future mutate({
    required Mutator<T, A> mutator,
    required A? arg,
  }) async {
    if (state.status.isMutating) return;

    final stateBeforeMutating = state;

    state = state.copyWith(status: MutationStatus.mutating);

    try {
      _cancelableOperation = CancelableOperation<T>.fromFuture(mutator(arg));

      final data = await _cancelableOperation!.valueOrCancellation();

      if (_cancelableOperation!.isCanceled) {
        state = stateBeforeMutating;
        return;
      }

      state = state.copyWith(
        status: MutationStatus.success,
        data: data,
        dataUpdatedAt: clock.now(),
      );
    } on Exception catch (error) {
      state = state.copyWith(
        status: MutationStatus.failure,
        error: error,
        errorUpdatedAt: clock.now(),
      );
    }
  }

  Future cancel() async {
    if (!state.status.isMutating) return;

    await _cancelableOperation?.cancel();
  }

  void reset() {
    if (state.status.isMutating) return;

    state = state
        .copyWith(
          status: MutationStatus.idle,
        )
        .copyWithNull(
          data: true,
          error: true,
          dataUpdatedAt: true,
          errorUpdatedAt: true,
        );
  }

  Future close() async {
    _cancelableOperation?.cancel();
  }
}
