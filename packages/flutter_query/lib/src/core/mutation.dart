import 'package:clock/clock.dart';
import 'package:meta/meta.dart';

import 'garbage_collectable.dart';
import 'mutation_function_context.dart';
import 'mutation_observer.dart';
import 'mutation_options.dart';
import 'mutation_state.dart';
import 'observable.dart';
import 'query_client.dart';
import 'query_options.dart';
import 'retryer.dart';
import 'utils.dart';

class Mutation<TData, TError, TVariables, TOnMutateResult>
    with
        Observable<MutationState<TData, TError, TVariables, TOnMutateResult>,
            MutationObserver<TData, TError, TVariables, TOnMutateResult>>,
        GarbageCollectable {
  @visibleForTesting
  Mutation(
    this._client,
    this.options,
    this.mutationId,
  ) : _state = const MutationState() {
    onAddObserver = (_) {
      cancelGc();
    };
    onRemoveObserver = (observer) {
      scheduleGc(observer.options.gcDuration);
    };
  }

  factory Mutation.cached(
    QueryClient client,
    MutationOptions<TData, TError, TVariables, TOnMutateResult> options,
  ) {
    final mutation = Mutation<TData, TError, TVariables, TOnMutateResult>(
      client,
      options,
      client.mutationCache.getNextMutationId(),
    );
    client.mutationCache.add(mutation);
    mutation.scheduleGc(options.gcDuration);
    return mutation;
  }

  final QueryClient _client;
  MutationOptions<TData, TError, TVariables, TOnMutateResult> options;
  final int mutationId;
  MutationState<TData, TError, TVariables, TOnMutateResult> _state;

  Retryer<TData, TError>? _retryer;

  MutationState<TData, TError, TVariables, TOnMutateResult> get state => _state;

  @protected
  set state(
    MutationState<TData, TError, TVariables, TOnMutateResult> newState,
  ) {
    if (newState != _state) {
      _state = newState;
      notifyObservers(newState);
    }
  }

  /// Executes the mutation with the given variables.
  ///
  /// This is the main entry point for running a mutation. It:
  /// 1. Calls onMutate callback (for optimistic updates)
  /// 2. Executes the mutation function
  /// 3. On success: calls onSuccess then onSettled
  /// 4. On error: calls onError then onSettled
  Future<TData> execute(TVariables variables) async {
    final fnContext = MutationFunctionContext(
      client: _client,
      meta: options.meta ?? const {},
      mutationKey: options.mutationKey,
    );

    _retryer = Retryer<TData, TError>(
      () => options.mutationFn(variables, fnContext),
      options.retry ?? retryNever,
      onFail: (failureCount, error) {
        state = _state.copyWith(
          failureCount: failureCount,
          failureReason: error,
        );
      },
    );

    try {
      // Dispatch pending state
      state = MutationState<TData, TError, TVariables, TOnMutateResult>(
        status: MutationStatus.pending,
        variables: variables,
        submittedAt: clock.now(),
        failureCount: 0,
        isPaused: false,
      );

      // Call onMutate callback
      TOnMutateResult? onMutateResult;
      if (options.onMutate != null) {
        onMutateResult = await options.onMutate!(variables, fnContext);
        if (onMutateResult != _state.onMutateResult) {
          state = _state.copyWith(onMutateResult: onMutateResult);
        }
      }

      // Execute the mutation
      final data = await _retryer!.run();

      // Call onSuccess callback
      if (options.onSuccess != null) {
        await options.onSuccess!(
            data, variables, _state.onMutateResult, fnContext);
      }

      // Call onSettled callback
      if (options.onSettled != null) {
        await options.onSettled!(
            data, null, variables, _state.onMutateResult, fnContext);
      }

      // Dispatch success state
      state = _state
          .copyWith(
            status: MutationStatus.success,
            data: data,
            failureCount: 0,
            isPaused: false,
          )
          .copyWithNull(
            error: true,
            failureReason: true,
          );

      return data;
    } catch (error) {
      try {
        // Call onError callback
        if (options.onError != null) {
          await options.onError!(
            error as TError,
            variables,
            _state.onMutateResult,
            fnContext,
          );
        }

        // Call onSettled callback
        if (options.onSettled != null) {
          await options.onSettled!(
            null,
            error as TError,
            variables,
            _state.onMutateResult,
            fnContext,
          );
        }

        rethrow;
      } finally {
        // Dispatch error state
        state = _state
            .copyWith(
              status: MutationStatus.error,
              error: error as TError,
              failureCount: _state.failureCount + 1,
              failureReason: error as TError,
              isPaused: false,
            )
            .copyWithNull(data: true);
      }
    }
  }

  @override
  void tryRemove() {
    if (hasObservers) {
      return;
    }
    if (_state.status == MutationStatus.pending) {
      // Don't remove pending mutations, reschedule GC
      scheduleGc(options.gcDuration ?? GcDuration(minutes: 5));
      return;
    }
    _client.mutationCache.remove(this);
  }
}

@internal
extension MutationMatches on Mutation {
  bool matches({
    List<Object?>? mutationKey,
    bool exact = false,
    bool Function(List<Object?>? mutationKey, MutationState state)? predicate,
    MutationStatus? status,
  }) {
    final key = options.mutationKey;

    if (mutationKey != null) {
      if (key == null) {
        return false;
      }

      if (exact) {
        if (!deepEq.equals(key, mutationKey)) {
          return false;
        }
      } else if (!_partialMatchKey(key, mutationKey)) {
        return false;
      }
    }

    if (status != null && state.status != status) {
      return false;
    }

    if (predicate != null && !predicate(key, state)) {
      return false;
    }

    return true;
  }

  static bool _partialMatchKey(List<Object?> key, List<Object?> prefix) {
    if (key.length < prefix.length) {
      return false;
    }
    for (var i = 0; i < prefix.length; i++) {
      if (!deepEq.equals(key[i], prefix[i])) {
        return false;
      }
    }
    return true;
  }
}
