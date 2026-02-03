import 'dart:async';

import 'package:meta/meta.dart';

import 'default_mutation_options.dart';
import 'mutation_function_context.dart';
import 'network_mode.dart';
import 'query_options.dart';
import 'utils.dart';

/// Options for configuring a mutation.
///
/// Contains all configuration for executing a mutation, including the mutation
/// function, lifecycle callbacks, and retry behavior.
class MutationOptions<TData, TError, TVariables, TOnMutateResult> {
  /// Creates mutation options.
  MutationOptions({
    required this.mutationFn,
    this.onMutate,
    this.onSuccess,
    this.onError,
    this.onSettled,
    this.mutationKey,
    this.networkMode,
    this.gcDuration,
    this.retry,
    this.meta,
  });

  /// The function that performs the mutation.
  final MutateFn<TData, TVariables> mutationFn;

  /// Callback invoked before the mutation function executes.
  final MutationOnMutate<TVariables, TOnMutateResult>? onMutate;

  /// Callback invoked when the mutation succeeds.
  final MutationOnSuccess<TData, TVariables, TOnMutateResult>? onSuccess;

  /// Callback invoked when the mutation fails.
  final MutationOnError<TError, TVariables, TOnMutateResult>? onError;

  /// Callback invoked when the mutation completes, regardless of outcome.
  final MutationOnSettled<TData, TError, TVariables, TOnMutateResult>?
      onSettled;

  /// Optional key to identify this mutation.
  final List<Object?>? mutationKey;

  /// The network connectivity mode for this mutation.
  final NetworkMode? networkMode;

  /// How long completed mutation data remains in cache.
  final GcDuration? gcDuration;

  /// Retry behavior for failed mutations.
  final RetryResolver<TError>? retry;

  /// Arbitrary metadata associated with this mutation.
  final Map<String, dynamic>? meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MutationOptions<TData, TError, TVariables, TOnMutateResult> &&
          identical(mutationFn, other.mutationFn) &&
          identical(onMutate, other.onMutate) &&
          identical(onSuccess, other.onSuccess) &&
          identical(onError, other.onError) &&
          identical(onSettled, other.onSettled) &&
          deepEq.equals(mutationKey, other.mutationKey) &&
          networkMode == other.networkMode &&
          gcDuration == other.gcDuration &&
          identical(retry, other.retry) &&
          deepEq.equals(meta, other.meta);

  @override
  int get hashCode => Object.hash(
        identityHashCode(mutationFn),
        identityHashCode(onMutate),
        identityHashCode(onSuccess),
        identityHashCode(onError),
        identityHashCode(onSettled),
        deepEq.hash(mutationKey),
        networkMode,
        gcDuration,
        identityHashCode(retry),
        deepEq.hash(meta),
      );

  @override
  String toString() => 'MutationOptions('
      'onMutate: ${onMutate != null ? '<Function>' : 'null'}, '
      'onSuccess: ${onSuccess != null ? '<Function>' : 'null'}, '
      'onError: ${onError != null ? '<Function>' : 'null'}, '
      'onSettled: ${onSettled != null ? '<Function>' : 'null'}, '
      'mutationKey: $mutationKey, '
      'networkMode: $networkMode, '
      'gcDuration: $gcDuration, '
      'retry: ${retry != null ? '<Function>' : 'null'}, '
      'meta: $meta)';
}

/// Signature for the function that performs the mutation.
///
/// Receives the [variables] to mutate and a [context] containing metadata
/// like the [MutationFunctionContext.signal] for cancellation.
typedef MutateFn<TData, TVariables> = Future<TData> Function(
  TVariables variables,
  MutationFunctionContext context,
);

/// Signature for a callback invoked before the mutation function executes.
///
/// Use this to perform optimistic updates. The returned value is passed to
/// [MutationOnSuccess], [MutationOnError], and [MutationOnSettled] callbacks
/// as `onMutateResult`.
typedef MutationOnMutate<TVariables, TOnMutateResult>
    = FutureOr<TOnMutateResult?> Function(
  TVariables variables,
  MutationFunctionContext context,
);

/// Signature for a callback invoked when the mutation succeeds.
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

/// Signature for a callback invoked when the mutation fails.
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

/// Signature for a callback invoked when the mutation completes, regardless of outcome.
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

@internal
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
      onMutate: onMutate,
      onSuccess: onSuccess,
      onError: onError,
      onSettled: onSettled,
      mutationKey: mutationKey,
      networkMode: networkMode ?? defaults.networkMode,
      gcDuration: gcDuration ?? defaults.gcDuration,
      retry: retry ?? defaults.retry as RetryResolver<TError>?,
      meta: meta,
    );
  }
}
