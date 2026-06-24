import 'package:meta/meta.dart';

import '../core/core.dart';

/// A Dart-idiomatic, exhaustively matchable snapshot of a mutation's state.
///
/// Unlike [MutationResult], this is a `sealed` hierarchy: a `switch` over it is
/// checked for exhaustiveness, `data` is non-nullable on [MutationSuccess],
/// `error` is non-nullable on [MutationError], and `variables` is non-nullable
/// on every variant except [MutationIdle].
///
/// The four variants mirror [MutationStatus]: [MutationIdle] (never invoked),
/// [MutationPending], [MutationSuccess], and [MutationError]. The
/// `TOnMutateResult` type parameter carried by [MutationResult] is internal and
/// never surfaced, so it is dropped here.
///
/// This is an experimental API and may change in a future minor release.
sealed class MutationSnapshot<TData, TError, TVariables> {
  /// Creates a mutation snapshot.
  const MutationSnapshot({
    required this.submittedAt,
    required this.failureCount,
    required this.failureReason,
    required this.isPaused,
    required this.mutate,
    required this.mutateAsync,
    required this.reset,
  });

  /// The timestamp when the mutation was submitted.
  final DateTime? submittedAt;

  /// The number of times the current mutation has failed.
  final int failureCount;

  /// The error from the most recent failed mutation attempt.
  final TError? failureReason;

  /// Whether the mutation is paused (typically offline).
  final bool isPaused;

  /// A fire-and-forget function that executes the mutation.
  final Mutate<TVariables> mutate;

  /// A function that executes the mutation and returns a [Future].
  final MutateAsync<TData, TVariables> mutateAsync;

  /// Resets the mutation to its initial idle state.
  final Reset reset;

  /// Whether the mutation has not been invoked yet.
  bool get isIdle => this is MutationIdle<TData, TError, TVariables>;

  /// Whether the mutation is currently executing.
  bool get isPending => this is MutationPending<TData, TError, TVariables>;

  /// Whether the mutation completed successfully.
  bool get isSuccess => this is MutationSuccess<TData, TError, TVariables>;

  /// Whether the mutation is in an error state.
  bool get isError => this is MutationError<TData, TError, TVariables>;

  /// The resolved data, if the mutation succeeded.
  TData? get dataOrNull;

  /// The variables of the most recent mutation, if one has been invoked.
  TVariables? get variablesOrNull;
}

/// The mutation has not been invoked yet.
///
/// This is an experimental API and may change in a future minor release.
final class MutationIdle<TData, TError, TVariables>
    extends MutationSnapshot<TData, TError, TVariables> {
  /// Creates an idle snapshot.
  const MutationIdle({
    required super.submittedAt,
    required super.failureCount,
    required super.failureReason,
    required super.isPaused,
    required super.mutate,
    required super.mutateAsync,
    required super.reset,
  });

  @override
  TData? get dataOrNull => null;

  @override
  TVariables? get variablesOrNull => null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MutationIdle<TData, TError, TVariables> &&
          submittedAt == other.submittedAt &&
          failureCount == other.failureCount &&
          deepEq.equals(failureReason, other.failureReason) &&
          isPaused == other.isPaused;

  @override
  int get hashCode => Object.hash(
        runtimeType,
        submittedAt,
        failureCount,
        deepEq.hash(failureReason),
        isPaused,
      );

  @override
  String toString() => 'MutationIdle(isPaused: $isPaused)';
}

/// The mutation is currently executing.
///
/// This is an experimental API and may change in a future minor release.
final class MutationPending<TData, TError, TVariables>
    extends MutationSnapshot<TData, TError, TVariables> {
  /// Creates a pending snapshot.
  const MutationPending({
    required this.variables,
    required super.submittedAt,
    required super.failureCount,
    required super.failureReason,
    required super.isPaused,
    required super.mutate,
    required super.mutateAsync,
    required super.reset,
  });

  /// The variables passed to the in-flight mutation.
  final TVariables variables;

  @override
  TData? get dataOrNull => null;

  @override
  TVariables? get variablesOrNull => variables;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MutationPending<TData, TError, TVariables> &&
          deepEq.equals(variables, other.variables) &&
          submittedAt == other.submittedAt &&
          failureCount == other.failureCount &&
          deepEq.equals(failureReason, other.failureReason) &&
          isPaused == other.isPaused;

  @override
  int get hashCode => Object.hash(
        runtimeType,
        deepEq.hash(variables),
        submittedAt,
        failureCount,
        deepEq.hash(failureReason),
        isPaused,
      );

  @override
  String toString() => 'MutationPending('
      'variables: $variables, '
      'isPaused: $isPaused)';
}

/// The mutation completed successfully.
///
/// This is an experimental API and may change in a future minor release.
final class MutationSuccess<TData, TError, TVariables>
    extends MutationSnapshot<TData, TError, TVariables> {
  /// Creates a success snapshot.
  const MutationSuccess({
    required this.data,
    required this.variables,
    required super.submittedAt,
    required super.failureCount,
    required super.failureReason,
    required super.isPaused,
    required super.mutate,
    required super.mutateAsync,
    required super.reset,
  });

  /// The resolved data.
  final TData data;

  /// The variables passed to the mutation.
  final TVariables variables;

  @override
  TData? get dataOrNull => data;

  @override
  TVariables? get variablesOrNull => variables;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MutationSuccess<TData, TError, TVariables> &&
          deepEq.equals(data, other.data) &&
          deepEq.equals(variables, other.variables) &&
          submittedAt == other.submittedAt &&
          failureCount == other.failureCount &&
          deepEq.equals(failureReason, other.failureReason) &&
          isPaused == other.isPaused;

  @override
  int get hashCode => Object.hash(
        runtimeType,
        deepEq.hash(data),
        deepEq.hash(variables),
        submittedAt,
        failureCount,
        deepEq.hash(failureReason),
        isPaused,
      );

  @override
  String toString() => 'MutationSuccess('
      'data: $data, '
      'variables: $variables)';
}

/// The mutation encountered an error.
///
/// This is an experimental API and may change in a future minor release.
final class MutationError<TData, TError, TVariables>
    extends MutationSnapshot<TData, TError, TVariables> {
  /// Creates an error snapshot.
  const MutationError({
    required this.error,
    required this.variables,
    required super.submittedAt,
    required super.failureCount,
    required super.failureReason,
    required super.isPaused,
    required super.mutate,
    required super.mutateAsync,
    required super.reset,
  });

  /// The error thrown by the failed mutation.
  final TError error;

  /// The variables passed to the failed mutation.
  final TVariables variables;

  @override
  TData? get dataOrNull => null;

  @override
  TVariables? get variablesOrNull => variables;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MutationError<TData, TError, TVariables> &&
          deepEq.equals(error, other.error) &&
          deepEq.equals(variables, other.variables) &&
          submittedAt == other.submittedAt &&
          failureCount == other.failureCount &&
          deepEq.equals(failureReason, other.failureReason) &&
          isPaused == other.isPaused;

  @override
  int get hashCode => Object.hash(
        runtimeType,
        deepEq.hash(error),
        deepEq.hash(variables),
        submittedAt,
        failureCount,
        deepEq.hash(failureReason),
        isPaused,
      );

  @override
  String toString() => 'MutationError('
      'error: $error, '
      'variables: $variables)';
}

/// Maps a [MutationResult] into the sealed [MutationSnapshot] hierarchy.
@internal
extension MutationResultSnapshot<TData, TError, TVariables, TOnMutateResult>
    on MutationResult<TData, TError, TVariables, TOnMutateResult> {
  /// Converts this result into a [MutationSnapshot].
  MutationSnapshot<TData, TError, TVariables> toSnapshot() {
    switch (status) {
      case MutationStatus.idle:
        return MutationIdle<TData, TError, TVariables>(
          submittedAt: submittedAt,
          failureCount: failureCount,
          failureReason: failureReason,
          isPaused: isPaused,
          mutate: mutate,
          mutateAsync: mutateAsync,
          reset: reset,
        );
      case MutationStatus.pending:
        return MutationPending<TData, TError, TVariables>(
          variables: variables as TVariables,
          submittedAt: submittedAt,
          failureCount: failureCount,
          failureReason: failureReason,
          isPaused: isPaused,
          mutate: mutate,
          mutateAsync: mutateAsync,
          reset: reset,
        );
      case MutationStatus.success:
        return MutationSuccess<TData, TError, TVariables>(
          data: data as TData,
          variables: variables as TVariables,
          submittedAt: submittedAt,
          failureCount: failureCount,
          failureReason: failureReason,
          isPaused: isPaused,
          mutate: mutate,
          mutateAsync: mutateAsync,
          reset: reset,
        );
      case MutationStatus.error:
        return MutationError<TData, TError, TVariables>(
          error: error as TError,
          variables: variables as TVariables,
          submittedAt: submittedAt,
          failureCount: failureCount,
          failureReason: failureReason,
          isPaused: isPaused,
          mutate: mutate,
          mutateAsync: mutateAsync,
          reset: reset,
        );
    }
  }
}
