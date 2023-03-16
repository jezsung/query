import 'dart:collection';

import 'package:equatable/equatable.dart';
import 'package:fluery/src/fluery_error.dart';
import 'package:flutter/foundation.dart';

typedef Mutator<Data, Args> = Future<Data> Function(Args? args);

typedef MutationCallback<Args> = Function(MutationState state, Args? args);

enum MutationStatus {
  idle,
  mutating,
  success,
  failure,
}

class MutationState<Data> extends Equatable {
  const MutationState({
    required this.status,
    this.data,
    this.error,
  });

  final MutationStatus status;
  final Data? data;
  final Object? error;

  MutationState<Data> copyWith({
    MutationStatus? status,
    Data? data,
    Object? error,
  }) {
    return MutationState<Data>(
      status: status ?? this.status,
      data: data ?? this.data,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [
        status,
        data,
        error,
      ];
}

class MutationController<Data, Args>
    extends ValueNotifier<MutationState<Data>> {
  MutationController({
    Mutator<Data, Args>? mutator,
    MutationCallback<Args>? onMutate,
    MutationCallback<Args>? onSuccess,
    MutationCallback<Args>? onFailure,
    MutationCallback<Args>? onSettled,
  })  : _mutator = mutator,
        _onMutate = onMutate,
        _onSuccess = onSuccess,
        _onFailure = onFailure,
        _onSettled = onSettled,
        _mutatorSetByController = mutator != null,
        _onMutateSetByController = onMutate != null,
        _onSuccessSetByController = onSuccess != null,
        _onFailureSetByController = onFailure != null,
        _onSettledSetByController = onSettled != null,
        super(MutationState<Data>(status: MutationStatus.idle));

  Mutator<Data, Args>? _mutator;
  MutationCallback<Args>? _onMutate;
  MutationCallback<Args>? _onSuccess;
  MutationCallback<Args>? _onFailure;
  MutationCallback<Args>? _onSettled;

  bool _mutatorSetByController;
  bool _onMutateSetByController;
  bool _onSuccessSetByController;
  bool _onFailureSetByController;
  bool _onSettledSetByController;

  Mutator<Data, Args>? get mutator => _mutator;
  set mutator(Mutator<Data, Args>? value) {
    _mutator = value;
    _mutatorSetByController = true;
  }

  MutationCallback<Args>? get onMutate => _onMutate;
  set onMutate(MutationCallback<Args>? value) {
    _onMutate = value;
    _onMutateSetByController = true;
  }

  MutationCallback<Args>? get onSuccess => _onSuccess;
  set onSuccess(MutationCallback<Args>? value) {
    _onSuccess = value;
    _onSuccessSetByController = true;
  }

  MutationCallback<Args>? get onFailure => _onFailure;
  set onFailure(MutationCallback<Args>? value) {
    _onFailure = value;
    _onFailureSetByController = true;
  }

  MutationCallback<Args>? get onSettled => _onSettled;
  set onSettled(MutationCallback<Args>? value) {
    _onSettled = value;
    _onSettledSetByController = true;
  }

  final _FunctionQueueExecutor _functionQueueExecutor =
      _FunctionQueueExecutor();

  Future<void> mutate([Args? args]) async {
    if (_mutator == null) {
      throw FlueryError('No mutator function is found');
    }

    Future<void> execute() async {
      Data? data;
      Object? error;

      value = value.copyWith(status: MutationStatus.mutating);

      if (_onMutate != null) {
        _functionQueueExecutor.queue(
          () async => await _onMutate!(value, args),
        );
      }

      try {
        data = await _mutator!(args);
        value = value.copyWith(
          status: MutationStatus.success,
          data: data,
        );

        if (_onSuccess != null) {
          _functionQueueExecutor.queue(
            () async => await _onSuccess!(value, args),
          );
        }
      } catch (e) {
        error = e;
        value = value.copyWith(
          status: MutationStatus.failure,
          error: error,
        );

        if (_onFailure != null) {
          _functionQueueExecutor.queue(
            () async => await _onFailure!(value, args),
          );
        }
      } finally {
        if (_onSettled != null) {
          _functionQueueExecutor.queue(
            () async => await _onSettled!(value, args),
          );
        }
      }
    }

    await execute();
  }

  void reset() {
    value = value.copyWith(
      status: MutationStatus.idle,
      data: null,
      error: null,
    );
  }

  void mergeOptions({
    Mutator<Data, Args>? mutator,
    MutationCallback<Args>? onMutate,
    MutationCallback<Args>? onSuccess,
    MutationCallback<Args>? onFailure,
    MutationCallback<Args>? onSettled,
  }) {
    if (!_mutatorSetByController) {
      _mutator = mutator;
    }
    if (!_onMutateSetByController) {
      _onMutate = onMutate;
    }
    if (!_onSuccessSetByController) {
      _onSuccess = onSuccess;
    }
    if (!_onFailureSetByController) {
      _onFailure = onFailure;
    }
    if (!_onSettledSetByController) {
      _onSettled = onSettled;
    }
  }
}

class _FunctionQueueExecutor {
  final Queue<Function> _queue = Queue<Function>();

  void queue(Function function) {
    _queue.add(function);

    if (_queue.length == 1) {
      execute();
    }
  }

  void execute() async {
    if (_queue.isEmpty) return;

    final Function function = _queue.first;
    await function();
    _queue.removeFirst();

    execute();
  }
}
