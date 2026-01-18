import 'default_query_options.dart';
import 'infinite_query_function_context.dart';
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

class InfiniteQueryObserverOptions<TData, TError, TPageParam> {
  InfiniteQueryObserverOptions(
    List<Object?> queryKey,
    this.queryFn, {
    required this.initialPageParam,
    required this.nextPageParamBuilder,
    this.prevPageParamBuilder,
    this.maxPages,
    this.enabled,
    this.staleDuration,
    this.gcDuration,
    this.placeholder,
    this.refetchOnMount,
    this.refetchOnResume,
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
  final StaleDuration? staleDuration;
  final GcDuration? gcDuration;
  final InfiniteData<TData, TPageParam>? placeholder;
  final RefetchOnMount? refetchOnMount;
  final RefetchOnResume? refetchOnResume;
  final Duration? refetchInterval;
  final RetryResolver<TError>? retry;
  final bool? retryOnMount;
  final InfiniteData<TData, TPageParam>? seed;
  final DateTime? seedUpdatedAt;
  final Map<String, dynamic>? meta;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InfiniteQueryObserverOptions<TData, TError, TPageParam> &&
        queryKey == other.queryKey &&
        identical(queryFn, other.queryFn) &&
        deepEq.equals(initialPageParam, other.initialPageParam) &&
        identical(nextPageParamBuilder, other.nextPageParamBuilder) &&
        identical(prevPageParamBuilder, other.prevPageParamBuilder) &&
        maxPages == other.maxPages &&
        enabled == other.enabled &&
        staleDuration == other.staleDuration &&
        gcDuration == other.gcDuration &&
        deepEq.equals(placeholder, other.placeholder) &&
        refetchOnMount == other.refetchOnMount &&
        refetchOnResume == other.refetchOnResume &&
        refetchInterval == other.refetchInterval &&
        identical(retry, other.retry) &&
        retryOnMount == other.retryOnMount &&
        deepEq.equals(seed, other.seed) &&
        seedUpdatedAt == other.seedUpdatedAt &&
        deepEq.equals(meta, other.meta);
  }

  @override
  int get hashCode => Object.hash(
        queryKey,
        identityHashCode(queryFn),
        deepEq.hash(initialPageParam),
        identityHashCode(nextPageParamBuilder),
        identityHashCode(prevPageParamBuilder),
        maxPages,
        enabled,
        staleDuration,
        gcDuration,
        deepEq.hash(placeholder),
        refetchOnMount,
        refetchOnResume,
        refetchInterval,
        identityHashCode(retry),
        retryOnMount,
        deepEq.hash(seed),
        seedUpdatedAt,
        deepEq.hash(meta),
      );
}

extension InfiniteQueryObserverOptionsExt<TData, TError, TPageParam>
    on InfiniteQueryObserverOptions<TData, TError, TPageParam> {
  InfiniteQueryObserverOptions<TData, TError, TPageParam> withDefaults(
    DefaultQueryOptions defaults,
  ) {
    return InfiniteQueryObserverOptions<TData, TError, TPageParam>(
      queryKey.parts,
      queryFn,
      initialPageParam: initialPageParam,
      nextPageParamBuilder: nextPageParamBuilder,
      prevPageParamBuilder: prevPageParamBuilder,
      maxPages: maxPages,
      enabled: enabled ?? defaults.enabled,
      staleDuration: staleDuration ?? defaults.staleDuration,
      gcDuration: gcDuration ?? defaults.gcDuration,
      placeholder: placeholder,
      refetchOnMount: refetchOnMount ?? defaults.refetchOnMount,
      refetchOnResume: refetchOnResume ?? defaults.refetchOnResume,
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
