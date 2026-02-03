import 'package:meta/meta.dart';

import 'utils.dart';

/// The execution status of a mutation.
enum MutationStatus {
  /// The mutation has not been invoked yet.
  idle,

  /// The mutation is currently executing.
  pending,

  /// The mutation completed successfully.
  success,

  /// The mutation encountered an error.
  error,
}

/// The internal state of a mutation.
///
/// Contains all data and metadata for a mutation's current state, including
/// the status, result data, error, and failure tracking.
final class MutationState<TData, TError, TVariables, TOnMutateResult> {
  /// Creates a mutation state.
  const MutationState({
    this.status = MutationStatus.idle,
    this.data,
    this.error,
    this.variables,
    this.onMutateResult,
    this.submittedAt,
    this.failureCount = 0,
    this.failureReason,
    this.isPaused = false,
  });

  /// The current status of the mutation.
  final MutationStatus status;

  /// The last successfully resolved data for this mutation.
  final TData? data;

  /// The error thrown by the last failed mutation, if any.
  final TError? error;

  /// The variables passed to the most recent mutation call.
  final TVariables? variables;

  /// The result returned by the onMutate callback.
  final TOnMutateResult? onMutateResult;

  /// The timestamp when the mutation was submitted.
  final DateTime? submittedAt;

  /// The number of times the current mutation has failed.
  final int failureCount;

  /// The error from the most recent failed mutation attempt.
  final TError? failureReason;

  /// Whether the mutation is paused.
  final bool isPaused;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MutationState<TData, TError, TVariables, TOnMutateResult> &&
          status == other.status &&
          deepEq.equals(data, other.data) &&
          deepEq.equals(error, other.error) &&
          deepEq.equals(variables, other.variables) &&
          deepEq.equals(onMutateResult, other.onMutateResult) &&
          submittedAt == other.submittedAt &&
          failureCount == other.failureCount &&
          deepEq.equals(failureReason, other.failureReason) &&
          isPaused == other.isPaused;

  @override
  int get hashCode => Object.hash(
        status,
        deepEq.hash(data),
        deepEq.hash(error),
        deepEq.hash(variables),
        deepEq.hash(onMutateResult),
        submittedAt,
        failureCount,
        deepEq.hash(failureReason),
        isPaused,
      );

  @override
  String toString() => 'MutationState('
      'status: $status, '
      'data: $data, '
      'error: $error, '
      'variables: $variables, '
      'onMutateResult: $onMutateResult, '
      'submittedAt: $submittedAt, '
      'failureCount: $failureCount, '
      'failureReason: $failureReason, '
      'isPaused: $isPaused)';
}

@internal
extension MutationStateExt<TData, TError, TVariables, TOnMutateResult>
    on MutationState<TData, TError, TVariables, TOnMutateResult> {
  MutationState<TData, TError, TVariables, TOnMutateResult> copyWith({
    MutationStatus? status,
    TData? data,
    TError? error,
    TVariables? variables,
    TOnMutateResult? onMutateResult,
    DateTime? submittedAt,
    int? failureCount,
    TError? failureReason,
    bool? isPaused,
  }) {
    return MutationState<TData, TError, TVariables, TOnMutateResult>(
      status: status ?? this.status,
      data: data ?? this.data,
      error: error ?? this.error,
      variables: variables ?? this.variables,
      onMutateResult: onMutateResult ?? this.onMutateResult,
      submittedAt: submittedAt ?? this.submittedAt,
      failureCount: failureCount ?? this.failureCount,
      failureReason: failureReason ?? this.failureReason,
      isPaused: isPaused ?? this.isPaused,
    );
  }

  MutationState<TData, TError, TVariables, TOnMutateResult> copyWithNull({
    bool data = false,
    bool error = false,
    bool onMutateResult = false,
    bool failureReason = false,
  }) {
    return MutationState<TData, TError, TVariables, TOnMutateResult>(
      status: status,
      data: data ? null : this.data,
      error: error ? null : this.error,
      variables: variables,
      onMutateResult: onMutateResult ? null : this.onMutateResult,
      submittedAt: submittedAt,
      failureCount: failureCount,
      failureReason: failureReason ? null : this.failureReason,
      isPaused: isPaused,
    );
  }
}
