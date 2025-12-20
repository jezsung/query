import 'dart:async';

import 'package:clock/clock.dart';

import 'abort_signal.dart';
import 'options/gc_duration.dart';
import 'options/stale_duration.dart';
import 'query_cache.dart';
import 'query_client.dart';
import 'query_context.dart';
import 'query_observer.dart';
import 'query_options.dart';
import 'query_state.dart';
import 'removable.dart';
import 'retryer.dart';

enum QueryStatus { pending, error, success }

enum FetchStatus { fetching, paused, idle }

class Query<TData, TError> with Removable {
  Query(
    QueryClient client,
    QueryCache cache,
    QueryOptions<TData, TError> options,
  )   : _client = client,
        _cache = cache,
        _options = options,
        _initialState = QueryState.fromOptions(options) {
    _state = _initialState;
    setOptions(options);
    scheduleGc();
  }

  final QueryClient _client;
  final QueryCache _cache;
  QueryOptions<TData, TError> _options;

  List<Object?> get queryKey => _options.queryKey;
  Future<TData> Function(QueryContext) get queryFn => _options.queryFn;

  late QueryState<TData, TError> _state;
  QueryState<TData, TError> get state => _state;

  // Store the initial state for reset functionality
  // This can be updated via setOptions when initialData is set on a query without data
  QueryState<TData, TError> _initialState;

  // Track observers explicitly to match TanStack Query's pattern
  final List<QueryObserver> _observers = [];

  bool get hasObservers => _observers.isNotEmpty;

  // Current retryer stored at class level (like TanStack's #retryer)
  Retryer<TData, TError>? _retryer;

  // Abort controller for current fetch operation
  AbortController? _abortController;

  // State before fetch started, used for reverting on cancel
  QueryState<TData, TError>? _revertState;

  /// Returns true if this query has at least one enabled observer.
  ///
  /// An active query is one that has observers with `enabled: true`.
  /// This is used by [refetchQueries] to determine which queries to refetch.
  ///
  /// Aligned with TanStack Query's `Query.isActive` method.
  bool get isActive {
    return _observers.any((observer) => observer.options.enabled ?? true);
  }

  /// Returns true if this query is disabled.
  ///
  /// A query is disabled if:
  /// - It has observers but none are enabled, OR
  /// - It has no observers and has never fetched data
  ///
  /// Aligned with TanStack Query's `Query.isDisabled` method.
  bool get isDisabled {
    if (_observers.isNotEmpty) {
      return !isActive;
    }
    // No observers: disabled if never fetched
    return state.status == QueryStatus.pending &&
        state.dataUpdatedAt == null &&
        state.errorUpdatedAt == null;
  }

  /// Returns true if any observer has staleTime set to static.
  ///
  /// Static queries should not be refetched automatically.
  ///
  /// Aligned with TanStack Query's `Query.isStatic` method.
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

  /// Checks if the query data is stale based on the given stale duration.
  ///
  /// The [staleDuration] should be pre-resolved by the caller (e.g., QueryObserver).
  ///
  /// Returns true if:
  /// - No data exists
  /// - Query is invalidated (unless static)
  /// - Data age exceeds or equals the stale duration
  ///
  /// Returns false if:
  /// - stale duration is infinity or static
  /// - Data is still fresh
  ///
  /// Aligned with TanStack Query's `isStaleByTime` method.
  bool isStaleByTime(StaleDuration staleDuration) {
    // No data is always stale
    if (state.data == null) {
      return true;
    }

    // Static queries are never stale
    if (staleDuration is StaleDurationStatic) {
      return false;
    }

    // Invalidated queries are always stale (unless static, checked above)
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

  /// Fetches data for this query.
  ///
  /// If [options] is provided, updates the query's options before fetching.
  /// This allows `fetchQuery` to pass new options that override existing ones.
  ///
  /// If a fetch is already in progress, returns the existing future unless
  /// [cancelRefetch] is true and data exists, in which case the current
  /// fetch is cancelled and a new one starts.
  ///
  /// Aligned with TanStack Query's `Query.fetch` method.
  Future<TData> fetch({
    QueryOptions<TData, TError>? options,
    bool cancelRefetch = false,
  }) async {
    // Handle concurrent fetch
    if (state.fetchStatus == FetchStatus.fetching && _retryer != null) {
      if (cancelRefetch && state.data != null) {
        // Cancel old fetch silently, then start new one
        cancel(silent: true);
        // Fall through to create new retryer
      } else {
        // Return existing future
        return _retryer!.future;
      }
    }

    // Update options if passed (like TanStack's setOptions call in fetch)
    if (options != null) {
      setOptions(options);
    }

    // Store state for potential revert on cancel
    _revertState = state;

    // Create abort controller for this fetch
    _abortController = AbortController();

    _setState(state
        .copyWith(
          fetchStatus: FetchStatus.fetching,
          failureCount: 0,
        )
        .copyWithNull(faliureReason: true));

    final context = QueryContext(
      queryKey: queryKey,
      client: _client,
      signal: _abortController!.signal,
    );

    // Default retry: 3 retries with exponential backoff
    Duration? defaultRetry(int retryCount, TError error) {
      if (retryCount >= 3) return null;
      // Exponential backoff: 1s, 2s, 4s (capped at 30s)
      final delayMs = 1000 * (1 << retryCount);
      return Duration(milliseconds: delayMs > 30000 ? 30000 : delayMs);
    }

    // Create and store retryer BEFORE await (like TanStack)
    // This is critical for silent cancellation to work correctly
    _retryer = Retryer<TData, TError>(
      fn: () => queryFn(context),
      retry: _options.retry ?? defaultRetry,
      signal: _abortController!.signal,
      onFail: (failureCount, error) {
        // Update state on each failure for reactivity
        _setState(state.copyWith(
          failureCount: failureCount,
          failureReason: error,
        ));
      },
    );

    // Store current retryer to detect if a new one is created during cancellation
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
        isInvalidated: false, // Reset on successful fetch
      ));

      return data;
    } on AbortedException catch (e) {
      // Handle abort - revert state if requested
      if (e.revert && _revertState != null) {
        _setState(_revertState!.copyWith(fetchStatus: FetchStatus.idle));
      } else {
        _setState(state.copyWith(fetchStatus: FetchStatus.idle));
      }

      if (e.silent) {
        // Silent cancellation - check if a new fetch started (retryer was replaced)
        if (_retryer != currentRetryer) {
          // New fetch started - return its future (piggybacking pattern)
          return _retryer!.future;
        }
        // No new fetch - return existing data if available
        if (state.data != null) {
          return state.data as TData;
        }
        // No data and no new fetch - return a never-completing future
        // This prevents throwing while caller waits for next fetch
        return Completer<TData>().future;
      } else if (e.revert) {
        // Revert: only throw if there was no prior data
        if (state.data == null) {
          rethrow;
        }
        return state.data as TData;
      } else {
        // revert: false - don't throw, return existing data or pending future
        if (state.data != null) {
          return state.data as TData;
        }
        // No data - return a never-completing future (caller can start new fetch)
        return Completer<TData>().future;
      }
    } catch (error) {
      // Cast error to TError - should already be TError from retryer
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
      // Note: Don't null _retryer - it may be the new one from a cancelRefetch
    }
  }

  /// Adds an observer to this query.
  ///
  /// Matches TanStack Query's pattern: clear GC timeout when an observer subscribes.
  void addObserver(QueryObserver observer) {
    if (!_observers.contains(observer)) {
      _observers.add(observer);

      // Stop the query from being garbage collected
      cancelGc();
    }
  }

  /// Removes an observer from this query.
  ///
  /// Matches TanStack Query's pattern: schedule GC only when the last observer is removed.
  /// If this is the last observer and a fetch is in progress with a consumed signal,
  /// the fetch will be cancelled.
  void removeObserver(QueryObserver observer) {
    if (_observers.contains(observer)) {
      _observers.remove(observer);

      // When no observers remain
      if (_observers.isEmpty) {
        // If fetching and signal was consumed, cancel the fetch
        if (state.fetchStatus == FetchStatus.fetching &&
            _abortController != null) {
          if (_abortController!.wasConsumed) {
            // Signal was used by queryFn, so abort the operation
            cancel(revert: true);
          }
          // If signal wasn't consumed, let the fetch complete
          // but the result won't be used (no observers)
        }

        scheduleGc();
      }
    }
  }

  /// Attempts to remove the query if it has no observers and is idle.
  ///
  /// This is called by the Removable mixin when the GC timer expires.
  /// Matches TanStack Query's behavior: remove when no observers and fetchStatus is idle.
  @override
  void tryRemove() {
    if (!hasObservers && state.fetchStatus == FetchStatus.idle) {
      _cache.remove(this);
    }
  }

  /// Resets the query to its initial state.
  ///
  /// This restores the query to the state it had when it was first created,
  /// including any initialData that was provided.
  void reset() {
    cancelGc();
    _setState(_initialState);
  }

  /// Cancels any in-progress fetch for this query.
  ///
  /// Returns a Future that completes when the fetch has been cancelled.
  /// If no fetch is in progress, returns an immediately completed Future.
  ///
  /// When [revert] is true (default), the query state will be restored to
  /// what it was before the fetch started. When false, the current state
  /// is preserved with fetchStatus set to idle.
  ///
  /// When [silent] is true, the cancellation will not trigger error callbacks
  /// or update the query's error state. The query will silently return to its
  /// previous state.
  ///
  /// Aligned with TanStack Query's Query.cancel method.
  Future<void> cancel({bool revert = true, bool silent = false}) {
    final retryer = _retryer;

    _abortController?.abort(revert: revert, silent: silent);

    // Wait for the current fetch to complete (success or error)
    // and swallow any errors
    return retryer?.future.then((_) {}).catchError((_) {}) ?? Future.value();
  }

  /// Sets the query options and updates the state if needed.
  ///
  /// This matches TanStack Query's setOptions behavior where initialData
  /// can be set on a query that exists without data.
  void setOptions(QueryOptions<TData, TError> options) {
    _options = options;

    // Update gcDuration if changed (use built-in default if null)
    final gcDuration = options.gcDuration ?? const GcDuration(minutes: 5);
    updateGcDuration(gcDuration);

    // If query has no data and options provide initialData, update state
    if (state.data == null && options.initialData != null) {
      final defaultState = QueryState<TData, TError>.fromOptions(options);
      if (defaultState.data != null) {
        _setState(defaultState);
        // Update initial state so reset() will restore to this state
        _initialState = defaultState;
      }
    }
  }

  void _setState(QueryState<TData, TError> newState) {
    _state = newState;

    // Notify all observers directly via method calls
    for (final observer in _observers) {
      observer.onQueryUpdate();
    }
  }

  /// Invalidates this query, marking it as stale.
  ///
  /// When a query is invalidated:
  /// - [isStaleByTime] will return true regardless of staleDuration
  /// - Active observers will be notified of the state change
  ///
  /// Aligned with TanStack Query's `Query.invalidate` method.
  void invalidate() {
    if (!state.isInvalidated) {
      _setState(state.copyWith(isInvalidated: true));
    }
  }
}
