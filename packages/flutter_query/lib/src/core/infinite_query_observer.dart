part of 'query_observer.dart';

/// Callback type for infinite query result change listeners.
@internal
typedef InfiniteResultChangeListener<TData, TError, TPageParam> = void Function(
  InfiniteQueryResult<TData, TError, TPageParam> result,
);

/// Observer for infinite queries with pagination support.
///
/// Uses composition to wrap a standard [Query] with pagination logic.
/// Does NOT extend [QueryObserver] - instead wraps a Query with a custom
/// queryFn that handles page accumulation.
///
/// Matches TanStack Query v5's InfiniteQueryObserver behavior.
@internal
class InfiniteQueryObserver<TData, TError, TPageParam> {
  InfiniteQueryObserver(
    QueryClient client,
    InfiniteQueryObserverOptions<TData, TError, TPageParam> options,
  )   : _client = client,
        _options = options.withDefaults(client.defaultQueryOptions) {
    _query = _client.cache.build<InfiniteData<TData, TPageParam>, TError>(
      _createWrappedQueryOptions(),
    );
    _adapter = _QueryObserverAdapter<TData, TError, TPageParam>(
      _client,
      this,
      _createWrappedQueryObserverOptions(),
    );

    // Get initial optimistic result
    _result = _getResult(optimistic: true);

    // Trigger initial fetch if enabled and (no data or data is stale)
    if (_shouldFetchOnMount(_options, _query.state)) {
      _query.fetch().ignore();
    }
  }

  final QueryClient _client;
  InfiniteQueryObserverOptions<TData, TError, TPageParam> _options;
  late Query<InfiniteData<TData, TPageParam>, TError> _query;
  late InfiniteQueryResult<TData, TError, TPageParam> _result;
  FetchDirection? _fetchDirection;

  final Set<InfiniteResultChangeListener<TData, TError, TPageParam>>
      _listeners = {};

  late final _QueryObserverAdapter<TData, TError, TPageParam> _adapter;

  InfiniteQueryObserverOptions<TData, TError, TPageParam> get options =>
      _options;
  InfiniteQueryResult<TData, TError, TPageParam> get result => _result;

  /// Fetch the next page of data.
  ///
  /// Uses [nextPageParamBuilder] to determine the page parameter for the next page.
  Future<InfiniteQueryResult<TData, TError, TPageParam>> fetchNextPage({
    bool cancelRefetch = true,
    bool throwOnError = false,
  }) async {
    _fetchDirection = FetchDirection.forward;
    try {
      await _query.fetch(cancelRefetch: cancelRefetch);
    } catch (e) {
      if (throwOnError) rethrow;
    } finally {
      _fetchDirection = null;
    }
    return _getResult();
  }

  /// Fetch the previous page of data.
  ///
  /// Uses [prevPageParamBuilder] to determine the page parameter for the previous page.
  Future<InfiniteQueryResult<TData, TError, TPageParam>> fetchPreviousPage({
    bool cancelRefetch = true,
    bool throwOnError = false,
  }) async {
    _fetchDirection = FetchDirection.backward;
    try {
      await _query.fetch(cancelRefetch: cancelRefetch);
    } catch (e) {
      if (throwOnError) rethrow;
    } finally {
      _fetchDirection = null;
    }
    return _getResult();
  }

  /// Manually refetch all pages.
  Future<InfiniteQueryResult<TData, TError, TPageParam>> refetch({
    bool cancelRefetch = true,
    bool throwOnError = false,
  }) async {
    _fetchDirection = null;
    try {
      await _query.fetch(cancelRefetch: cancelRefetch);
    } catch (e) {
      if (throwOnError) rethrow;
    } finally {
      _fetchDirection = null;
    }
    return _getResult();
  }

  /// Update options. Called during re-render.
  void updateOptions(
      InfiniteQueryObserverOptions<TData, TError, TPageParam> options) {
    final oldOptions = _options;
    final newOptions = options.withDefaults(_client.defaultQueryOptions);
    _options = newOptions;

    // Compare options to detect actual changes
    final didKeyChange = newOptions.queryKey != oldOptions.queryKey;
    final didGcDurationChange = newOptions.gcDuration != oldOptions.gcDuration;
    final didEnabledChange = newOptions.enabled != oldOptions.enabled;
    final didPlaceholderChange =
        newOptions.placeholder != oldOptions.placeholder;
    final didRefetchIntervalChange =
        newOptions.refetchInterval != oldOptions.refetchInterval;
    final didRefetchOnMountChange =
        newOptions.refetchOnMount != oldOptions.refetchOnMount;
    final didRefetchOnResumeChange =
        newOptions.refetchOnResume != oldOptions.refetchOnResume;
    final didRetryChange = !identical(newOptions.retry, oldOptions.retry);
    final didRetryOnMountChange =
        newOptions.retryOnMount != oldOptions.retryOnMount;
    final didStaleDurationChange =
        newOptions.staleDuration != oldOptions.staleDuration;

    // If nothing changed, return early
    if (!didKeyChange &&
        !didEnabledChange &&
        !didStaleDurationChange &&
        !didGcDurationChange &&
        !didPlaceholderChange &&
        !didRefetchIntervalChange &&
        !didRefetchOnMountChange &&
        !didRefetchOnResumeChange &&
        !didRetryChange &&
        !didRetryOnMountChange) {
      return;
    }

    if (didKeyChange) {
      final oldQuery = _query;

      // Create new wrapped options for new key
      final wrappedOptions = _createWrappedQueryOptions();
      _query = _client.cache.build<InfiniteData<TData, TPageParam>, TError>(
        wrappedOptions,
      );
      _query.withOptions(wrappedOptions);
      _query.addObserver(_adapter);

      // Reset initial counters for the new query
      _adapter._initialDataUpdateCount = _query.state.dataUpdateCount;
      _adapter._initialErrorUpdateCount = _query.state.errorUpdateCount;

      // Get optimistic result
      final result = _getResult(optimistic: true);
      _setResult(result);

      // Trigger initial fetch if enabled and (no data or data is stale)
      if (_shouldFetchOnMount(newOptions, _query.state)) {
        _query.fetch().ignore();
      }

      // Remove from old query
      oldQuery.removeObserver(_adapter);

      return;
    }

    if (didEnabledChange) {
      final result = _getResult(optimistic: true);
      _setResult(result);

      if (_shouldFetchOnMount(newOptions, _query.state)) {
        _query.fetch().ignore();
      }
    }

    if (didPlaceholderChange) {
      final result = _getResult(optimistic: true);
      _setResult(result);
    }

    if (didRefetchOnMountChange) {
      final result = _getResult(optimistic: true);
      _setResult(result);

      if (_shouldFetchOnMount(newOptions, _query.state)) {
        _query.fetch().ignore();
      }
    }

    if (didRefetchOnResumeChange) {
      final result = _getResult(optimistic: true);
      _setResult(result);
    }

    if (didStaleDurationChange) {
      final result = _getResult(optimistic: true);
      _setResult(result);

      if (_shouldFetchOnMount(newOptions, _query.state)) {
        _query.fetch().ignore();
      }
    }

    if (didRetryOnMountChange) {
      final result = _getResult(optimistic: true);
      _setResult(result);

      if (_shouldFetchOnMount(newOptions, _query.state)) {
        _query.fetch().ignore();
      }
    }
  }

  void Function() subscribe(
    InfiniteResultChangeListener<TData, TError, TPageParam> listener,
  ) {
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  void onResume() {
    if (_shouldFetchOnResume(options, _query.state)) {
      _query.fetch().ignore();
    }
  }

  void dispose() {
    _listeners.clear();
    _adapter.dispose();
  }

  void _onQueryUpdate() {
    final result = _getResult();
    _setResult(result);
  }

  // ============================================================================
  // Private Helpers
  // ============================================================================

  QueryOptions<InfiniteData<TData, TPageParam>, TError>
      _createWrappedQueryOptions() {
    return QueryOptions<InfiniteData<TData, TPageParam>, TError>(
      _options.queryKey.parts,
      _createWrappedQueryFn(),
      gcDuration: _options.gcDuration,
      meta: _options.meta,
      retry: _options.retry,
      seed: _options.seed,
      seedUpdatedAt: _options.seedUpdatedAt,
    );
  }

  QueryObserverOptions<InfiniteData<TData, TPageParam>, TError>
      _createWrappedQueryObserverOptions() {
    return QueryObserverOptions<InfiniteData<TData, TPageParam>, TError>(
      _options.queryKey.parts,
      _createWrappedQueryFn(),
      enabled: _options.enabled,
      gcDuration: _options.gcDuration,
      meta: _options.meta,
      placeholder: _options.placeholder,
      refetchInterval: _options.refetchInterval,
      refetchOnMount: _options.refetchOnMount,
      refetchOnResume: _options.refetchOnResume,
      retry: _options.retry,
      retryOnMount: _options.retryOnMount,
      seed: _options.seed,
      seedUpdatedAt: _options.seedUpdatedAt,
      staleDuration: _options.staleDuration,
    );
  }

  Future<InfiniteData<TData, TPageParam>> Function(QueryFunctionContext)
      _createWrappedQueryFn() {
    return (context) async {
      final data = _query.state.data ?? InfiniteData.empty();

      return switch (_fetchDirection) {
        final dir? => _fetchMore(context, data, dir),
        null => _fetchAll(context, data),
      };
    };
  }

  Future<InfiniteData<TData, TPageParam>> _fetchMore(
    QueryFunctionContext context,
    InfiniteData<TData, TPageParam> data,
    FetchDirection direction,
  ) async {
    TPageParam? param = switch (direction) {
      FetchDirection.forward => _options.buildNextPageParam(data),
      FetchDirection.backward => _options.buildPrevPageParam(data),
    };

    // No more pages in this direction
    if (param == null) {
      return data;
    }

    final infiniteContext = InfiniteQueryFunctionContext<TPageParam>(
      queryKey: context.queryKey,
      client: context.client,
      signal: context.signal,
      meta: context.meta,
      pageParam: param,
      direction: direction,
    );

    final page = await _options.queryFn(infiniteContext);

    return switch (direction) {
      FetchDirection.forward => InfiniteData(
          data.pages.appendBounded(page, _options.maxPages),
          data.pageParams.appendBounded(param, _options.maxPages),
        ),
      FetchDirection.backward => InfiniteData(
          data.pages.prependBounded(page, _options.maxPages),
          data.pageParams.prependBounded(param, _options.maxPages),
        ),
    };
  }

  Future<InfiniteData<TData, TPageParam>> _fetchAll(
    QueryFunctionContext context,
    InfiniteData<TData, TPageParam> data,
  ) async {
    final pagesToFetch = max(data.pages.length, 1);

    var result = InfiniteData<TData, TPageParam>.empty();

    for (var i = 0; i < pagesToFetch; i++) {
      TPageParam param;

      if (i == 0) {
        param = data.pageParams.firstOrNull ?? _options.initialPageParam;
      } else {
        final nextParam = _options.buildNextPageParam(result);
        if (nextParam == null) break;
        param = nextParam;
      }

      final infiniteContext = InfiniteQueryFunctionContext<TPageParam>(
        queryKey: context.queryKey,
        client: context.client,
        signal: context.signal,
        meta: context.meta,
        pageParam: param,
        direction: FetchDirection.forward,
      );

      final page = await _options.queryFn(infiniteContext);

      result = InfiniteData(
        result.pages.appendBounded(page, _options.maxPages),
        result.pageParams.appendBounded(param, _options.maxPages),
      );
    }

    return result;
  }

  void _setResult(InfiniteQueryResult<TData, TError, TPageParam> newResult) {
    if (newResult != _result) {
      _result = newResult;
      for (final listener in _listeners) {
        listener(_result);
      }
    }
  }

  InfiniteQueryResult<TData, TError, TPageParam> _getResult({
    bool optimistic = false,
  }) {
    final state = _query.state;

    var status = state.status;
    var fetchStatus = state.fetchStatus;
    var data = state.data;
    var isPlaceholderData = false;

    if (optimistic) {
      fetchStatus = _shouldFetchOnMount(options, state)
          ? FetchStatus.fetching
          : state.fetchStatus;
    }

    // Use placeholder if needed
    if (options.placeholder != null &&
        data == null &&
        status == QueryStatus.pending) {
      status = QueryStatus.success;
      data = options.placeholder;
      isPlaceholderData = true;
    }

    final staleDuration = options.staleDuration ?? const StaleDuration();

    final isEnabled = options.enabled ?? true;
    final isStale = isEnabled && _query.shouldFetch(staleDuration);

    // Compute infinite-specific fields
    final isFetching = fetchStatus == FetchStatus.fetching;
    final isFetchingNextPage =
        isFetching && _fetchDirection == FetchDirection.forward;
    final isFetchingPreviousPage =
        isFetching && _fetchDirection == FetchDirection.backward;
    final isFetchNextPageError = state.status == QueryStatus.error &&
        _fetchDirection == FetchDirection.forward;
    final isFetchPreviousPageError = state.status == QueryStatus.error &&
        _fetchDirection == FetchDirection.backward;

    final hasNextPage = _hasNextPage(data);
    final hasPreviousPage = _hasPreviousPage(data);

    return InfiniteQueryResult<TData, TError, TPageParam>(
      status: status,
      fetchStatus: fetchStatus,
      data: data,
      dataUpdatedAt: state.dataUpdatedAt,
      dataUpdateCount: state.dataUpdateCount,
      error: state.error,
      errorUpdatedAt: state.errorUpdatedAt,
      errorUpdateCount: state.errorUpdateCount,
      failureCount: state.failureCount,
      failureReason: state.failureReason,
      isEnabled: isEnabled,
      isStale: isStale,
      isFetchedAfterMount:
          state.dataUpdateCount > _adapter._initialDataUpdateCount ||
              state.errorUpdateCount > _adapter._initialErrorUpdateCount,
      isPlaceholderData: isPlaceholderData,
      refetch: refetch,
      fetchNextPage: fetchNextPage,
      fetchPreviousPage: fetchPreviousPage,
      hasNextPage: hasNextPage,
      hasPreviousPage: hasPreviousPage,
      isFetchingNextPage: isFetchingNextPage,
      isFetchingPreviousPage: isFetchingPreviousPage,
      isFetchNextPageError: isFetchNextPageError,
      isFetchPreviousPageError: isFetchPreviousPageError,
    );
  }

  bool _hasNextPage(InfiniteData<TData, TPageParam>? data) {
    if (data == null || data.pages.isEmpty) return false;
    return _options.buildNextPageParam(data) != null;
  }

  bool _hasPreviousPage(InfiniteData<TData, TPageParam>? data) {
    if (data == null || data.pages.isEmpty) return false;
    return _options.buildPrevPageParam(data) != null;
  }

  bool _shouldFetchOnMount(
    InfiniteQueryObserverOptions<TData, TError, TPageParam> options,
    QueryState<InfiniteData<TData, TPageParam>, TError> state,
  ) {
    final enabled = options.enabled ?? true;
    final retryOnMount = options.retryOnMount ?? true;
    final refetchOnMount = options.refetchOnMount ?? RefetchOnMount.stale;

    if (!enabled) return false;

    if (state.status == QueryStatus.error && !retryOnMount) {
      return false;
    }

    if (state.data == null) return true;

    final staleDuration = options.staleDuration ?? const StaleDuration();

    if (staleDuration is StaleDurationStatic) return false;

    if (refetchOnMount == RefetchOnMount.always) return true;
    if (refetchOnMount == RefetchOnMount.never) return false;

    final age = clock.now().difference(state.dataUpdatedAt!);

    return switch (staleDuration) {
      StaleDurationValue duration => age >= duration,
      StaleDurationInfinity() => false,
      StaleDurationStatic() => false,
    };
  }

  bool _shouldFetchOnResume(
    InfiniteQueryObserverOptions<TData, TError, TPageParam> options,
    QueryState<InfiniteData<TData, TPageParam>, TError> state,
  ) {
    final enabled = options.enabled ?? true;
    final refetchOnResume = options.refetchOnResume ?? RefetchOnResume.stale;

    if (!enabled) return false;

    final staleDuration = options.staleDuration ?? const StaleDuration();

    if (staleDuration is StaleDurationStatic) return false;

    if (refetchOnResume == RefetchOnResume.never) return false;
    if (refetchOnResume == RefetchOnResume.always) return true;

    if (state.data == null || state.dataUpdatedAt == null) return true;

    final age = clock.now().difference(state.dataUpdatedAt!);

    return switch (staleDuration) {
      StaleDurationValue duration => age >= duration,
      StaleDurationInfinity() => false,
      StaleDurationStatic() => false,
    };
  }
}

/// Adapter to bridge Query's observer interface with InfiniteQueryObserver.
///
/// This extends QueryObserver but bypasses its normal initialization by
/// passing disabled options to the superclass constructor, then provides
/// custom options via the getter.
class _QueryObserverAdapter<TData, TError, TPageParam>
    extends QueryObserver<InfiniteData<TData, TPageParam>, TError> {
  _QueryObserverAdapter(
    QueryClient client,
    this._delegate,
    QueryObserverOptions<InfiniteData<TData, TPageParam>, TError> options,
  ) : super(
          client,
          // Pass options with enabled=false to prevent QueryObserver from
          // triggering any fetches in its constructor
          QueryObserverOptions<InfiniteData<TData, TPageParam>, TError>(
            options.queryKey.parts,
            options.queryFn,
            enabled: false, // Prevent any automatic behavior
            gcDuration: options.gcDuration,
            meta: options.meta,
            placeholder: options.placeholder,
            refetchInterval: options.refetchInterval,
            refetchOnMount: options.refetchOnMount,
            refetchOnResume: options.refetchOnResume,
            retry: options.retry,
            retryOnMount: options.retryOnMount,
            seed: options.seed,
            seedUpdatedAt: options.seedUpdatedAt,
            staleDuration: options.staleDuration,
          ),
        );

  final InfiniteQueryObserver<TData, TError, TPageParam> _delegate;

  /// Override to forward notifications to InfiniteQueryObserver
  @override
  void onNotified(QueryState<InfiniteData<TData, TPageParam>, TError> state) {
    _delegate._onQueryUpdate();
  }

  /// Provides options that Query uses for isActive/isStatic checks
  @override
  QueryObserverOptions<InfiniteData<TData, TPageParam>, TError> get options {
    return _delegate._createWrappedQueryObserverOptions();
  }
}

extension<T> on List<T> {
  /// Append item to end, removing first item if exceeding [maxLength].
  List<T> appendBounded(T item, [int? maxLength]) {
    final newItems = [...this, item];
    if (maxLength != null && newItems.length > maxLength) {
      return newItems.sublist(1);
    }
    return newItems;
  }

  /// Prepend item to start, removing last item if exceeding [maxLength].
  List<T> prependBounded(T item, [int? maxLength]) {
    final newItems = [item, ...this];
    if (maxLength != null && newItems.length > maxLength) {
      return newItems.sublist(0, newItems.length - 1);
    }
    return newItems;
  }
}
