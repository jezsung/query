import '../core/core.dart';
import '../hooks/use_mutation.dart' as core;
import 'mutation_snapshot.dart';

/// A hook for performing create, update, and delete operations.
///
/// Equivalent to the canonical `useMutation`, but returns a [MutationSnapshot]:
/// a `sealed` type that supports exhaustive pattern matching and exposes
/// non-nullable `data`/`error`/`variables` in the appropriate variants.
///
/// This is an experimental API exposed via
/// `package:flutter_query/experiments.dart`. See the canonical `useMutation`
/// for the meaning of every option.
///
/// This is an experimental API and may change in a future minor release.
MutationSnapshot<TData, TError, TVariables>
    useMutation<TData, TError, TVariables, TOnMutateResult>(
  MutateFn<TData, TVariables> mutationFn, {
  MutationOnMutate<TVariables, TOnMutateResult>? onMutate,
  MutationOnSuccess<TData, TVariables, TOnMutateResult>? onSuccess,
  MutationOnError<TError, TVariables, TOnMutateResult>? onError,
  MutationOnSettled<TData, TError, TVariables, TOnMutateResult>? onSettled,
  List<Object?>? mutationKey,
  NetworkMode? networkMode,
  GcDuration? gcDuration,
  RetryResolver<TError>? retry,
  Map<String, dynamic>? meta,
  QueryClient? client,
}) {
  final result = core.useMutation<TData, TError, TVariables, TOnMutateResult>(
    mutationFn,
    onMutate: onMutate,
    onSuccess: onSuccess,
    onError: onError,
    onSettled: onSettled,
    mutationKey: mutationKey,
    networkMode: networkMode,
    gcDuration: gcDuration,
    retry: retry,
    meta: meta,
    client: client,
  );

  return result.toSnapshot();
}
