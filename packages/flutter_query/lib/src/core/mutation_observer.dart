import 'package:meta/meta.dart';

import 'mutation.dart';
import 'mutation_options.dart';
import 'mutation_snapshot.dart';
import 'mutation_state.dart';
import 'observable.dart';
import 'query_client.dart';

@internal
typedef MutationSnapshotListener<TData, TError, TVariables> = void Function(
  MutationSnapshot<TData, TError, TVariables> snapshot,
);

@internal
class MutationObserver<TData, TError, TVariables, TOnMutateResult>
    with Observer<MutationState<TData, TError, TVariables, TOnMutateResult>> {
  MutationObserver(
    this._client,
    MutationOptions<TData, TError, TVariables, TOnMutateResult> options,
  ) : _options = options.withDefaults(_client.defaultMutationOptions);

  final QueryClient _client;
  MutationOptions<TData, TError, TVariables, TOnMutateResult> _options;
  MutationSnapshot<TData, TError, TVariables>? _result;
  Mutation<TData, TError, TVariables, TOnMutateResult>? _mutation;

  final Set<MutationSnapshotListener<TData, TError, TVariables>> _listeners =
      {};

  MutationOptions<TData, TError, TVariables, TOnMutateResult> get options =>
      _options;

  MutationSnapshot<TData, TError, TVariables> get result {
    if (_result == null) {
      throw StateError(
        'Cannot access result before MutationObserver is mounted. '
        'Call onMount() first.',
      );
    }
    return _result!;
  }

  set options(
    MutationOptions<TData, TError, TVariables, TOnMutateResult> options,
  ) {
    final newOptions = options.withDefaults(_client.defaultMutationOptions);
    _options = newOptions;
  }

  set result(
    MutationSnapshot<TData, TError, TVariables> newResult,
  ) {
    if (newResult == _result) {
      return;
    }
    _result = newResult;
    for (final listener in _listeners) {
      listener(newResult);
    }
  }

  /// Executes the mutation with the given [variables].
  ///
  /// This is a fire-and-forget function. It does not return the mutation
  /// result and will not throw if the mutation fails. Use [mutateAsync]
  /// if you need to await the result or handle errors directly.
  void mutate(TVariables variables) {
    // ignore() swallows the error, matching TanStack Query's behavior
    mutateAsync(variables).ignore();
  }

  /// Executes the mutation with the given [variables] and returns the result.
  ///
  /// Returns a [Future] that completes with the mutation result data.
  /// The future will reject if the mutation fails.
  Future<TData> mutateAsync(TVariables variables) async {
    _mutation?.removeObserver(this);

    final mutation = _mutation = Mutation.cached(
      _client,
      mutationKey: _options.mutationKey,
      gcDuration: _options.gcDuration,
    );
    mutation.addObserver(this);

    return mutation.execute(
      variables,
      _options.mutationFn,
      onMutate: _options.onMutate,
      onSuccess: _options.onSuccess,
      onError: _options.onError,
      onSettled: _options.onSettled,
      retry: _options.retry,
      networkMode: _options.networkMode,
      meta: _options.meta,
    );
  }

  /// Resets the mutation to its initial idle state.
  void reset() {
    _mutation?.removeObserver(this);
    _mutation = null;
    result = _buildResult();
  }

  void onMount() {
    _result = _buildResult();
  }

  void onUnmount() {
    _listeners.clear();
    _mutation?.removeObserver(this);
  }

  @override
  void onNotified(
    MutationState<TData, TError, TVariables, TOnMutateResult> newState,
  ) {
    result = _buildResult(newState);
  }

  void Function() subscribe(
    MutationSnapshotListener<TData, TError, TVariables> listener,
  ) {
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  MutationSnapshot<TData, TError, TVariables> _buildResult([
    MutationState<TData, TError, TVariables, TOnMutateResult>? state,
  ]) {
    final status = state?.status ?? MutationStatus.idle;
    final submittedAt = state?.submittedAt;
    final failureCount = state?.failureCount ?? 0;
    final failureReason = state?.failureReason;
    final isPaused = state?.isPaused ?? false;

    switch (status) {
      case MutationStatus.idle:
        return MutationIdle<TData, TError, TVariables>(
          submittedAt: submittedAt,
          failureCount: failureCount,
          failureReason: failureReason,
          isPaused: isPaused,
          mutate: mutate,
          mutateAsync: mutateAsync,
          reset: reset,
        );
      case MutationStatus.pending:
        return MutationPending<TData, TError, TVariables>(
          variables: state!.variables as TVariables,
          submittedAt: submittedAt,
          failureCount: failureCount,
          failureReason: failureReason,
          isPaused: isPaused,
          mutate: mutate,
          mutateAsync: mutateAsync,
          reset: reset,
        );
      case MutationStatus.success:
        return MutationSuccess<TData, TError, TVariables>(
          data: state!.data as TData,
          variables: state.variables as TVariables,
          submittedAt: submittedAt,
          failureCount: failureCount,
          failureReason: failureReason,
          isPaused: isPaused,
          mutate: mutate,
          mutateAsync: mutateAsync,
          reset: reset,
        );
      case MutationStatus.error:
        return MutationError<TData, TError, TVariables>(
          error: state!.error as TError,
          variables: state.variables as TVariables,
          submittedAt: submittedAt,
          failureCount: failureCount,
          failureReason: failureReason,
          isPaused: isPaused,
          mutate: mutate,
          mutateAsync: mutateAsync,
          reset: reset,
        );
    }
  }
}
