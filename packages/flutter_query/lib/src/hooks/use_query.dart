import '../core/core.dart';
import 'use_query_options.dart';

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
/// Returns a [QuerySnapshot] containing the current state of the query: a
/// `sealed` type supporting exhaustive pattern matching over
/// [QueryPending] / [QuerySuccess] / [QueryError]. The widget rebuilds
/// automatically when the query state changes.
///
/// ## Options
///
/// - [enabled]: Whether the query should execute. Defaults to `true`. Set to
///   `false` to disable automatic fetching.
///
/// - [networkMode]: The network connectivity mode for this query. Has no
///   effect unless [connectivityChanges] is provided to [QueryClient]. Can be
///   [NetworkMode.online] (default, pauses when offline), [NetworkMode.always]
///   (ignores network state), or [NetworkMode.offlineFirst] (first fetch runs
///   immediately, retries pause when offline).
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
/// - [refetchOnReconnect]: Controls refetch behavior when network connectivity
///   is restored. Can be [RefetchOnReconnect.stale] (default),
///   [RefetchOnReconnect.always], or [RefetchOnReconnect.never]. Requires
///   [connectivityChanges] to be provided to [QueryClient].
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
/// - [shouldRebuild]: Decides per update whether the observing widget
///   rebuilds. Receives the last accepted result and the new result; return
///   `true` to rebuild or `false` to suppress. When omitted, the widget
///   rebuilds on every change.
///
/// - [client]: The [QueryClient] to use. If provided, takes precedence over
///   the nearest [QueryClientProvider] ancestor.
///
/// See also:
///
/// - [useInfiniteQuery] for paginated data
/// - [useMutation] for create, update, and delete operations
/// - [QueryClient.prefetchQuery] for prefetching data before it's needed
QuerySnapshot<TData, TError> useQuery<TData, TError>(
  List<Object?> queryKey,
  QueryFn<TData> queryFn, {
  bool? enabled,
  NetworkMode? networkMode,
  StaleDuration? staleDuration,
  GcDuration? gcDuration,
  TData? placeholder,
  RefetchOnMount? refetchOnMount,
  RefetchOnResume? refetchOnResume,
  RefetchOnReconnect? refetchOnReconnect,
  Duration? refetchInterval,
  RetryResolver<TError>? retry,
  bool? retryOnMount,
  TData? seed,
  DateTime? seedUpdatedAt,
  Map<String, dynamic>? meta,
  ShouldRebuild<QuerySnapshot<TData, TError>>? shouldRebuild,
  QueryClient? client,
}) {
  return useQueryOptions(
    QueryOptions(
      queryKey,
      queryFn,
      enabled: enabled,
      networkMode: networkMode,
      staleDuration: staleDuration,
      gcDuration: gcDuration,
      placeholder: placeholder,
      refetchOnMount: refetchOnMount,
      refetchOnResume: refetchOnResume,
      refetchOnReconnect: refetchOnReconnect,
      refetchInterval: refetchInterval,
      retry: retry,
      retryOnMount: retryOnMount,
      seed: seed,
      seedUpdatedAt: seedUpdatedAt,
      meta: meta,
    ),
    shouldRebuild: shouldRebuild,
    client: client,
  );
}
