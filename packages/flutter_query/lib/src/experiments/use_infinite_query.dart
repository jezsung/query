import '../core/core.dart';
import '../hooks/use_infinite_query.dart' as core;
import 'infinite_query_snapshot.dart';

/// A hook for fetching and caching paginated data with automatic page
/// accumulation.
///
/// Equivalent to the canonical `useInfiniteQuery`, but returns an
/// [InfiniteQuerySnapshot]: a `sealed` type that supports exhaustive pattern
/// matching and exposes non-nullable `data`/`error` in the
/// [InfiniteQuerySuccess]/[InfiniteQueryError] variants.
///
/// This is an experimental API exposed via
/// `package:flutter_query/experiments.dart`. See the canonical
/// `useInfiniteQuery` for the meaning of every option.
///
/// This is an experimental API and may change in a future minor release.
InfiniteQuerySnapshot<TData, TError, TPageParam>
    useInfiniteQuery<TData, TError, TPageParam>(
  List<Object?> queryKey,
  InfiniteQueryFn<TData, TPageParam> queryFn, {
  required TPageParam initialPageParam,
  required NextPageParamBuilder<TData, TPageParam> nextPageParamBuilder,
  PrevPageParamBuilder<TData, TPageParam>? prevPageParamBuilder,
  int? maxPages,
  bool? enabled,
  NetworkMode? networkMode,
  StaleDuration? staleDuration,
  GcDuration? gcDuration,
  InfiniteData<TData, TPageParam>? placeholder,
  RefetchOnMount? refetchOnMount,
  RefetchOnResume? refetchOnResume,
  RefetchOnReconnect? refetchOnReconnect,
  Duration? refetchInterval,
  RetryResolver<TError>? retry,
  bool? retryOnMount,
  InfiniteData<TData, TPageParam>? seed,
  DateTime? seedUpdatedAt,
  Map<String, dynamic>? meta,
  ShouldRebuild<InfiniteQuerySnapshot<TData, TError, TPageParam>>?
      shouldRebuild,
  QueryClient? client,
}) {
  final result = core.useInfiniteQuery<TData, TError, TPageParam>(
    queryKey,
    queryFn,
    initialPageParam: initialPageParam,
    nextPageParamBuilder: nextPageParamBuilder,
    prevPageParamBuilder: prevPageParamBuilder,
    maxPages: maxPages,
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
    shouldRebuild: shouldRebuild == null
        ? null
        : (previous, next) =>
            shouldRebuild(previous.toSnapshot(), next.toSnapshot()),
    client: client,
  );

  return result.toSnapshot();
}
