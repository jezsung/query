import 'package:meta/meta.dart';

import 'mutation.dart';
import 'mutation_options.dart';
import 'mutation_result.dart';
import 'mutation_state.dart';
import 'observable.dart';
import 'query_client.dart';

@internal
typedef MutationResultListener<TData, TError, TVariables, TOnMutateResult>
    = void Function(
  MutationResult<TData, TError, TVariables, TOnMutateResult> result,
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
  MutationResult<TData, TError, TVariables, TOnMutateResult>? _result;
  Mutation<TData, TError, TVariables, TOnMutateResult>? _mutation;

  final Set<MutationResultListener<TData, TError, TVariables, TOnMutateResult>>
      _listeners = {};

  MutationOptions<TData, TError, TVariables, TOnMutateResult> get options =>
      _options;

  MutationResult<TData, TError, TVariables, TOnMutateResult> get result {
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
    MutationResult<TData, TError, TVariables, TOnMutateResult> newResult,
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
  Future<TData> mutate(TVariables variables) async {
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
    MutationResultListener<TData, TError, TVariables, TOnMutateResult> listener,
  ) {
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  MutationResult<TData, TError, TVariables, TOnMutateResult> _buildResult([
    MutationState<TData, TError, TVariables, TOnMutateResult>? state,
  ]) {
    return MutationResult<TData, TError, TVariables, TOnMutateResult>(
      status: state?.status ?? MutationStatus.idle,
      data: state?.data,
      error: state?.error,
      variables: state?.variables,
      submittedAt: state?.submittedAt,
      failureCount: state?.failureCount ?? 0,
      failureReason: state?.failureReason,
      isPaused: state?.isPaused ?? false,
      mutate: mutate,
      reset: reset,
    );
  }
}
