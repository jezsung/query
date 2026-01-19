import 'mutation_state.dart';
import 'utils.dart';

/// Signature for a function that executes a mutation with the given variables.
///
/// Returns a [Future] that completes with the mutation result data.
typedef Mutate<TData, TVariables> = Future<TData> Function(
  TVariables variables,
);

/// Signature for a function that resets the mutation to its initial state.
typedef Reset = void Function();

/// The result of a mutation operation.
///
/// Contains the current state of a mutation including its data, error, and
/// status flags. This is the primary type returned by mutation observers and
/// provides both the mutation result and metadata about the mutation's lifecycle.
///
/// The type parameters are:
/// - [TData]: The type of data returned by the mutation.
/// - [TError]: The type of error that may occur during the mutation.
/// - [TVariables]: The type of variables passed to the mutation function.
/// - [TOnMutateResult]: The type of result returned by the onMutate callback.
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

  /// The current status of the mutation.
  final MutationStatus status;

  /// The last successfully resolved data for this mutation.
  final TData? data;

  /// The error thrown by the last failed mutation, if any.
  final TError? error;

  /// The variables passed to the most recent [mutate] call.
  final TVariables? variables;

  /// The timestamp when the mutation was submitted.
  final DateTime? submittedAt;

  /// The number of times the current mutation has failed.
  ///
  /// Resets to zero when a new mutation starts or when the mutation succeeds.
  final int failureCount;

  /// The error from the most recent failed mutation attempt.
  ///
  /// Resets to null when a new mutation starts or when the mutation succeeds.
  final TError? failureReason;

  /// Whether the mutation is paused.
  final bool isPaused;

  /// Executes the mutation with the given variables.
  final Mutate<TData, TVariables> mutate;

  /// Resets the mutation to its initial idle state.
  final Reset reset;

  /// Whether the mutation has not been called yet.
  bool get isIdle => status == MutationStatus.idle;

  /// Whether the mutation is currently executing.
  bool get isPending => status == MutationStatus.pending;

  /// Whether the mutation completed successfully.
  bool get isSuccess => status == MutationStatus.success;

  /// Whether the mutation is in an error state.
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
  String toString() => 'MutationResult('
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
