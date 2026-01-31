import 'package:flutter/widgets.dart';

import 'package:flutter_hooks/flutter_hooks.dart';

import '../core/core.dart';
import 'use_query_client.dart';

/// A hook for fetching and caching paginated data with automatic page
/// accumulation.
///
/// This hook extends [useQuery] with pagination support, managing multiple
/// pages of data and providing methods to fetch additional pages in either
/// direction.
///
/// The [queryKey] uniquely identifies this query in the cache. Queries with the
/// same key share cached data across the widget tree.
///
/// The [queryFn] fetches a single page of data. It receives an
/// [InfiniteQueryFunctionContext] containing the [pageParam] for the page to
/// fetch.
///
/// Returns an [InfiniteQueryResult] containing the accumulated pages,
/// pagination state, and methods to fetch more pages. The widget rebuilds
/// automatically when the query state changes.
///
/// ## Options
///
/// - [initialPageParam]: The page parameter for the first page fetch.
///
/// - [nextPageParamBuilder]: A function that returns the page parameter for the
///   next page, or `null` if there are no more pages. Receives the current
///   [InfiniteData] containing all fetched pages.
///
/// - [prevPageParamBuilder]: A function that returns the page parameter for the
///   previous page, or `null` if there are no previous pages. Required for
///   bidirectional pagination.
///
/// - [maxPages]: The maximum number of pages to keep in cache. When exceeded,
///   pages are removed from the opposite end of the fetch direction.
///
/// - [enabled]: Whether the query should execute. Defaults to `true`. Set to
///   `false` to disable automatic fetching.
///
/// - [staleDuration]: How long data remains fresh before becoming stale.
///   Stale data may be refetched on the next access. Defaults to zero (data is
///   immediately stale).
///
/// - [gcDuration]: How long unused data remains in cache before garbage
///   collection. Defaults to 5 minutes.
///
/// - [placeholder]: Data to display while the query is pending and has no
///   cached data. Unlike [seed], placeholder data is not persisted to the
///   cache.
///
/// - [refetchOnMount]: Controls refetch behavior when this hook mounts. Can be
///   [RefetchOnMount.stale] (default), [RefetchOnMount.always], or
///   [RefetchOnMount.never].
///
/// - [refetchOnResume]: Controls refetch behavior when the app resumes from
///   background. Can be [RefetchOnResume.stale] (default),
///   [RefetchOnResume.always], or [RefetchOnResume.never].
///
/// - [refetchInterval]: Automatically refetch at the specified interval while
///   this hook is mounted.
///
/// - [retry]: A callback that controls retry behavior on failure. Returns a
///   [Duration] to retry after waiting, or `null` to stop retrying. Defaults
///   to 3 retries with exponential backoff (1s, 2s, 4s).
///
/// - [retryOnMount]: Whether to retry failed queries when this hook mounts.
///   Defaults to `true`.
///
/// - [seed]: Initial data to populate the cache before the first fetch. Unlike
///   [placeholder], seed data is persisted to the cache.
///
/// - [seedUpdatedAt]: The timestamp when [seed] data was last updated. Used to
///   determine staleness of seed data.
///
/// - [meta]: A map of arbitrary metadata attached to this query, accessible
///   in the query function context. When multiple hooks share the same query
///   key, their [meta] maps are deep merged.
///
/// - [client]: The [QueryClient] to use. If provided, takes precedence over
///   the nearest [QueryClientProvider] ancestor.
///
/// See also:
///
/// - [useQuery] for non-paginated data
/// - [useMutation] for create, update, and delete operations
InfiniteQueryResult<TData, TError, TPageParam>
    useInfiniteQuery<TData, TError, TPageParam>(
  List<Object?> queryKey,
  InfiniteQueryFn<TData, TPageParam> queryFn, {
  required TPageParam initialPageParam,
  required NextPageParamBuilder<TData, TPageParam> nextPageParamBuilder,
  PrevPageParamBuilder<TData, TPageParam>? prevPageParamBuilder,
  int? maxPages,
  bool? enabled,
  StaleDuration? staleDuration,
  GcDuration? gcDuration,
  InfiniteData<TData, TPageParam>? placeholder,
  RefetchOnMount? refetchOnMount,
  RefetchOnResume? refetchOnResume,
  Duration? refetchInterval,
  RetryResolver<TError>? retry,
  bool? retryOnMount,
  InfiniteData<TData, TPageParam>? seed,
  DateTime? seedUpdatedAt,
  Map<String, dynamic>? meta,
  QueryClient? client,
}) {
  final effectiveClient = useQueryClient(client);

  // Create observer once per component instance
  final observer = useMemoized(
    () => InfiniteQueryObserver<TData, TError, TPageParam>(
      effectiveClient,
      InfiniteQueryOptions(
        queryKey,
        queryFn,
        initialPageParam: initialPageParam,
        nextPageParamBuilder: nextPageParamBuilder,
        prevPageParamBuilder: prevPageParamBuilder,
        maxPages: maxPages,
        enabled: enabled,
        staleDuration: staleDuration,
        gcDuration: gcDuration,
        placeholder: placeholder,
        refetchOnMount: refetchOnMount,
        refetchOnResume: refetchOnResume,
        refetchInterval: refetchInterval,
        retry: retry,
        retryOnMount: retryOnMount,
        seed: seed,
        seedUpdatedAt: seedUpdatedAt,
        meta: meta,
      ),
    ),
    [effectiveClient],
  );

  // Mount observer and cleanup on unmount
  useEffect(() {
    observer.onMount();
    return observer.onUnmount;
  }, [observer]);

  // Handle app lifecycle resume events
  useEffect(() {
    final listener = AppLifecycleListener(onResume: observer.onResume);
    return listener.dispose;
  }, [observer]);

  // Update options during render (before subscribing)
  observer.options = InfiniteQueryOptions(
    queryKey,
    queryFn,
    initialPageParam: initialPageParam,
    nextPageParamBuilder: nextPageParamBuilder,
    prevPageParamBuilder: prevPageParamBuilder,
    maxPages: maxPages,
    enabled: enabled,
    staleDuration: staleDuration,
    gcDuration: gcDuration,
    placeholder: placeholder,
    refetchOnMount: refetchOnMount,
    refetchOnResume: refetchOnResume,
    refetchInterval: refetchInterval,
    retry: retry,
    retryOnMount: retryOnMount,
    seed: seed,
    seedUpdatedAt: seedUpdatedAt,
    meta: meta,
  );

  // Subscribe to observer and trigger rebuilds when result changes
  // Uses useState with useEffect subscription for synchronous updates
  final result = useState(observer.result);

  useEffect(() {
    final unsubscribe = observer.subscribe((newResult) {
      result.value = newResult;
    });
    return unsubscribe;
  }, [observer]);

  return result.value;
}
