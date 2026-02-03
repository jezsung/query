import 'package:clock/clock.dart';
import 'package:meta/meta.dart';

import 'garbage_collectable.dart';
import 'mutation_cache_event.dart';
import 'mutation_function_context.dart';
import 'mutation_observer.dart';
import 'mutation_options.dart';
import 'mutation_state.dart';
import 'network_mode.dart';
import 'observable.dart';
import 'query_client.dart';
import 'query_options.dart';
import 'retry_controller.dart';
import 'utils.dart';

@internal
class Mutation<TData, TError, TVariables, TOnMutateResult>
    with
        Observable<MutationState<TData, TError, TVariables, TOnMutateResult>,
            MutationObserver<TData, TError, TVariables, TOnMutateResult>>,
        GarbageCollectable {
  @visibleForTesting
  Mutation(
    this._client, {
    this.mutationKey,
  })  : mutationId = _client.mutationCache.getNextMutationId(),
        _state = const MutationState() {
    onAddObserver = (observer) {
      cancelGc();
    };
    onRemoveObserver = (observer) {
      scheduleGc(observer.options.gcDuration);
    };
  }

  factory Mutation.cached(
    QueryClient client, {
    List<Object?>? mutationKey,
    GcDuration? gcDuration,
  }) {
    final mutation = Mutation<TData, TError, TVariables, TOnMutateResult>(
      client,
      mutationKey: mutationKey,
    );
    client.mutationCache.add(mutation);
    mutation.scheduleGc(gcDuration ?? client.defaultMutationOptions.gcDuration);
    return mutation;
  }

  final QueryClient _client;
  final int mutationId;
  final List<Object?>? mutationKey;
  MutationState<TData, TError, TVariables, TOnMutateResult> _state;

  RetryController<TData, TError>? _retryController;
  NetworkMode? _currentNetworkMode;

  MutationState<TData, TError, TVariables, TOnMutateResult> get state => _state;

  @protected
  set state(
    MutationState<TData, TError, TVariables, TOnMutateResult> newState,
  ) {
    if (newState != _state) {
      _state = newState;
      notifyObservers(newState);
      _client.mutationCache.dispatch(MutationUpdatedEvent(this));
    }
  }

  /// Executes the mutation with the given variables.
  ///
  /// This is the main entry point for running a mutation. It:
  /// 1. Calls onMutate callback (for optimistic updates)
  /// 2. Executes the mutation function
  /// 3. On success: calls onSuccess then onSettled
  /// 4. On error: calls onError then onSettled
  Future<TData> execute(
    TVariables variables,
    MutateFn<TData, TVariables> mutationFn, {
    MutationOnMutate<TVariables, TOnMutateResult>? onMutate,
    MutationOnSuccess<TData, TVariables, TOnMutateResult>? onSuccess,
    MutationOnError<TError, TVariables, TOnMutateResult>? onError,
    MutationOnSettled<TData, TError, TVariables, TOnMutateResult>? onSettled,
    RetryResolver<TError>? retry,
    NetworkMode? networkMode,
    Map<String, dynamic>? meta,
  }) async {
    _currentNetworkMode =
        networkMode ?? _client.defaultMutationOptions.networkMode;

    final fnContext = MutationFunctionContext(
      client: _client,
      meta: [_client.defaultMutationOptions.meta, meta]
          .followedBy(observers.map((observer) => observer.options.meta))
          .nonNulls
          .deepMergeAll(),
      mutationKey: mutationKey,
    );

    // Determine initial paused state based on network mode and online state
    final initialIsPaused = !canFetch(_currentNetworkMode!, _client.isOnline);

    _retryController = RetryController<TData, TError>(
      () => mutationFn(variables, fnContext),
      retry: retry ?? _client.defaultMutationOptions.retry,
      onError: (failureCount, error) {
        // Check if we should pause (network unavailable)
        if (!canContinue(_currentNetworkMode!, _client.isOnline)) {
          _retryController?.pause();
        }

        state = _state.copyWith(
          failureCount: failureCount,
          failureReason: error,
        );
      },
      onPause: () {
        state = _state.copyWith(isPaused: true);
      },
      onResume: () {
        state = _state.copyWith(isPaused: false);
      },
    );
    final retryController = _retryController!;

    try {
      // Dispatch pending state
      state = MutationState<TData, TError, TVariables, TOnMutateResult>(
        status: MutationStatus.pending,
        variables: variables,
        submittedAt: clock.now(),
        failureCount: 0,
        isPaused: initialIsPaused,
      );

      // Call onMutate callback
      TOnMutateResult? onMutateResult;
      if (onMutate != null) {
        onMutateResult = await onMutate(variables, fnContext);
        if (onMutateResult != _state.onMutateResult) {
          state = _state.copyWith(onMutateResult: onMutateResult);
        }
      }

      // Execute the mutation
      final data = await retryController.start(paused: initialIsPaused);

      // Call onSuccess callback
      if (onSuccess != null) {
        await onSuccess(data, variables, _state.onMutateResult, fnContext);
      }

      // Call onSettled callback
      if (onSettled != null) {
        await onSettled(
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
        if (onError != null) {
          await onError(
            error as TError,
            variables,
            _state.onMutateResult,
            fnContext,
          );
        }

        // Call onSettled callback
        if (onSettled != null) {
          await onSettled(
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
    } finally {
      _currentNetworkMode = null;
    }
  }

  @override
  void tryRemove() {
    if (hasObservers) {
      return;
    }
    if (_state.status == MutationStatus.pending) {
      // Don't remove pending mutations, reschedule GC
      rescheduleGc();
      return;
    }
    _client.mutationCache.remove(this);
  }

  /// Called when network connectivity is lost.
  ///
  /// Pauses the mutation if the network mode requires connectivity.
  void onOffline() {
    final retryController = _retryController;
    if (retryController == null ||
        retryController.isPaused ||
        retryController.isCancelled) {
      return;
    }

    // Check if we should pause based on network mode
    if (_currentNetworkMode != null &&
        !canContinue(_currentNetworkMode!, _client.isOnline)) {
      retryController.pause();
    }
  }

  /// Called when network connectivity is restored.
  ///
  /// Resumes the mutation if it was paused due to network unavailability.
  void onOnline() {
    final retryController = _retryController;
    if (retryController == null || !retryController.isPaused) return;

    // Check if we can actually continue based on network mode
    if (_currentNetworkMode != null &&
        canContinue(_currentNetworkMode!, _client.isOnline)) {
      retryController.resume();
    }
  }
}

@internal
extension MutationExt on Mutation {
  bool matches({
    List<Object?>? mutationKey,
    bool exact = false,
    bool Function(List<Object?>? mutationKey, MutationState state)? predicate,
    MutationStatus? status,
  }) {
    final key = this.mutationKey;

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
