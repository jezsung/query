import 'dart:async';

import 'default_mutation_options.dart';
import 'mutation_function_context.dart';
import 'query_options.dart';

class MutationOptions<TData, TError, TVariables, TOnMutateResult> {
  MutationOptions({
    required this.mutationFn,
    this.onMutate,
    this.onSuccess,
    this.onError,
    this.onSettled,
    this.mutationKey,
    this.retry,
    this.gcDuration,
    this.meta,
  });

  final Future<TData> Function(
    TVariables variables,
    MutationFunctionContext context,
  ) mutationFn;
  final MutationOnMutate<TVariables, TOnMutateResult>? onMutate;
  final MutationOnSuccess<TData, TVariables, TOnMutateResult>? onSuccess;
  final MutationOnError<TError, TVariables, TOnMutateResult>? onError;
  final MutationOnSettled<TData, TError, TVariables, TOnMutateResult>?
      onSettled;
  final List<Object?>? mutationKey;
  final RetryResolver<TError>? retry;
  final GcDuration? gcDuration;
  final Map<String, dynamic>? meta;

  @override
  String toString() {
    return 'MutationOptions('
        'onMutate: ${onMutate != null ? '<Function>' : 'null'}, '
        'onSuccess: ${onSuccess != null ? '<Function>' : 'null'}, '
        'onError: ${onError != null ? '<Function>' : 'null'}, '
        'onSettled: ${onSettled != null ? '<Function>' : 'null'}, '
        'mutationKey: $mutationKey, '
        'retry: ${retry != null ? '<Function>' : 'null'}, '
        'gcDuration: $gcDuration, '
        'meta: $meta)';
  }
}

/// Callback invoked before the mutation function executes.
///
/// Use this to perform optimistic updates. The returned value is passed to
/// [MutationOnSuccess], [MutationOnError], and [MutationOnSettled] callbacks
/// as `onMutateResult`.
typedef MutationOnMutate<TVariables, TOnMutateResult>
    = FutureOr<TOnMutateResult?> Function(
  TVariables variables,
  MutationFunctionContext context,
);

/// Callback invoked when the mutation succeeds.
///
/// Receives the [data] returned by the mutation function, the [variables]
/// passed to the mutation, and any [onMutateResult] returned from the
/// [MutationOnMutate] callback.
typedef MutationOnSuccess<TData, TVariables, TOnMutateResult> = FutureOr<void>
    Function(
  TData data,
  TVariables variables,
  TOnMutateResult? onMutateResult,
  MutationFunctionContext context,
);

/// Callback invoked when the mutation fails.
///
/// Receives the [error] thrown by the mutation function, the [variables]
/// passed to the mutation, and any [onMutateResult] returned from the
/// [MutationOnMutate] callback. Use this to roll back optimistic updates.
typedef MutationOnError<TError, TVariables, TOnMutateResult> = FutureOr<void>
    Function(
  TError error,
  TVariables variables,
  TOnMutateResult? onMutateResult,
  MutationFunctionContext context,
);

/// Callback invoked when the mutation completes, regardless of outcome.
///
/// Called after either [MutationOnSuccess] or [MutationOnError]. Receives the
/// [data] if successful, the [error] if failed, the [variables] passed to the
/// mutation, and any [onMutateResult] returned from [MutationOnMutate].
typedef MutationOnSettled<TData, TError, TVariables, TOnMutateResult>
    = FutureOr<void> Function(
  TData? data,
  TError? error,
  TVariables variables,
  TOnMutateResult? onMutateResult,
  MutationFunctionContext context,
);

extension MutationOptionsExt<TData, TError, TVariables, TOnMutateResult>
    on MutationOptions<TData, TError, TVariables, TOnMutateResult> {
  /// Merges these options with the given defaults.
  ///
  /// Options specified here take precedence over defaults (null coalescing).
  MutationOptions<TData, TError, TVariables, TOnMutateResult> withDefaults(
    DefaultMutationOptions defaults,
  ) {
    return MutationOptions<TData, TError, TVariables, TOnMutateResult>(
      mutationFn: mutationFn,
      mutationKey: mutationKey,
      meta: meta,
      onMutate: onMutate,
      onSuccess: onSuccess,
      onError: onError,
      onSettled: onSettled,
      retry: retry ?? defaults.retry as RetryResolver<TError>?,
      gcDuration: gcDuration ?? defaults.gcDuration,
    );
  }
}
