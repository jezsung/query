import 'dart:async';

import 'package:async/async.dart';
import 'package:clock/clock.dart';
import 'package:equatable/equatable.dart';
import 'package:fluery/src/conditional_value_listenable_builder.dart';
import 'package:fluery/src/conditional_value_listenable_listener.dart';
import 'package:fluery/src/timer_interceptor.dart';
import 'package:flutter/widgets.dart';
import 'package:retry/retry.dart';

part 'mutation_builder.dart';
part 'mutation_consumer.dart';
part 'mutation_controller.dart';
part 'mutation_listener.dart';
part 'mutation_state.dart';

typedef Mutator<T, P> = Future<T> Function(P? param);

enum MutationStatus {
  idle,
  mutating,
  retrying,
  success,
  failure,
}

extension MutationStatusExtension on MutationStatus {
  bool get isIdle => this == MutationStatus.idle;

  bool get isMutating => this == MutationStatus.mutating;

  bool get isRetrying => this == MutationStatus.retrying;

  bool get isSuccess => this == MutationStatus.success;

  bool get isFailure => this == MutationStatus.failure;
}

typedef RetryCondition = FutureOr<bool> Function(Exception e);

typedef MutationListenerCondition<T> = bool Function(
  MutationState<T> previousState,
  MutationState<T> currentState,
);

typedef MutationBuilderCondition<T> = bool Function(
  MutationState<T> previousState,
  MutationState<T> currentState,
);

typedef MutationWidgetListener<T> = void Function(
  BuildContext context,
  MutationState<T> state,
);

typedef MutationWidgetBuilder<Data> = Widget Function(
  BuildContext context,
  MutationState<Data> state,
  Widget? child,
);

mixin _MutationWidgetState<T, A> {
  Mutator<T, A> get mutator;
  RetryCondition? get retryWhen;
  int get retryMaxAttempts;
  Duration get retryMaxDelay;
  Duration get retryDelayFactor;
  double get retryRandomizationFactor;
}
