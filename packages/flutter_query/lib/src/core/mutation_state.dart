import 'package:collection/collection.dart';

const _equality = DeepCollectionEquality();

enum MutationStatus { idle, pending, success, error }

final class MutationState<TData, TError, TVariables, TOnMutateResult> {
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

  final MutationStatus status;
  final TData? data;
  final TError? error;
  final TVariables? variables;
  final TOnMutateResult? onMutateResult;
  final DateTime? submittedAt;
  final int failureCount;
  final TError? failureReason;
  final bool isPaused;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MutationState<TData, TError, TVariables, TOnMutateResult> &&
        status == other.status &&
        _equality.equals(data, other.data) &&
        _equality.equals(error, other.error) &&
        _equality.equals(variables, other.variables) &&
        _equality.equals(onMutateResult, other.onMutateResult) &&
        submittedAt == other.submittedAt &&
        failureCount == other.failureCount &&
        _equality.equals(failureReason, other.failureReason) &&
        isPaused == other.isPaused;
  }

  @override
  int get hashCode => Object.hash(
        status,
        _equality.hash(data),
        _equality.hash(error),
        _equality.hash(variables),
        _equality.hash(onMutateResult),
        submittedAt,
        failureCount,
        _equality.hash(failureReason),
        isPaused,
      );

  @override
  String toString() {
    return 'MutationState('
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
}

extension CopyWith<TData, TError, TVariables, TOnMutateResult>
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
