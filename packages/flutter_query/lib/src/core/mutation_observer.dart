import 'package:meta/meta.dart';

import 'mutation.dart';
import 'mutation_options.dart';
import 'mutation_result.dart';
import 'mutation_state.dart';
import 'observable.dart';
import 'query_client.dart';

/// Callback type for mutation result change listeners.
@internal
typedef MutationResultListener<TData, TError, TVariables, TOnMutateResult>
    = void Function(
        MutationResult<TData, TError, TVariables, TOnMutateResult> result);

/// Observer that bridges the hook layer to the mutation system.
///
/// MutationObserver manages the lifecycle of a mutation and provides
/// the result to the UI layer.
///
/// Aligned with TanStack Query's MutationObserver.
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

  /// Listeners that are notified when the result changes.
  final Set<MutationResultListener<TData, TError, TVariables, TOnMutateResult>>
      _listeners = {};

  MutationOptions<TData, TError, TVariables, TOnMutateResult> get options =>
      _options;
  MutationResult<TData, TError, TVariables, TOnMutateResult> get result =>
      _result;

  /// Sets the options for this observer, merging with client defaults.
  ///
  /// This setter applies the client's default mutation options to the provided
  /// options, then updates the observer and any active mutation.
  ///
  /// Aligned with TanStack Query's MutationObserver.setOptions().
  set options(
    MutationOptions<TData, TError, TVariables, TOnMutateResult> options,
  ) {
    _options = options.withDefaults(_client.defaultMutationOptions);
    _mutation?.options = _options;
  }

  /// Subscribe to result changes. Returns an unsubscribe function.
  void Function() subscribe(
    MutationResultListener<TData, TError, TVariables, TOnMutateResult> listener,
  ) {
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  /// Called by Mutation when its state changes.
  @override
  void onNotified(
    MutationState<TData, TError, TVariables, TOnMutateResult> newState,
  ) {
    final newResult = _buildResult(newState);
    _setResult(newResult);
  }

  /// Triggers the mutation with the given variables.
  ///
  /// Creates a new mutation instance and executes it.
  Future<TData> mutate(TVariables variables) async {
    // Remove observer from old mutation if exists
    _mutation?.removeObserver(this);

    // Create new mutation
    final mutation = _mutation = _client.mutationCache
        .build<TData, TError, TVariables, TOnMutateResult>(_options);
    mutation.addObserver(this);

    // Execute and return result
    return mutation.execute(variables);
  }

  /// Resets the mutation to its initial idle state.
  void reset() {
    _mutation?.removeObserver(this);
    _mutation = null;
    _setResult(_buildResult());
  }

  /// Disposes of the observer.
  void dispose() {
    _listeners.clear();
    _mutation?.removeObserver(this);
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

  void _setResult(
    MutationResult<TData, TError, TVariables, TOnMutateResult> newResult,
  ) {
    if (newResult == _result) return;

    _result = newResult;

    for (final listener in _listeners) {
      listener(newResult);
    }
  }
}
