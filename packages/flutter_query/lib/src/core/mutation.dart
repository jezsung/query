import 'package:clock/clock.dart';
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'garbage_collectable.dart';
import 'mutation_cache.dart';
import 'mutation_function_context.dart';
import 'mutation_observer.dart';
import 'mutation_options.dart';
import 'mutation_state.dart';
import 'observable.dart';
import 'options/gc_duration.dart';
import 'query_client.dart';
import 'retryer.dart';

/// A mutation instance that manages the execution and state of a single mutation.
///
/// Mutations are used for creating, updating, or deleting data, as opposed to
/// queries which are used for fetching data.
///
/// Aligned with TanStack Query's Mutation class.
class Mutation<TData, TError, TVariables, TOnMutateResult>
    with
        Observable<MutationState<TData, TError, TVariables, TOnMutateResult>,
            MutationObserver<TData, TError, TVariables, TOnMutateResult>>,
        GarbageCollectable {
  Mutation({
    required QueryClient client,
    required MutationCache cache,
    required int mutationId,
    required this.options,
    MutationState<TData, TError, TVariables, TOnMutateResult>? state,
  })  : _client = client,
        _cache = cache,
        _mutationId = mutationId,
        _state = state ??
            MutationState<TData, TError, TVariables, TOnMutateResult>() {
    scheduleGc();
    onAddObserver = (_) {
      cancelGc();
    };
    onRemoveObserver = (_) {
      scheduleGc();
    };
  }

  final QueryClient _client;
  final MutationCache _cache;
  final int _mutationId;
  MutationOptions<TData, TError, TVariables, TOnMutateResult> options;
  MutationState<TData, TError, TVariables, TOnMutateResult> _state;

  Retryer<TData, TError>? _retryer;

  int get mutationId => _mutationId;

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
      meta: options.meta,
      mutationKey: options.mutationKey,
    );

    // Default retry: 0 retries for mutations (unlike queries which default to 3)
    Duration? defaultRetry(int retryCount, TError error) {
      return null; // No retries by default
    }

    _retryer = Retryer<TData, TError>(
      fn: () => options.mutationFn(variables, fnContext),
      retry: options.retry ?? defaultRetry,
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
      final data = await _retryer!.start();

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
  GcDuration get gcDuration {
    return observers
        .map((obs) => obs.options.gcDuration)
        .whereType<GcDuration>()
        .fold(
          // Defaults to 5 minutes
          options.gcDuration ?? const GcDuration(minutes: 5),
          (longest, duration) => duration > longest ? duration : longest,
        );
  }

  @override
  void tryRemove() {
    if (!hasObservers) {
      if (_state.status == MutationStatus.pending) {
        // Don't remove pending mutations, reschedule GC
        scheduleGc();
      } else {
        _cache.remove(this);
      }
    }
  }
}

const _equality = DeepCollectionEquality();

/// Extension methods for matching mutations against filters.
///
/// Aligned with TanStack Query's matchMutation utility function.
extension MutationMatches on Mutation {
  /// Returns true if this mutation matches the given filters.
  ///
  /// - [exact]: when true, the mutation key must exactly equal the filter key;
  ///   when false (default), the mutation key only needs to start with the filter key
  /// - [predicate]: custom filter function that receives the mutation and returns
  ///   whether it should be included
  /// - [mutationKey]: the key to match against; if the mutation has no key, it won't match
  /// - [status]: filters mutations by their current status (idle, pending, success, error)
  bool matches({
    bool exact = false,
    bool Function(Mutation)? predicate,
    List<Object?>? mutationKey,
    MutationStatus? status,
  }) {
    if (mutationKey != null) {
      final key = options.mutationKey;
      if (key == null) {
        return false;
      }

      if (exact) {
        if (!_equality.equals(key, mutationKey)) {
          return false;
        }
      } else if (!_partialMatchKey(key, mutationKey)) {
        return false;
      }
    }

    if (status != null && state.status != status) {
      return false;
    }

    if (predicate != null && !predicate(this)) {
      return false;
    }

    return true;
  }

  /// Checks if [key] starts with [prefix].
  ///
  /// Uses deep equality for comparing individual elements.
  static bool _partialMatchKey(List<Object?> key, List<Object?> prefix) {
    if (key.length < prefix.length) {
      return false;
    }
    for (var i = 0; i < prefix.length; i++) {
      if (!_equality.equals(key[i], prefix[i])) {
        return false;
      }
    }
    return true;
  }
}
