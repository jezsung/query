import '../core/core.dart';
import '../hooks/use_mutation_options.dart' as core;
import 'mutation_snapshot.dart';

/// A hook for performing mutations from a pre-built [MutationOptions] object.
///
/// Equivalent to the canonical `useMutationOptions`, but returns a
/// [MutationSnapshot]: a `sealed` type that supports exhaustive pattern
/// matching and exposes non-nullable `data`/`error`/`variables` in the
/// appropriate variants.
///
/// This is the object-first counterpart to the experimental `useMutation`. See
/// the canonical `useMutationOptions` for the meaning of [options] and
/// [client].
///
/// This is an experimental API exposed via
/// `package:flutter_query/experiments.dart`, and may change in a future minor
/// release.
MutationSnapshot<TData, TError, TVariables>
    useMutationOptions<TData, TError, TVariables, TOnMutateResult>(
  MutationOptions<TData, TError, TVariables, TOnMutateResult> options, {
  QueryClient? client,
}) {
  final result =
      core.useMutationOptions<TData, TError, TVariables, TOnMutateResult>(
    options,
    client: client,
  );

  return result.toSnapshot();
}
