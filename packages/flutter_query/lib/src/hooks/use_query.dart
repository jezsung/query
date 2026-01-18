import 'package:flutter/widgets.dart';

import 'package:flutter_hooks/flutter_hooks.dart';

import '../core/core.dart';
import 'use_query_client.dart';

/// A hook for fetching, caching, and subscribing to async data.
///
/// This hook manages the complete lifecycle of async data fetching, including
/// request deduplication, caching, background refetching, and stale-while-
/// revalidate patterns.
///
/// The [queryKey] uniquely identifies this query in the cache. Queries with the
/// same key share cached data across the widget tree.
///
/// The [queryFn] fetches the data when the query needs to execute. It receives
/// a [QueryFunctionContext] with the query key and other metadata.
///
/// Returns a [QueryResult] containing the current state of the query, including
/// data, error, and status flags. The widget rebuilds automatically when the
/// query state changes.
///
/// ## Options
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
/// - [useInfiniteQuery] for paginated data
/// - [useMutation] for create, update, and delete operations
/// - [QueryClient.prefetchQuery] for prefetching data before it's needed
QueryResult<TData, TError> useQuery<TData, TError>(
  List<Object?> queryKey,
  QueryFn<TData> queryFn, {
  bool? enabled,
  StaleDuration? staleDuration,
  GcDuration? gcDuration,
  TData? placeholder,
  RefetchOnMount? refetchOnMount,
  RefetchOnResume? refetchOnResume,
  Duration? refetchInterval,
  RetryResolver<TError>? retry,
  bool? retryOnMount,
  TData? seed,
  DateTime? seedUpdatedAt,
  Map<String, dynamic>? meta,
  QueryClient? client,
}) {
  final effectiveClient = useQueryClient(client);

  // Create observer once per component instance
  final observer = useMemoized(
    () => QueryObserver<TData, TError>(
      effectiveClient,
      QueryObserverOptions(
        queryKey,
        queryFn,
        enabled: enabled,
        staleDuration: staleDuration,
        gcDuration: gcDuration,
        meta: meta,
        placeholder: placeholder,
        refetchInterval: refetchInterval,
        refetchOnMount: refetchOnMount,
        refetchOnResume: refetchOnResume,
        retry: retry,
        retryOnMount: retryOnMount,
        seed: seed,
        seedUpdatedAt: seedUpdatedAt,
      ),
    ),
    [effectiveClient],
  );

  // Update options during render (before subscribing)
  observer.options = QueryObserverOptions(
    queryKey,
    queryFn,
    enabled: enabled,
    staleDuration: staleDuration,
    gcDuration: gcDuration,
    meta: meta,
    placeholder: placeholder,
    refetchInterval: refetchInterval,
    refetchOnMount: refetchOnMount,
    refetchOnResume: refetchOnResume,
    retry: retry,
    retryOnMount: retryOnMount,
    seed: seed,
    seedUpdatedAt: seedUpdatedAt,
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
