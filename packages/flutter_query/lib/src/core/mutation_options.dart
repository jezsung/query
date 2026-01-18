import 'dart:async';

import 'default_mutation_options.dart';
import 'mutation_function_context.dart';
import 'query_options.dart';

/// Options for configuring a mutation.
///
/// Contains all the configuration options for a mutation including the mutation
/// function and callbacks for lifecycle events.
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

  /// The function that performs the mutation.
  final Future<TData> Function(
    TVariables variables,
    MutationFunctionContext context,
  ) mutationFn;

  /// Called before the mutation function is fired.
  ///
  /// Can be used to perform optimistic updates. The returned value
  /// is passed to onSuccess, onError, and onSettled callbacks as `onMutateResult`.
  final MutationOnMutate<TVariables, TOnMutateResult>? onMutate;

  /// Called when the mutation is successful.
  final MutationOnSuccess<TData, TVariables, TOnMutateResult>? onSuccess;

  /// Called when the mutation encounters an error.
  final MutationOnError<TError, TVariables, TOnMutateResult>? onError;

  /// Called when the mutation is either successful or errors.
  final MutationOnSettled<TData, TError, TVariables, TOnMutateResult>?
      onSettled;

  /// Optional key to identify this mutation.
  final List<Object?>? mutationKey;

  /// Retry configuration.
  ///
  /// Defaults to 0 (no retries) for mutations, unlike queries which default to 3.
  final RetryResolver<TError>? retry;

  /// Duration after which the mutation can be garbage collected.
  final GcDuration? gcDuration;

  /// Optional metadata associated with the mutation.
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

/// Callback invoked before the mutation function is executed.
///
/// Can be used to perform optimistic updates. The returned value is passed
/// to onSuccess, onError, and onSettled callbacks as `onMutateResult`.
typedef MutationOnMutate<TVariables, TOnMutateResult>
    = FutureOr<TOnMutateResult?> Function(
  TVariables variables,
  MutationFunctionContext context,
);

/// Callback invoked when the mutation is successful.
typedef MutationOnSuccess<TData, TVariables, TOnMutateResult> = FutureOr<void>
    Function(
  TData data,
  TVariables variables,
  TOnMutateResult? onMutateResult,
  MutationFunctionContext context,
);

/// Callback invoked when the mutation encounters an error.
typedef MutationOnError<TError, TVariables, TOnMutateResult> = FutureOr<void>
    Function(
  TError error,
  TVariables variables,
  TOnMutateResult? onMutateResult,
  MutationFunctionContext context,
);

/// Callback invoked when the mutation is either successful or errors.
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
