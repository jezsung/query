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
  @visibleForTesting
  Query(this._client, this._queryKey)
      : _initialState = const QueryState(),
        _currentState = const QueryState() {
    onAddObserver = (_) {
      cancelGc();
      state = _currentState.copyWith(isActive: isActive);
    };
    onRemoveObserver = (observer) {
      state = _currentState.copyWith(isActive: isActive);
      if (observers.isEmpty) {
        scheduleGc(observer.options.gcDuration);
        if (state.fetchStatus == FetchStatus.fetching &&
            _abortController != null &&
            _abortController!.wasConsumed) {
          cancel(revert: true);
        }
      }
    };
  }

  factory Query.cached(
    QueryClient client,
    List<Object?> queryKey, {
    GcDuration? gcDuration,
    TData? seed,
    DateTime? seedUpdatedAt,
  }) {
    var query = client.cache.get<TData, TError>(queryKey);
    if (query == null) {
      query = Query<TData, TError>(client, queryKey);
      client.cache.add(query);
      query.scheduleGc(gcDuration ?? client.defaultQueryOptions.gcDuration);
    }

    if (seed != null) {
      query.setSeed(seed, seedUpdatedAt);
    }

    return query;
  }

  final QueryClient _client;
  final List<Object?> _queryKey;
  QueryState<TData, TError> _initialState;
  QueryState<TData, TError> _currentState;

  Retryer<TData, TError>? _retryer;
  AbortController? _abortController;
  QueryState<TData, TError>? _revertState;

  QueryKey get key => QueryKey(_queryKey);

  QueryState<TData, TError> get state => _currentState;

  bool get isActive {
    return observers.any((observer) => observer.options.enabled ?? true);
  }

  bool get isStatic {
    return observers.any(
      (observer) => observer.options.staleDuration == StaleDuration.static,
    );
  }

  @protected
  set state(QueryState<TData, TError> newState) {
    if (newState != _currentState) {
      _currentState = newState;
      notifyObservers(_currentState);
    }
  }

  void setSeed(TData seed, [DateTime? updatedAt]) {
    final data = _currentState.data;
    final dataUpdatedAt = _currentState.dataUpdatedAt;

    if (data == seed && dataUpdatedAt != null) {
      return;
    }

    if (updatedAt != null &&
        dataUpdatedAt != null &&
        updatedAt.isBefore(dataUpdatedAt)) {
      return;
    }

    state = _initialState = QueryState<TData, TError>(
      status: QueryStatus.success,
      fetchStatus: FetchStatus.idle,
      data: seed,
      dataUpdatedAt: updatedAt ?? clock.now(),
      error: null,
      errorUpdatedAt: null,
      errorUpdateCount: 0,
      failureCount: 0,
      failureReason: null,
      isActive: isActive,
    );
  }

  TData setData(TData data, {DateTime? updatedAt}) {
    state = QueryState<TData, TError>(
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

  Future<TData> fetch(
    QueryFn<TData> queryFn, {
    GcDuration? gcDuration,
    RetryResolver<TError>? retry,
    Map<String, dynamic>? meta,
    bool cancelRefetch = false,
  }) async {
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
      meta: observers.map((observer) => observer.options.meta).fold(
                deepMergeMap(_client.defaultQueryOptions.meta, meta),
                deepMergeMap,
              ) ??
          const {},
    );

    final retryer = _retryer = Retryer<TData, TError>(
      () => queryFn(context),
      retry ?? _client.defaultQueryOptions.retry ?? retryExponentialBackoff,
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
      scheduleGc(gcDuration ?? observers.lastOrNull?.options.gcDuration);
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
    unawaited(cancel(revert: true, silent: true));
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

  @override
  void tryRemove() {
    if (!hasObservers && state.fetchStatus == FetchStatus.idle) {
      _client.cache.remove(this);
    }
  }
}

@internal
extension QueryExt on Query {
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
  /// - [test]: custom filter function that receives the query key and state,
  ///   and returns whether it should be included
  bool matchesWhere(
      bool Function(List<Object?> queryKey, QueryState state) test) {
    return test(key.parts, state);
  }
}
