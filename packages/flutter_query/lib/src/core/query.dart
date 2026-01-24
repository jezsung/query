import 'dart:async';

import 'package:clock/clock.dart';
import 'package:meta/meta.dart';

import 'abort_signal.dart';
import 'garbage_collectable.dart';
import 'observable.dart';
import 'query_client.dart';
import 'query_function_context.dart';
import 'query_key.dart';
import 'query_observer.dart';
import 'query_options.dart';
import 'query_state.dart';
import 'retryer.dart';
import 'utils.dart';

class Query<TData, TError>
    with
        Observable<QueryState<TData, TError>, QueryObserver<TData, TError>>,
        GarbageCollectable {
  Query(
    QueryClient client,
    QueryOptions<TData, TError> options,
  )   : _client = client,
        _options = options.withDefaults(client.defaultQueryOptions) {
    onAddObserver = (_) {
      cancelGc();
    };
    onRemoveObserver = (observer) {
      if (observers.isEmpty) {
        // Use the removed observer's gcDuration since it was the last one
        scheduleGc(observer.options.gcDuration ?? GcDuration(minutes: 5));
        if (state.fetchStatus == FetchStatus.fetching &&
            _abortController != null &&
            _abortController!.wasConsumed) {
          cancel(revert: true);
        }
      }
    };

    _initialState = switch (_options.seed) {
      final seed? => QueryState<TData, TError>.fromSeed(
          key.parts,
          seed,
          _options.seedUpdatedAt,
          isActive: isActive,
          meta: meta,
        ),
      null => QueryState<TData, TError>(
          key: key.parts,
          isActive: isActive,
          meta: meta,
        ),
    };
    _currentState = _initialState;

    scheduleGc(_options.gcDuration ?? GcDuration(minutes: 5));
  }

  final QueryClient _client;
  QueryOptions<TData, TError> _options;
  late QueryState<TData, TError> _initialState;
  late QueryState<TData, TError> _currentState;

  Retryer<TData, TError>? _retryer;
  AbortController? _abortController;
  QueryState<TData, TError>? _revertState;

  QueryKey get key => _options.queryKey;

  QueryState<TData, TError> get state => _currentState;

  bool get isActive {
    return observers.any((obs) => obs.options.enabled ?? true);
  }

  Map<String, dynamic> get meta {
    return observers
            .map((obs) => obs.options.meta)
            .fold(_options.meta, deepMergeMap) ??
        const {};
  }

  @protected
  set state(QueryState<TData, TError> newState) {
    _currentState = newState.copyWith(
      key: key.parts,
      isActive: isActive,
      meta: meta,
    );
    notifyObservers(_currentState);
  }

  set options(QueryOptions<TData, TError> newOptions) {
    _options = _options.merge(newOptions);
    if (state.data == null && _options.seed != null) {
      state = _initialState = QueryState<TData, TError>.fromSeed(
        key.parts,
        _options.seed as TData,
        _options.seedUpdatedAt,
        isActive: isActive,
        meta: meta,
      );
    }
  }

  Future<TData> fetch({bool cancelRefetch = false}) async {
    if (state.fetchStatus == FetchStatus.fetching && _retryer != null) {
      if (cancelRefetch && state.data != null) {
        unawaited(cancel(silent: true));
      } else {
        return _retryer!.future;
      }
    }

    _revertState = state;
    _abortController = AbortController();

    state = state
        .copyWith(
          fetchStatus: FetchStatus.fetching,
          failureCount: 0,
        )
        .copyWithNull(failureReason: true);

    final context = QueryFunctionContext(
      queryKey: key.parts,
      client: _client,
      signal: _abortController!.signal,
      meta: meta,
    );

    final retryer = _retryer = Retryer<TData, TError>(
      () => _options.queryFn(context),
      _options.retry ?? retryExponentialBackoff(),
      onFail: (failureCount, error) {
        state = state.copyWith(
          failureCount: failureCount,
          failureReason: error,
        );
      },
    );

    try {
      final data = await retryer.run();

      state = QueryState<TData, TError>(
        key: state.key,
        status: QueryStatus.success,
        fetchStatus: FetchStatus.idle,
        data: data,
        dataUpdatedAt: clock.now(),
        dataUpdateCount: state.dataUpdateCount + 1,
        error: null,
        errorUpdatedAt: state.errorUpdatedAt,
        errorUpdateCount: state.errorUpdateCount,
        failureCount: 0,
        failureReason: null,
        isInvalidated: false,
      );

      return data;
    } on AbortedException catch (e) {
      // Silent cancellation suppresses errors
      if (e.silent) {
        // Check if a new fetch started (cancelRefetch case)
        if (_retryer != retryer) {
          return _retryer!.future;
        }
        // External silent cancel - return existing data or never-completing future
        state = state.copyWith(fetchStatus: FetchStatus.idle);
        if (state.data != null) {
          return state.data as TData;
        }
        return Completer<TData>().future;
      }

      // Update state for non-silent cancellation
      state = switch (e.revert && _revertState != null) {
        true => _revertState!.copyWith(fetchStatus: FetchStatus.idle),
        false => state.copyWith(fetchStatus: FetchStatus.idle),
      };

      if (state.data == null) {
        rethrow;
      }
      return state.data as TData;
    } catch (error) {
      if (error is TError) {
        final typedError = error as TError;
        state = state.copyWith(
          status: QueryStatus.error,
          fetchStatus: FetchStatus.idle,
          error: typedError,
          errorUpdatedAt: clock.now(),
          errorUpdateCount: state.errorUpdateCount + 1,
          failureCount: state.failureCount + 1,
          failureReason: typedError,
        );
      }
      rethrow;
    } finally {
      _abortController = null;
      _revertState = null;
    }
  }

  void invalidate() {
    if (!state.isInvalidated) {
      state = state.copyWith(isInvalidated: true);
    }
  }

  Future<void> cancel({bool revert = true, bool silent = false}) async {
    _abortController?.abort(revert: revert, silent: silent);

    final retryer = _retryer;
    if (retryer == null) return;

    retryer.cancel(error: AbortedException(revert: revert, silent: silent));
    await retryer.future.then((_) {}).catchError((_) {}) ?? Future.value();
  }

  void reset() {
    cancelGc();
    state = _initialState;
  }

  bool shouldFetch(StaleDuration staleDuration) {
    if (state.data == null || state.dataUpdatedAt == null) return true;
    if (staleDuration is StaleDurationStatic) return false;
    if (state.isInvalidated) return true;

    return switch (staleDuration) {
      StaleDurationValue duration =>
        clock.now().difference(state.dataUpdatedAt!) >= duration,
      StaleDurationInfinity() => false,
      StaleDurationStatic() => false,
    };
  }

  TData setData(TData data, {DateTime? updatedAt}) {
    state = QueryState<TData, TError>(
      key: state.key,
      status: QueryStatus.success,
      fetchStatus: FetchStatus.idle,
      data: data,
      dataUpdatedAt: updatedAt ?? clock.now(),
      dataUpdateCount: state.dataUpdateCount + 1,
      error: null,
      errorUpdatedAt: state.errorUpdatedAt,
      errorUpdateCount: state.errorUpdateCount,
      failureCount: 0,
      failureReason: null,
      isInvalidated: false,
    );

    return data;
  }

  @override
  void tryRemove() {
    if (!hasObservers && state.fetchStatus == FetchStatus.idle) {
      _client.cache.remove(this);
    }
  }
}

/// Extension methods for matching queries against filters.
///
/// Aligned with TanStack Query's matchQuery utility function.
@internal
extension QueryMatches on Query {
  /// Returns true if this query's key matches the given key.
  ///
  /// - [queryKey]: the key to match against (required)
  /// - [exact]: when true, the query key must exactly equal the filter key;
  ///   when false (default), the query key only needs to start with the filter key
  bool matches(List<Object?> queryKey, {bool exact = false}) {
    final filterKey = QueryKey(queryKey);
    if (exact) {
      return key == filterKey;
    } else {
      return key.startsWith(filterKey);
    }
  }

  /// Returns true if this query matches the given predicate [test].
  ///
  /// - [test]: custom filter function that receives the query state and returns
  ///   whether it should be included
  bool matchesWhere(bool Function(QueryState state) test) {
    return test(state);
  }
}
