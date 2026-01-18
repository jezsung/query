import 'mutation_state.dart';
import 'utils.dart';

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
  final Future<TData> Function(TVariables variables) mutate;
  final void Function() reset;

  bool get isIdle => status == MutationStatus.idle;
  bool get isPending => status == MutationStatus.pending;
  bool get isSuccess => status == MutationStatus.success;
  bool get isError => status == MutationStatus.error;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MutationResult<TData, TError, TVariables, TOnMutateResult> &&
          status == other.status &&
          deepEq.equals(data, other.data) &&
          deepEq.equals(error, other.error) &&
          deepEq.equals(variables, other.variables) &&
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
        submittedAt,
        failureCount,
        deepEq.hash(failureReason),
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
