import 'default_query_options.dart';
import 'gc_duration.dart';
import 'query_key.dart';
import 'refetch_on_mount.dart';
import 'refetch_on_resume.dart';
import 'retry.dart';
import 'stale_duration.dart';
import 'types.dart';
import 'utils.dart';

/// Base options for configuring a query at the cache level.
///
/// Contains core configuration that affects the Query instance itself,
/// shared across all observers watching this query.
class QueryOptions<TData, TError> {
  QueryOptions(
    List<Object?> queryKey,
    this.queryFn, {
    this.retry,
    this.gcDuration,
    this.seed,
    this.seedUpdatedAt,
    this.meta,
  }) : queryKey = QueryKey(queryKey);

  final QueryKey queryKey;
  final QueryFn<TData> queryFn;
  final RetryResolver<TError>? retry;
  final GcDuration? gcDuration;
  final TData? seed;
  final DateTime? seedUpdatedAt;
  final Map<String, dynamic>? meta;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QueryOptions<TData, TError> &&
        queryKey == other.queryKey &&
        identical(queryFn, other.queryFn) &&
        gcDuration == other.gcDuration &&
        deepEq.equals(meta, other.meta) &&
        identical(retry, other.retry) &&
        deepEq.equals(seed, other.seed) &&
        seedUpdatedAt == other.seedUpdatedAt;
  }

  @override
  int get hashCode => Object.hash(
        queryKey,
        identityHashCode(queryFn),
        gcDuration,
        deepEq.hash(meta),
        identityHashCode(retry),
        deepEq.hash(seed),
        seedUpdatedAt,
      );
}

/// Observer-specific options that extend the base QueryOptions.
///
/// Contains configuration that affects individual QueryObserver instances,
/// allowing different observers to have different behaviors for the same query.
class QueryObserverOptions<TData, TError> extends QueryOptions<TData, TError> {
  QueryObserverOptions(
    super.queryKey,
    super.queryFn, {
    super.retry,
    super.gcDuration,
    super.seed,
    super.seedUpdatedAt,
    super.meta,
    this.enabled,
    this.staleDuration,
    this.placeholder,
    this.refetchOnMount,
    this.refetchOnResume,
    this.refetchInterval,
    this.retryOnMount,
  });

  final bool? enabled;
  final StaleDuration? staleDuration;
  final TData? placeholder;
  final RefetchOnMount? refetchOnMount;
  final RefetchOnResume? refetchOnResume;
  final Duration? refetchInterval;
  final bool? retryOnMount;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QueryObserverOptions<TData, TError> &&
        queryKey == other.queryKey &&
        identical(queryFn, other.queryFn) &&
        gcDuration == other.gcDuration &&
        deepEq.equals(meta, other.meta) &&
        identical(retry, other.retry) &&
        deepEq.equals(seed, other.seed) &&
        seedUpdatedAt == other.seedUpdatedAt &&
        enabled == other.enabled &&
        staleDuration == other.staleDuration &&
        deepEq.equals(placeholder, other.placeholder) &&
        refetchInterval == other.refetchInterval &&
        refetchOnMount == other.refetchOnMount &&
        refetchOnResume == other.refetchOnResume &&
        retryOnMount == other.retryOnMount;
  }

  @override
  int get hashCode => Object.hash(
        queryKey,
        identityHashCode(queryFn),
        gcDuration,
        deepEq.hash(meta),
        identityHashCode(retry),
        deepEq.hash(seed),
        seedUpdatedAt,
        enabled,
        staleDuration,
        deepEq.hash(placeholder),
        refetchInterval,
        refetchOnMount,
        refetchOnResume,
        retryOnMount,
      );
}

extension QueryOptionsWithDefaults<TData, TError>
    on QueryOptions<TData, TError> {
  /// Merges this QueryOptions with default options.
  ///
  /// Query-specific options take precedence over defaults.
  QueryOptions<TData, TError> withDefaults(DefaultQueryOptions defaults) {
    return QueryOptions<TData, TError>(
      queryKey.parts,
      queryFn,
      gcDuration: gcDuration ?? defaults.gcDuration,
      meta: meta,
      retry: retry ?? defaults.retry as RetryResolver<TError>?,
      seed: seed,
      seedUpdatedAt: seedUpdatedAt,
    );
  }
}

extension QueryObserverOptionsWithDefaults<TData, TError>
    on QueryObserverOptions<TData, TError> {
  /// Merges this QueryObserverOptions with default options.
  ///
  /// Observer-specific options take precedence over defaults.
  QueryObserverOptions<TData, TError> withDefaults(
    DefaultQueryOptions defaults,
  ) {
    return QueryObserverOptions<TData, TError>(
      queryKey.parts,
      queryFn,
      gcDuration: gcDuration ?? defaults.gcDuration,
      meta: meta,
      retry: retry ?? defaults.retry as RetryResolver<TError>?,
      seed: seed,
      seedUpdatedAt: seedUpdatedAt,
      enabled: enabled ?? defaults.enabled,
      staleDuration: staleDuration ?? defaults.staleDuration,
      placeholder: placeholder,
      refetchInterval: refetchInterval ?? defaults.refetchInterval,
      refetchOnMount: refetchOnMount ?? defaults.refetchOnMount,
      refetchOnResume: refetchOnResume ?? defaults.refetchOnResume,
      retryOnMount: retryOnMount ?? defaults.retryOnMount,
    );
  }
}

extension QueryOptionsMerge<TData, TError> on QueryOptions<TData, TError> {
  QueryOptions<TData, TError> merge(QueryOptions<TData, TError> options) {
    assert(options.queryKey == queryKey);

    return QueryOptions<TData, TError>(
      options.queryKey.parts,
      options.queryFn,
      gcDuration: switch ((options.gcDuration, gcDuration)) {
        (null, null) => null,
        (final a?, null) => a,
        (null, final b?) => b,
        (final a?, final b?) => a > b ? a : b,
      },
      meta: deepMergeMap(meta, options.meta),
      retry: options.retry ?? retry,
      seed: switch ((options.seed, seed)) {
        (null, null) => null,
        (final TData a, null) => a,
        (null, final TData b) => b,
        (final TData a, final TData _) => a,
      },
      seedUpdatedAt: switch ((options.seedUpdatedAt, seedUpdatedAt)) {
        (null, null) => null,
        (final a?, null) => a,
        (null, final b?) => b,
        (final a?, final b?) => a.isAfter(b) ? a : b,
      },
    );
  }
}
