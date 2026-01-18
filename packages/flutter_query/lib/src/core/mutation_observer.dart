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

class MutationObserver<TData, TError, TVariables, TOnMutateResult>
    with Observer<MutationState<TData, TError, TVariables, TOnMutateResult>> {
  MutationObserver(
    QueryClient client,
    MutationOptions<TData, TError, TVariables, TOnMutateResult> options,
  ) : _client = client {
    this.options = options;
    _result = _buildResult();
  }

  final QueryClient _client;
  late MutationOptions<TData, TError, TVariables, TOnMutateResult> _options;
  late MutationResult<TData, TError, TVariables, TOnMutateResult> _result;
  Mutation<TData, TError, TVariables, TOnMutateResult>? _mutation;

  final Set<MutationResultListener<TData, TError, TVariables, TOnMutateResult>>
      _listeners = {};

  MutationOptions<TData, TError, TVariables, TOnMutateResult> get options =>
      _options;
  MutationResult<TData, TError, TVariables, TOnMutateResult> get result =>
      _result;

  set options(
    MutationOptions<TData, TError, TVariables, TOnMutateResult> options,
  ) {
    _options = options.withDefaults(_client.defaultMutationOptions);
    _mutation?.options = _options;
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

    final mutation = _mutation = _client.mutationCache
        .build<TData, TError, TVariables, TOnMutateResult>(_options);
    mutation.addObserver(this);

    return mutation.execute(variables);
  }

  /// Resets the mutation to its initial idle state.
  void reset() {
    _mutation?.removeObserver(this);
    _mutation = null;
    result = _buildResult();
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
