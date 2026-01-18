import 'package:flutter/widgets.dart';

import 'package:flutter_hooks/flutter_hooks.dart';

import '../core/core.dart';
import 'use_query_client.dart';

/// A hook that manages infinite/paginated queries with automatic page accumulation.
///
/// Returns an [InfiniteQueryResult] containing the accumulated pages, pagination
/// state, and methods to fetch more pages.
///
/// Example:
/// ```dart
/// final query = useInfiniteQuery<Post, Error, int>(
///   ['posts'],
///   (context) => fetchPosts(page: context.pageParam),
///   initialPageParam: 1,
///   nextPageParamBuilder: (data) {
///     return data.pages.last.hasMore ? data.pageParams.last + 1 : null;
///   },
/// );
///
/// // Access pages
/// for (final page in query.data?.pages ?? []) {
///   for (final post in page.items) {
///     // render post
///   }
/// }
///
/// // Load more
/// if (query.hasNextPage) {
///   TextButton(
///     onPressed: query.isFetchingNextPage ? null : () => query.fetchNextPage(),
///     child: Text('Load More'),
///   );
/// }
/// ```
///
/// Matches TanStack Query v5's useInfiniteQuery hook.
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
      InfiniteQueryObserverOptions(
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

  // Update options during render (before subscribing)
  observer.options = InfiniteQueryObserverOptions(
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

  return result.value;
}
