import 'package:collection/collection.dart';

import 'mutation_state.dart';

const _equality = DeepCollectionEquality();

/// The result of a mutation, containing state and control methods.
///
/// This is the public API returned by useMutation and MutationObserver.
class MutationResult<TData, TError, TVariables, TOnMutateResult> {
  const MutationResult({
    required this.status,
    required this.data,
    required this.error,
    required this.variables,
    required this.submittedAt,
    required this.failureCount,
    required this.failureReason,
    required this.isPaused,
    required this.mutate,
    required this.reset,
  });

  final MutationStatus status;
  final TData? data;
  final TError? error;
  final TVariables? variables;
  final DateTime? submittedAt;
  final int failureCount;
  final TError? failureReason;
  final bool isPaused;

  /// Triggers the mutation with the given variables.
  final Future<TData> Function(TVariables variables) mutate;

  /// Resets the mutation to its initial idle state.
  final void Function() reset;

  /// True when status is idle (mutation has not been triggered yet or was reset).
  bool get isIdle => status == MutationStatus.idle;

  /// True when status is pending (mutation is currently executing).
  bool get isPending => status == MutationStatus.pending;

  /// True when status is success (last mutation completed successfully).
  bool get isSuccess => status == MutationStatus.success;

  /// True when status is error (last mutation resulted in an error).
  bool get isError => status == MutationStatus.error;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MutationResult<TData, TError, TVariables, TOnMutateResult> &&
          status == other.status &&
          _equality.equals(data, other.data) &&
          _equality.equals(error, other.error) &&
          _equality.equals(variables, other.variables) &&
          submittedAt == other.submittedAt &&
          failureCount == other.failureCount &&
          _equality.equals(failureReason, other.failureReason) &&
          isPaused == other.isPaused;

  @override
  int get hashCode => Object.hash(
        status,
        _equality.hash(data),
        _equality.hash(error),
        _equality.hash(variables),
        submittedAt,
        failureCount,
        _equality.hash(failureReason),
        isPaused,
      );

  @override
  String toString() {
    return 'MutationResult('
        'status: $status, '
        'data: $data, '
        'error: $error, '
        'variables: $variables, '
        'submittedAt: $submittedAt, '
        'failureCount: $failureCount, '
        'failureReason: $failureReason, '
        'isPaused: $isPaused, '
        'mutate: <Function>, '
        'reset: <Function>)';
  }
}
