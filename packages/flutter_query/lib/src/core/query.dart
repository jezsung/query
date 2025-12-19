import 'package:clock/clock.dart';
import 'package:equatable/equatable.dart';

import 'options/gc_duration.dart';
import 'options/stale_duration.dart';
import 'query_cache.dart';
import 'query_client.dart';
import 'query_context.dart';
import 'query_observer.dart';
import 'query_options.dart';
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

  // Track current fetch future to return same future for concurrent calls
  Future<TData>? _currentFetch;

  /// Checks if the query data is stale based on the given stale duration.
  ///
  /// If [staleDurationResolver] is provided, it takes precedence over [staleDuration].
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
  bool isStaleByTime(
    StaleDuration? staleDuration, [
    StaleDurationResolver<TData, TError>? staleDurationResolver,
  ]) {
    // No data is always stale
    if (state.data == null) {
      return true;
    }

    // Resolver takes precedence over static value
    final resolved = staleDurationResolver != null
        ? staleDurationResolver(this)
        : (staleDuration ?? const StaleDuration());

    // Static queries are never stale
    if (resolved is StaleDurationStatic) {
      return false;
    }

    // Invalidated queries are always stale (unless static, checked above)
    if (state.isInvalidated) {
      return true;
    }

    return switch (resolved) {
      StaleDurationDuration duration =>
        clock.now().difference(state.dataUpdatedAt!) >= duration,
      StaleDurationInfinity() => false,
      StaleDurationStatic() => false,
    };
  }

  Future<TData> fetch() {
    // If already fetching, return existing future (TanStack behavior)
    if (state.fetchStatus == FetchStatus.fetching && _currentFetch != null) {
      return _currentFetch!;
    }

    _currentFetch = _doFetch();
    return _currentFetch!;
  }

  Future<TData> _doFetch() async {
    _setState(state
        .copyWith(
          fetchStatus: FetchStatus.fetching,
          failureCount: 0,
        )
        .copyWithNull(faliureReason: true));

    final context = QueryContext(queryKey: queryKey, client: _client);

    // Default retry: 3 retries with exponential backoff
    Duration? defaultRetry(int retryCount, TError error) {
      if (retryCount >= 3) return null;
      // Exponential backoff: 1s, 2s, 4s (capped at 30s)
      final delayMs = 1000 * (1 << retryCount);
      return Duration(milliseconds: delayMs > 30000 ? 30000 : delayMs);
    }

    final retryer = Retryer<TData, TError>(
      RetryerConfig(
        fn: () => queryFn(context),
        retry: _options.retry ?? defaultRetry,
        onFail: (failureCount, error) {
          // Update state on each failure for reactivity
          _setState(state.copyWith(
            failureCount: failureCount,
            failureReason: error,
          ));
        },
      ),
    );

    try {
      final data = await retryer.start();

      _setState(QueryState<TData, TError>(
        status: QueryStatus.success,
        fetchStatus: FetchStatus.idle,
        data: data,
        dataUpdatedAt: clock.now(),
        error: null,
        errorUpdatedAt: state.errorUpdatedAt,
        errorUpdateCount: state.errorUpdateCount,
        failureCount: 0,
        failureReason: null,
        isInvalidated: false, // Reset on successful fetch
      ));

      return data;
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
      _currentFetch = null;
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
  void removeObserver(QueryObserver observer) {
    if (_observers.contains(observer)) {
      _observers.remove(observer);

      // Schedule GC only if there are no more observers
      if (_observers.isEmpty) {
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

  /// Returns true if this query has at least one enabled observer.
  ///
  /// An active query is one that has observers with `enabled: true`.
  /// This is used by [refetchQueries] to determine which queries to refetch.
  ///
  /// Aligned with TanStack Query's `Query.isActive` method.
  bool isActive() {
    return _observers.any((observer) => observer.options.enabled ?? true);
  }

  /// Returns true if this query is disabled.
  ///
  /// A query is disabled if:
  /// - It has observers but none are enabled, OR
  /// - It has no observers and has never fetched data
  ///
  /// Aligned with TanStack Query's `Query.isDisabled` method.
  bool isDisabled() {
    if (_observers.isNotEmpty) {
      return !isActive();
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
  bool isStatic() {
    if (_observers.isEmpty) return false;
    return _observers.any((observer) {
      final opts = observer.options;
      final resolved = opts.staleDurationResolver != null
          ? opts.staleDurationResolver!(this)
          : opts.staleDuration;
      return resolved is StaleDurationStatic;
    });
  }
}

class QueryState<TData, TError> with EquatableMixin {
  const QueryState({
    this.status = QueryStatus.pending,
    this.fetchStatus = FetchStatus.idle,
    this.data,
    this.dataUpdatedAt,
    this.error,
    this.errorUpdatedAt,
    this.errorUpdateCount = 0,
    this.failureCount = 0,
    this.failureReason,
    this.isInvalidated = false,
  });

  /// Creates a QueryState from QueryOptions, handling initialData.
  ///
  /// This matches TanStack Query's getDefaultState function behavior.
  factory QueryState.fromOptions(QueryOptions<TData, TError> options) {
    if (options.initialData != null) {
      return QueryState<TData, TError>(
        status: QueryStatus.success,
        fetchStatus: FetchStatus.idle,
        data: options.initialData,
        dataUpdatedAt: options.initialDataUpdatedAt ?? clock.now(),
        error: null,
        errorUpdatedAt: null,
        errorUpdateCount: 0,
        failureCount: 0,
        failureReason: null,
      );
    }

    return QueryState<TData, TError>();
  }

  final QueryStatus status;
  final FetchStatus fetchStatus;
  final TData? data;
  final DateTime? dataUpdatedAt;
  final TError? error;
  final DateTime? errorUpdatedAt;
  final int errorUpdateCount;
  final int failureCount;
  final TError? failureReason;
  final bool isInvalidated;

  QueryState<TData, TError> copyWith({
    QueryStatus? status,
    FetchStatus? fetchStatus,
    TData? data,
    DateTime? dataUpdatedAt,
    TError? error,
    DateTime? errorUpdatedAt,
    int? errorUpdateCount,
    int? failureCount,
    TError? failureReason,
    bool? isInvalidated,
  }) {
    return QueryState<TData, TError>(
      status: status ?? this.status,
      fetchStatus: fetchStatus ?? this.fetchStatus,
      data: data ?? this.data,
      dataUpdatedAt: dataUpdatedAt ?? this.dataUpdatedAt,
      error: error ?? this.error,
      errorUpdatedAt: errorUpdatedAt ?? this.errorUpdatedAt,
      errorUpdateCount: errorUpdateCount ?? this.errorUpdateCount,
      failureCount: failureCount ?? this.failureCount,
      failureReason: failureReason ?? this.failureReason,
      isInvalidated: isInvalidated ?? this.isInvalidated,
    );
  }

  QueryState<TData, TError> copyWithNull({
    bool faliureReason = false,
  }) {
    return QueryState<TData, TError>(
      status: this.status,
      fetchStatus: this.fetchStatus,
      data: this.data,
      dataUpdatedAt: this.dataUpdatedAt,
      error: this.error,
      errorUpdatedAt: this.errorUpdatedAt,
      errorUpdateCount: this.errorUpdateCount,
      failureCount: this.failureCount,
      failureReason: faliureReason ? null : this.failureReason,
      isInvalidated: this.isInvalidated,
    );
  }

  @override
  List<Object?> get props => [
        status,
        fetchStatus,
        data,
        dataUpdatedAt,
        error,
        errorUpdatedAt,
        errorUpdateCount,
        failureCount,
        failureReason,
        isInvalidated,
      ];
}
