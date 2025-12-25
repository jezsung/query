import 'dart:async';

import 'package:clock/clock.dart';

import 'abort_signal.dart';
import 'garbage_collectable.dart';
import 'options/gc_duration.dart';
import 'options/stale_duration.dart';
import 'query_cache.dart';
import 'query_client.dart';
import 'query_function_context.dart';
import 'query_key.dart';
import 'query_observer.dart';
import 'query_options.dart';
import 'query_state.dart';
import 'retryer.dart';

class Query<TData, TError> with GarbageCollectable {
  Query(
    QueryClient client,
    QueryOptions<TData, TError> options,
  )   : _client = client,
        _options = options,
        _initialState = QueryState.fromSeed(
          options.initialData,
          options.initialDataUpdatedAt,
        ) {
    _state = _initialState;
    setOptions(options);
    scheduleGc();
  }

  final QueryClient _client;
  QueryOptions<TData, TError> _options;
  QueryState<TData, TError> _initialState;
  late QueryState<TData, TError> _state;
  final List<QueryObserver> _observers = [];
  Retryer<TData, TError>? _retryer;
  AbortController? _abortController;
  QueryState<TData, TError>? _revertState;

  List<Object?> get queryKey => _options.queryKey;
  QueryState<TData, TError> get state => _state;
  bool get hasObservers => _observers.isNotEmpty;

  bool get isActive {
    return _observers.any((observer) => observer.options.enabled ?? true);
  }

  bool get isDisabled {
    if (_observers.isNotEmpty) {
      return !isActive;
    }
    return state.status == QueryStatus.pending &&
        state.dataUpdatedAt == null &&
        state.errorUpdatedAt == null;
  }

  bool get isStatic {
    if (_observers.isEmpty) return false;
    return _observers.any((observer) {
      final opts = observer.options;
      final resolved = opts.staleDurationResolver != null
          ? opts.staleDurationResolver!(this)
          : opts.staleDuration;
      return resolved is StaleDurationStatic;
    });
  }

  bool isStaleByTime(StaleDuration staleDuration) {
    if (state.data == null) {
      return true;
    }

    if (staleDuration is StaleDurationStatic) {
      return false;
    }

    if (state.isInvalidated) {
      return true;
    }

    return switch (staleDuration) {
      StaleDurationDuration duration =>
        clock.now().difference(state.dataUpdatedAt!) >= duration,
      StaleDurationInfinity() => false,
      StaleDurationStatic() => false,
    };
  }

  void invalidate() {
    if (!state.isInvalidated) {
      _setState(state.copyWith(isInvalidated: true));
    }
  }

  void setOptions(QueryOptions<TData, TError> options) {
    _options = options;

    if (state.data == null && options.initialData != null) {
      final defaultState = QueryState<TData, TError>.fromSeed(
        options.initialData,
        options.initialDataUpdatedAt,
      );
      if (defaultState.data != null) {
        _setState(defaultState);
        _initialState = defaultState;
      }
    }
  }

  Future<TData> fetch({
    QueryOptions<TData, TError>? options,
    bool cancelRefetch = false,
  }) async {
    if (state.fetchStatus == FetchStatus.fetching && _retryer != null) {
      if (cancelRefetch && state.data != null) {
        cancel(silent: true);
      } else {
        return _retryer!.future;
      }
    }

    if (options != null) {
      setOptions(options);
    }

    _revertState = state;
    _abortController = AbortController();

    _setState(state
        .copyWith(
          fetchStatus: FetchStatus.fetching,
          failureCount: 0,
        )
        .copyWithNull(failureReason: true));

    final context = QueryFunctionContext(
      queryKey: queryKey,
      client: _client,
      signal: _abortController!.signal,
    );

    Duration? defaultRetry(int retryCount, TError error) {
      if (retryCount >= 3) return null;
      final delayMs = 1000 * (1 << retryCount);
      return Duration(milliseconds: delayMs > 30000 ? 30000 : delayMs);
    }

    _retryer = Retryer<TData, TError>(
      fn: () => _options.queryFn(context),
      retry: _options.retry ?? defaultRetry,
      signal: _abortController!.signal,
      onFail: (failureCount, error) {
        _setState(state.copyWith(
          failureCount: failureCount,
          failureReason: error,
        ));
      },
    );

    final currentRetryer = _retryer;

    try {
      final data = await _retryer!.start();

      _setState(QueryState<TData, TError>(
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
      ));

      return data;
    } on AbortedException catch (e) {
      if (e.revert && _revertState != null) {
        _setState(_revertState!.copyWith(fetchStatus: FetchStatus.idle));
      } else {
        _setState(state.copyWith(fetchStatus: FetchStatus.idle));
      }

      if (e.silent) {
        if (_retryer != currentRetryer) {
          return _retryer!.future;
        }
        if (state.data != null) {
          return state.data as TData;
        }
        return Completer<TData>().future;
      } else if (e.revert) {
        if (state.data == null) {
          rethrow;
        }
        return state.data as TData;
      } else {
        if (state.data != null) {
          return state.data as TData;
        }
        return Completer<TData>().future;
      }
    } catch (error) {
      if (error is TError) {
        final typedError = error as TError;
        _setState(state.copyWith(
          status: QueryStatus.error,
          fetchStatus: FetchStatus.idle,
          error: typedError,
          errorUpdatedAt: clock.now(),
          errorUpdateCount: state.errorUpdateCount + 1,
          failureCount: state.failureCount + 1,
          failureReason: typedError,
        ));
      }
      rethrow;
    } finally {
      _abortController = null;
      _revertState = null;
    }
  }

  Future<void> cancel({bool revert = true, bool silent = false}) {
    final retryer = _retryer;
    _abortController?.abort(revert: revert, silent: silent);
    return retryer?.future.then((_) {}).catchError((_) {}) ?? Future.value();
  }

  void addObserver(QueryObserver<TData, TError> observer) {
    if (!_observers.contains(observer)) {
      _observers.add(observer);
      cancelGc();
    }
  }

  void removeObserver(QueryObserver<TData, TError> observer) {
    _observers.remove(observer);

    if (_observers.isEmpty) {
      if (state.fetchStatus == FetchStatus.fetching &&
          _abortController != null) {
        if (_abortController!.wasConsumed) {
          cancel(revert: true);
        }
      }
      scheduleGc();
    }
  }

  void reset() {
    cancelGc();
    _setState(_initialState);
  }

  void _setState(QueryState<TData, TError> newState) {
    _state = newState;
    for (final observer in _observers) {
      observer.onQueryUpdate();
    }
  }

  @override
  GcDuration get gcDuration {
    return _observers
        .map((ob) => ob.options.gcDuration)
        .whereType<GcDuration>()
        .fold(
          // Defaults to 5 minutes
          _options.gcDuration ?? const GcDuration(minutes: 5),
          (longest, duration) => duration > longest ? duration : longest,
        );
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
extension QueryMatches on Query {
  /// Returns true if this query matches the given filters.
  ///
  /// - [exact]: when true, the query key must exactly equal the filter key;
  ///   when false (default), the query key only needs to start with the filter key
  /// - [predicate]: custom filter function that receives the query and returns
  ///   whether it should be included
  /// - [queryKey]: the key to match against
  /// - [type]: filters queries by their active state (all, active, inactive)
  bool matches({
    bool exact = false,
    bool Function(Query)? predicate,
    List<Object?>? queryKey,
    QueryTypeFilter type = QueryTypeFilter.all,
  }) {
    // Check type filter first
    if (type != QueryTypeFilter.all) {
      final active = isActive;
      if (type == QueryTypeFilter.active && !active) {
        return false;
      }
      if (type == QueryTypeFilter.inactive && active) {
        return false;
      }
    }

    // Check predicate
    if (predicate != null && !predicate(this)) {
      return false;
    }

    // Check query key if provided
    if (queryKey != null) {
      final key = QueryKey(this.queryKey);
      final filterKey = QueryKey(queryKey);
      if (exact) {
        // Exact match
        if (key != filterKey) {
          return false;
        }
      } else {
        // Prefix match
        if (!key.startsWith(filterKey)) {
          return false;
        }
      }
    }

    return true;
  }
}
