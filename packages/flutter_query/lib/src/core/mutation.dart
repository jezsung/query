import 'package:clock/clock.dart';
import 'package:collection/collection.dart';

import 'mutation_cache.dart';
import 'mutation_function_context.dart';
import 'mutation_observer.dart';
import 'mutation_options.dart';
import 'mutation_state.dart';
import 'options/gc_duration.dart';
import 'query_client.dart';
import 'removable.dart';
import 'retryer.dart';

/// A mutation instance that manages the execution and state of a single mutation.
///
/// Mutations are used for creating, updating, or deleting data, as opposed to
/// queries which are used for fetching data.
///
/// Aligned with TanStack Query's Mutation class.
class Mutation<TData, TError, TVariables, TOnMutateResult> with Removable {
  Mutation({
    required QueryClient client,
    required MutationCache cache,
    required int mutationId,
    required MutationOptions<TData, TError, TVariables, TOnMutateResult>
        options,
    MutationState<TData, TError, TVariables, TOnMutateResult>? state,
  })  : _client = client,
        _cache = cache,
        _mutationId = mutationId,
        _options = options,
        _state = state ??
            MutationState<TData, TError, TVariables, TOnMutateResult>() {
    updateGcDuration(_options.gcDuration ?? const GcDuration(minutes: 5));
    scheduleGc();
  }

  final QueryClient _client;
  final MutationCache _cache;
  final int _mutationId;
  MutationOptions<TData, TError, TVariables, TOnMutateResult> _options;
  MutationState<TData, TError, TVariables, TOnMutateResult> _state;

  Retryer<TData, TError>? _retryer;

  int get mutationId => _mutationId;
  MutationOptions<TData, TError, TVariables, TOnMutateResult> get options =>
      _options;
  MutationState<TData, TError, TVariables, TOnMutateResult> get state => _state;

  set options(
    MutationOptions<TData, TError, TVariables, TOnMutateResult> newOption,
  ) {
    _options = newOption;
    if (newOption.gcDuration != null) {
      updateGcDuration(newOption.gcDuration!);
    }
  }

  /// Attempts to remove the mutation from cache.
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
      meta: _options.meta,
      mutationKey: _options.mutationKey,
    );

    // Default retry: 0 retries for mutations (unlike queries which default to 3)
    Duration? defaultRetry(int retryCount, TError error) {
      return null; // No retries by default
    }

    _retryer = Retryer<TData, TError>(
      fn: () => _options.mutationFn(variables, fnContext),
      retry: _options.retry ?? defaultRetry,
      onFail: (failureCount, error) {
        _setState(_state.copyWith(
          failureCount: failureCount,
          failureReason: error,
        ));
      },
    );

    try {
      // Dispatch pending state
      _setState(MutationState<TData, TError, TVariables, TOnMutateResult>(
        status: MutationStatus.pending,
        variables: variables,
        submittedAt: clock.now(),
        failureCount: 0,
        isPaused: false,
      ));

      // Call onMutate callback
      TOnMutateResult? onMutateResult;
      if (_options.onMutate != null) {
        onMutateResult = await _options.onMutate!(variables, fnContext);
        if (onMutateResult != _state.onMutateResult) {
          _setState(_state.copyWith(onMutateResult: onMutateResult));
        }
      }

      // Execute the mutation
      final data = await _retryer!.start();

      // Call onSuccess callback
      if (_options.onSuccess != null) {
        await _options.onSuccess!(
            data, variables, _state.onMutateResult, fnContext);
      }

      // Call onSettled callback
      if (_options.onSettled != null) {
        await _options.onSettled!(
            data, null, variables, _state.onMutateResult, fnContext);
      }

      // Dispatch success state
      _setState(_state
          .copyWith(
            status: MutationStatus.success,
            data: data,
            failureCount: 0,
            isPaused: false,
          )
          .copyWithNull(
            error: true,
            failureReason: true,
          ));

      return data;
    } catch (error) {
      try {
        // Call onError callback
        if (_options.onError != null) {
          await _options.onError!(
            error as TError,
            variables,
            _state.onMutateResult,
            fnContext,
          );
        }

        // Call onSettled callback
        if (_options.onSettled != null) {
          await _options.onSettled!(
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
        _setState(_state
            .copyWith(
              status: MutationStatus.error,
              error: error as TError,
              failureCount: _state.failureCount + 1,
              failureReason: error as TError,
              isPaused: false,
            )
            .copyWithNull(data: true));
      }
    }
  }

  void _setState(
    MutationState<TData, TError, TVariables, TOnMutateResult> newState,
  ) {
    if (newState == _state) return;

    _state = newState;

    // Notify all observers
    for (final observer in _observers) {
      observer.onMutationUpdate();
    }
  }

  // ---------------------------------------------------------------------------
  // Observer Management
  // ---------------------------------------------------------------------------
  final List<MutationObserver<TData, TError, TVariables, TOnMutateResult>>
      _observers = [];

  bool get hasObservers => _observers.isNotEmpty;

  /// Adds an observer to this mutation.
  void addObserver(
      MutationObserver<TData, TError, TVariables, TOnMutateResult> observer) {
    if (!_observers.contains(observer)) {
      _observers.add(observer);
      cancelGc();
    }
  }

  /// Removes an observer from this mutation.
  void removeObserver(
      MutationObserver<TData, TError, TVariables, TOnMutateResult> observer) {
    _observers.remove(observer);
    scheduleGc();
  }
  // ---------------------------------------------------------------------------
}

const _equality = DeepCollectionEquality();

/// Extension methods for matching mutations against filters.
///
/// Aligned with TanStack Query's matchMutation utility function.
extension Matches on Mutation {
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
