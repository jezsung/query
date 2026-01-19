part of 'query_options.dart';

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
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueryObserverOptions<TData, TError> &&
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

  @override
  String toString() => 'QueryObserverOptions('
      'queryKey: $queryKey, '
      'enabled: $enabled, '
      'staleDuration: $staleDuration, '
      'gcDuration: $gcDuration, '
      'placeholder: $placeholder, '
      'refetchOnMount: $refetchOnMount, '
      'refetchOnResume: $refetchOnResume, '
      'refetchInterval: $refetchInterval, '
      'retryOnMount: $retryOnMount, '
      'seed: $seed, '
      'seedUpdatedAt: $seedUpdatedAt, '
      'meta: $meta)';
}

extension QueryObserverOptionsExt<TData, TError>
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
