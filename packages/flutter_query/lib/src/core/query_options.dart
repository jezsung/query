import 'package:collection/collection.dart';

import 'default_query_options.dart';
import 'options/expiry.dart';
import 'options/gc_duration.dart';
import 'options/refetch_on_mount.dart';
import 'options/refetch_on_resume.dart';
import 'options/retry.dart';
import 'query_key.dart';
import 'types.dart';

/// Options for configuring a query.
///
/// Contains all the configuration options for a query including the query key,
/// query function, and various behavioral options like expiresIn, retry, etc.
class QueryOptions<TData, TError> {
  QueryOptions(
    this.queryKey,
    this.queryFn, {
    this.enabled,
    this.expiresIn,
    this.gcDuration,
    this.placeholder,
    this.refetchInterval,
    this.refetchOnMount,
    this.refetchOnResume,
    this.retry,
    this.retryOnMount,
    this.seed,
    this.seedUpdatedAt,
  });

  final List<Object?> queryKey;
  final QueryFn<TData> queryFn;
  final bool? enabled;
  final Expiry? expiresIn;
  final GcDuration? gcDuration;
  final TData? placeholder;
  final Duration? refetchInterval;
  final RefetchOnMount? refetchOnMount;
  final RefetchOnResume? refetchOnResume;
  final RetryResolver<TError>? retry;
  final bool? retryOnMount;
  final TData? seed;
  final DateTime? seedUpdatedAt;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QueryOptions<TData, TError> &&
        _equality.equals(queryKey, other.queryKey) &&
        identical(queryFn, other.queryFn) &&
        enabled == other.enabled &&
        expiresIn == other.expiresIn &&
        gcDuration == other.gcDuration &&
        _equality.equals(placeholder, other.placeholder) &&
        refetchInterval == other.refetchInterval &&
        refetchOnMount == other.refetchOnMount &&
        refetchOnResume == other.refetchOnResume &&
        identical(retry, other.retry) &&
        retryOnMount == other.retryOnMount &&
        _equality.equals(seed, other.seed) &&
        seedUpdatedAt == other.seedUpdatedAt;
  }

  @override
  int get hashCode => Object.hash(
        _equality.hash(queryKey),
        identityHashCode(queryFn),
        enabled,
        expiresIn,
        gcDuration,
        _equality.hash(placeholder),
        refetchInterval,
        refetchOnMount,
        refetchOnResume,
        identityHashCode(retry),
        retryOnMount,
        _equality.hash(seed),
        seedUpdatedAt,
      );
}

const DeepCollectionEquality _equality = DeepCollectionEquality();

extension QueryOptionsMergeWith<TData, TError> on QueryOptions<TData, TError> {
  /// Merges this QueryOptions with default options.
  ///
  /// Query-specific options take precedence over defaults.
  /// Handles type conversion for generic types (dynamic/Object? -> TData/TError).
  QueryOptions<TData, TError> withDefaults(DefaultQueryOptions defaults) {
    return QueryOptions<TData, TError>(
      queryKey,
      queryFn,
      enabled: enabled ?? defaults.enabled,
      expiresIn: expiresIn ?? defaults.expiresIn,
      gcDuration: gcDuration ?? defaults.gcDuration,
      placeholder: placeholder,
      refetchInterval: refetchInterval ?? defaults.refetchInterval,
      refetchOnMount: refetchOnMount ?? defaults.refetchOnMount,
      refetchOnResume: refetchOnResume ?? defaults.refetchOnResume,
      retry: retry ?? defaults.retry as RetryResolver<TError>?,
      retryOnMount: retryOnMount ?? defaults.retryOnMount,
      seed: seed,
      seedUpdatedAt: seedUpdatedAt,
    );
  }
}

extension QueryOptionsMerge<TData, TError> on QueryOptions<TData, TError> {
  QueryOptions<TData, TError> merge(QueryOptions<TData, TError> options) {
    assert(QueryKey(options.queryKey) == QueryKey(queryKey));

    return QueryOptions<TData, TError>(
      options.queryKey,
      options.queryFn,
      enabled: switch ((options.enabled, enabled)) {
        (null, null) => null,
        (final a, null) => a,
        (null, final b) => b,
        (true, _) => true,
        (_, true) => true,
        (false, false) => false,
      },
      expiresIn: switch ((options.expiresIn, expiresIn)) {
        (null, null) => null,
        (final a?, null) => a,
        (null, final b?) => b,
        (ExpiryNever(), _) => Expiry.never,
        (_, ExpiryNever()) => Expiry.never,
        (ExpiryInfinity(), _) => Expiry.infinity,
        (_, ExpiryInfinity()) => Expiry.infinity,
        (ExpiryDuration a, ExpiryDuration b) => a < b ? a : b,
      },
      gcDuration: switch ((options.gcDuration, gcDuration)) {
        (null, null) => null,
        (final a?, null) => a,
        (null, final b?) => b,
        (final a?, final b?) => a > b ? a : b,
      },
      placeholder: options.placeholder ?? placeholder,
      refetchInterval: switch ((options.refetchInterval, refetchInterval)) {
        (null, null) => null,
        (final a?, null) => a,
        (null, final b?) => b,
        (final a?, final b?) => a < b ? a : b,
      },
      refetchOnMount: switch ((options.refetchOnMount, refetchOnMount)) {
        (null, null) => null,
        (final a?, null) => a,
        (null, final b?) => b,
        (RefetchOnMount.always, _) => RefetchOnMount.always,
        (_, RefetchOnMount.always) => RefetchOnMount.always,
        (RefetchOnMount.stale, _) => RefetchOnMount.stale,
        (_, RefetchOnMount.stale) => RefetchOnMount.stale,
        (RefetchOnMount.never, RefetchOnMount.never) => RefetchOnMount.never,
      },
      refetchOnResume: switch ((options.refetchOnResume, refetchOnResume)) {
        (null, null) => null,
        (final a?, null) => a,
        (null, final b?) => b,
        (RefetchOnResume.always, _) => RefetchOnResume.always,
        (_, RefetchOnResume.always) => RefetchOnResume.always,
        (RefetchOnResume.stale, _) => RefetchOnResume.stale,
        (_, RefetchOnResume.stale) => RefetchOnResume.stale,
        (RefetchOnResume.never, RefetchOnResume.never) => RefetchOnResume.never,
      },
      retry: options.retry ?? retry,
      retryOnMount: switch ((options.retryOnMount, retryOnMount)) {
        (null, null) => null,
        (final a, null) => a,
        (null, final b) => b,
        (true, _) => true,
        (_, true) => true,
        (false, false) => false,
      },
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
        (final a?, final b?) => a.isBefore(b) ? a : b,
      },
    );
  }
}

extension QueryOptionsCopyWith<TData, TError> on QueryOptions<TData, TError> {
  QueryOptions<TData, TError> copyWith({
    List<Object?>? queryKey,
    QueryFn<TData>? queryFn,
    bool? enabled,
    Expiry? expiresIn,
    GcDuration? gcDuration,
    TData? placeholder,
    Duration? refetchInterval,
    RefetchOnMount? refetchOnMount,
    RefetchOnResume? refetchOnResume,
    RetryResolver<TError>? retry,
    bool? retryOnMount,
    TData? seed,
    DateTime? seedUpdatedAt,
  }) {
    return QueryOptions<TData, TError>(
      queryKey ?? this.queryKey,
      queryFn ?? this.queryFn,
      enabled: enabled ?? this.enabled,
      expiresIn: expiresIn ?? this.expiresIn,
      gcDuration: gcDuration ?? this.gcDuration,
      placeholder: placeholder ?? this.placeholder,
      refetchInterval: refetchInterval ?? this.refetchInterval,
      refetchOnMount: refetchOnMount ?? this.refetchOnMount,
      refetchOnResume: refetchOnResume ?? this.refetchOnResume,
      retry: retry ?? this.retry,
      retryOnMount: retryOnMount ?? this.retryOnMount,
      seed: seed ?? this.seed,
      seedUpdatedAt: seedUpdatedAt ?? this.seedUpdatedAt,
    );
  }
}
