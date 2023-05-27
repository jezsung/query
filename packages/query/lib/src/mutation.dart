import 'package:async/async.dart';
import 'package:clock/clock.dart';
import 'package:equatable/equatable.dart';
import 'package:query/src/utils/observer.dart';

part 'mutation_observer.dart';
part 'mutation_state.dart';

typedef Mutator<T, P> = Future<T> Function(P? param);

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

class Mutation<T, P> with Observable<MutationObserver<T, P>, MutationState<T>> {
  Mutation() : _state = MutationState<T>();

  MutationState<T> _state;

  MutationState<T> get state => _state;

  set state(value) {
    _state = value;
    notify(value);
  }

  CancelableOperation<T>? _cancelableOperation;

  Future mutate({
    required Mutator<T, P> mutator,
    required P? param,
  }) async {
    if (state.status.isMutating) return;

    final stateBeforeMutating = state;

    state = state.copyWith(status: MutationStatus.mutating);

    try {
      _cancelableOperation = CancelableOperation<T>.fromFuture(mutator(param));

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
}
