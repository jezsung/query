import 'default_query_options.dart';
import 'infinite_query_function_context.dart';
import 'network_mode.dart';
import 'query_key.dart';
import 'query_observer.dart';
import 'query_options.dart';
import 'utils.dart';

/// Signature for the function that fetches a page of data for an infinite query.
///
/// Receives a [context] containing the [InfiniteQueryFunctionContext.pageParam]
/// for the page to fetch and a [InfiniteQueryFunctionContext.signal] for
/// cancellation.
typedef InfiniteQueryFn<TData, TPageParam> = Future<TData> Function(
  InfiniteQueryFunctionContext<TPageParam> context,
);

/// Signature for the function that determines the next page parameter.
///
/// Receives the current [data] containing all fetched pages and their
/// parameters. Returns the parameter for the next page, or `null` if there
/// are no more pages.
typedef NextPageParamBuilder<TData, TPageParam> = TPageParam? Function(
  InfiniteData<TData, TPageParam> data,
);

/// Signature for the function that determines the previous page parameter.
///
/// Receives the current [data] containing all fetched pages and their
/// parameters. Returns the parameter for the previous page, or `null` if there
/// are no more pages.
typedef PrevPageParamBuilder<TData, TPageParam> = TPageParam? Function(
  InfiniteData<TData, TPageParam> data,
);

class InfiniteQueryOptions<TData, TError, TPageParam> {
  InfiniteQueryOptions(
    List<Object?> queryKey,
    this.queryFn, {
    required this.initialPageParam,
    required this.nextPageParamBuilder,
    this.prevPageParamBuilder,
    this.maxPages,
    this.enabled,
    this.networkMode,
    this.staleDuration,
    this.gcDuration,
    this.placeholder,
    this.refetchOnMount,
    this.refetchOnResume,
    this.refetchOnReconnect,
    this.refetchInterval,
    this.retry,
    this.retryOnMount,
    this.seed,
    this.seedUpdatedAt,
    this.meta,
  }) : queryKey = QueryKey(queryKey);

  final QueryKey queryKey;
  final InfiniteQueryFn<TData, TPageParam> queryFn;
  final TPageParam initialPageParam;
  final NextPageParamBuilder<TData, TPageParam> nextPageParamBuilder;
  final PrevPageParamBuilder<TData, TPageParam>? prevPageParamBuilder;
  final int? maxPages;
  final bool? enabled;
  final NetworkMode? networkMode;
  final StaleDuration? staleDuration;
  final GcDuration? gcDuration;
  final InfiniteData<TData, TPageParam>? placeholder;
  final RefetchOnMount? refetchOnMount;
  final RefetchOnResume? refetchOnResume;
  final RefetchOnReconnect? refetchOnReconnect;
  final Duration? refetchInterval;
  final RetryResolver<TError>? retry;
  final bool? retryOnMount;
  final InfiniteData<TData, TPageParam>? seed;
  final DateTime? seedUpdatedAt;
  final Map<String, dynamic>? meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InfiniteQueryOptions<TData, TError, TPageParam> &&
          queryKey == other.queryKey &&
          identical(queryFn, other.queryFn) &&
          deepEq.equals(initialPageParam, other.initialPageParam) &&
          identical(nextPageParamBuilder, other.nextPageParamBuilder) &&
          identical(prevPageParamBuilder, other.prevPageParamBuilder) &&
          maxPages == other.maxPages &&
          enabled == other.enabled &&
          networkMode == other.networkMode &&
          staleDuration == other.staleDuration &&
          gcDuration == other.gcDuration &&
          deepEq.equals(placeholder, other.placeholder) &&
          refetchOnMount == other.refetchOnMount &&
          refetchOnResume == other.refetchOnResume &&
          refetchOnReconnect == other.refetchOnReconnect &&
          refetchInterval == other.refetchInterval &&
          identical(retry, other.retry) &&
          retryOnMount == other.retryOnMount &&
          deepEq.equals(seed, other.seed) &&
          seedUpdatedAt == other.seedUpdatedAt &&
          deepEq.equals(meta, other.meta);

  @override
  int get hashCode => Object.hash(
        queryKey,
        identityHashCode(queryFn),
        deepEq.hash(initialPageParam),
        identityHashCode(nextPageParamBuilder),
        identityHashCode(prevPageParamBuilder),
        maxPages,
        enabled,
        networkMode,
        staleDuration,
        gcDuration,
        deepEq.hash(placeholder),
        refetchOnMount,
        refetchOnResume,
        refetchOnReconnect,
        refetchInterval,
        identityHashCode(retry),
        retryOnMount,
        deepEq.hash(seed),
        seedUpdatedAt,
        deepEq.hash(meta),
      );

  @override
  String toString() => 'InfiniteQueryOptions('
      'queryKey: $queryKey, '
      'initialPageParam: $initialPageParam, '
      'maxPages: $maxPages, '
      'enabled: $enabled, '
      'networkMode: $networkMode, '
      'staleDuration: $staleDuration, '
      'gcDuration: $gcDuration, '
      'placeholder: $placeholder, '
      'refetchOnMount: $refetchOnMount, '
      'refetchOnResume: $refetchOnResume, '
      'refetchOnReconnect: $refetchOnReconnect, '
      'refetchInterval: $refetchInterval, '
      'retryOnMount: $retryOnMount, '
      'seed: $seed, '
      'seedUpdatedAt: $seedUpdatedAt, '
      'meta: $meta)';
}

extension InfiniteQueryOptionsExt<TData, TError, TPageParam>
    on InfiniteQueryOptions<TData, TError, TPageParam> {
  InfiniteQueryOptions<TData, TError, TPageParam> withDefaults(
    DefaultQueryOptions defaults,
  ) {
    return InfiniteQueryOptions<TData, TError, TPageParam>(
      queryKey.parts,
      queryFn,
      initialPageParam: initialPageParam,
      nextPageParamBuilder: nextPageParamBuilder,
      prevPageParamBuilder: prevPageParamBuilder,
      maxPages: maxPages,
      enabled: enabled ?? defaults.enabled,
      networkMode: networkMode ?? defaults.networkMode,
      staleDuration: staleDuration ?? defaults.staleDuration,
      gcDuration: gcDuration ?? defaults.gcDuration,
      placeholder: placeholder,
      refetchOnMount: refetchOnMount ?? defaults.refetchOnMount,
      refetchOnResume: refetchOnResume ?? defaults.refetchOnResume,
      refetchOnReconnect: refetchOnReconnect ?? defaults.refetchOnReconnect,
      refetchInterval: refetchInterval ?? defaults.refetchInterval,
      retry: retry ?? defaults.retry as RetryResolver<TError>?,
      retryOnMount: retryOnMount ?? defaults.retryOnMount,
      seed: seed,
      seedUpdatedAt: seedUpdatedAt,
      meta: meta,
    );
  }

  TPageParam? buildNextPageParam(InfiniteData<TData, TPageParam> data) {
    if (data.pages.isEmpty || data.pageParams.isEmpty) return null;

    return nextPageParamBuilder(data);
  }

  TPageParam? buildPrevPageParam(InfiniteData<TData, TPageParam> data) {
    if (data.pages.isEmpty || data.pageParams.isEmpty) return null;

    return prevPageParamBuilder?.call(data);
  }
}
