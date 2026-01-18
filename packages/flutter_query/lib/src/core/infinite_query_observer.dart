part of 'query_observer.dart';

/// Data structure for infinite queries containing pages and their params.
class InfiniteData<TData, TPageParam> {
  const InfiniteData(
    this.pages,
    this.pageParams,
  );

  const InfiniteData.empty()
      : pages = const [],
        pageParams = const [];

  /// The list of pages fetched so far.
  /// Each page corresponds to a pageParam at the same index.
  final List<TData> pages;

  /// The list of page parameters used to fetch each page.
  /// pageParams[i] was used to fetch pages[i].
  final List<TPageParam> pageParams;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InfiniteData<TData, TPageParam> &&
          deepEq.equals(pages, other.pages) &&
          deepEq.equals(pageParams, other.pageParams);

  @override
  int get hashCode => Object.hash(
        deepEq.hash(pages),
        deepEq.hash(pageParams),
      );

  @override
  String toString() => 'InfiniteData(pages: $pages, pageParams: $pageParams)';
}

/// Direction of page fetch for infinite queries.
enum FetchDirection {
  /// Fetching the next page (appending to the end).
  forward,

  /// Fetching the previous page (prepending to the start).
  backward,
}

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
  ) : _client = client {
    _options = options.withDefaults(client.defaultQueryOptions);
    _inner = QueryObserver<InfiniteData<TData, TPageParam>, TError>(
      _client,
      queryObserverOptions,
    );
  }

  final QueryClient _client;
  late InfiniteQueryObserverOptions<TData, TError, TPageParam> _options;
  late final QueryObserver<InfiniteData<TData, TPageParam>, TError> _inner;
  FetchDirection? _fetchDirection;

  InfiniteQueryResult<TData, TError, TPageParam> get result {
    final queryResult = _inner._result;
    final data = queryResult.data;

    final hasNextPage = data != null &&
        data.pages.isNotEmpty &&
        _options.buildNextPageParam(data) != null;
    final hasPrevPage = data != null &&
        data.pages.isNotEmpty &&
        _options.buildPrevPageParam(data) != null;

    return InfiniteQueryResult<TData, TError, TPageParam>(
      status: queryResult.status,
      fetchStatus: queryResult.fetchStatus,
      data: queryResult.data,
      dataUpdatedAt: queryResult.dataUpdatedAt,
      dataUpdateCount: queryResult.dataUpdateCount,
      error: queryResult.error,
      errorUpdatedAt: queryResult.errorUpdatedAt,
      errorUpdateCount: queryResult.errorUpdateCount,
      failureCount: queryResult.failureCount,
      failureReason: queryResult.failureReason,
      isEnabled: queryResult.isEnabled,
      isStale: queryResult.isStale,
      isFetchedAfterMount: queryResult.isFetchedAfterMount,
      isPlaceholderData: queryResult.isPlaceholderData,
      refetch: refetch,
      fetchNextPage: fetchNextPage,
      fetchPreviousPage: fetchPreviousPage,
      hasNextPage: hasNextPage,
      hasPreviousPage: hasPrevPage,
      isFetchingNextPage:
          queryResult.isFetching && _fetchDirection == FetchDirection.forward,
      isFetchingPreviousPage:
          queryResult.isFetching && _fetchDirection == FetchDirection.backward,
      isFetchNextPageError: queryResult.status == QueryStatus.error &&
          _fetchDirection == FetchDirection.forward,
      isFetchPreviousPageError: queryResult.status == QueryStatus.error &&
          _fetchDirection == FetchDirection.forward,
    );
  }

  QueryObserverOptions<InfiniteData<TData, TPageParam>, TError>
      get queryObserverOptions {
    return QueryObserverOptions<InfiniteData<TData, TPageParam>, TError>(
      _options.queryKey.parts,
      (context) async {
        final data = _inner._query.state.data ?? InfiniteData.empty();

        if (_fetchDirection case final direction? when data.pages.isNotEmpty) {
          // Fetch more pages
          final param = switch (direction) {
            FetchDirection.forward => _options.buildNextPageParam(data),
            FetchDirection.backward => _options.buildPrevPageParam(data),
          };

          if (param == null) {
            return data;
          }

          final fnContext = InfiniteQueryFunctionContext<TPageParam>(
            queryKey: context.queryKey,
            client: context.client,
            signal: context.signal,
            meta: context.meta,
            pageParam: param,
            direction: direction,
          );

          final page = await _options.queryFn(fnContext);

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

        // Fetch all pages
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
      },
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

  set options(InfiniteQueryObserverOptions<TData, TError, TPageParam> value) {
    final newOptions = value.withDefaults(_client.defaultQueryOptions);
    _options = newOptions;
    _inner.options = queryObserverOptions;
  }

  /// Fetch the next page of data.
  ///
  /// Uses [nextPageParamBuilder] to determine the page parameter for the next page.
  Future<InfiniteQueryResult<TData, TError, TPageParam>> fetchNextPage({
    bool cancelRefetch = true,
    bool throwOnError = false,
  }) async {
    _fetchDirection = FetchDirection.forward;
    try {
      await _inner._query.fetch(cancelRefetch: cancelRefetch);
    } catch (e) {
      if (throwOnError) rethrow;
    } finally {
      _fetchDirection = null;
    }
    return result;
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
      await _inner._query.fetch(cancelRefetch: cancelRefetch);
    } catch (e) {
      if (throwOnError) rethrow;
    } finally {
      _fetchDirection = null;
    }
    return result;
  }

  /// Manually refetch all pages.
  Future<InfiniteQueryResult<TData, TError, TPageParam>> refetch({
    bool cancelRefetch = true,
    bool throwOnError = false,
  }) async {
    _fetchDirection = null;
    try {
      await _inner._query.fetch(cancelRefetch: cancelRefetch);
    } catch (e) {
      if (throwOnError) rethrow;
    } finally {
      _fetchDirection = null;
    }
    return result;
  }

  void onMount() => _inner.onMount();

  void onResume() => _inner.onResume();

  void onUnmount() => _inner.onUnmount();

  void Function() subscribe(
    InfiniteResultChangeListener<TData, TError, TPageParam> listener,
  ) {
    void adapterListener(
      QueryResult<InfiniteData<TData, TPageParam>, TError> _,
    ) {
      listener(result);
    }

    _inner._listeners.add(adapterListener);
    return () => _inner._listeners.remove(adapterListener);
  }
}
