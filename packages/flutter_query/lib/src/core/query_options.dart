import 'package:collection/collection.dart';

import 'default_query_options.dart';
import 'options/gc_duration.dart';
import 'options/placeholder_data.dart';
import 'options/refetch_on_mount.dart';
import 'options/refetch_on_resume.dart';
import 'options/retry.dart';
import 'options/stale_duration.dart';
import 'query_key.dart';
import 'types.dart';

/// Options for configuring a query.
///
/// Contains all the configuration options for a query including the query key,
/// query function, and various behavioral options like staleDuration, retry, etc.
class QueryOptions<TData, TError> {
  QueryOptions(
    this.queryKey,
    this.queryFn, {
    this.enabled,
    this.gcDuration,
    this.initialData,
    this.initialDataUpdatedAt,
    this.placeholderData,
    this.refetchInterval,
    this.refetchOnMount,
    this.refetchOnResume,
    this.retry,
    this.retryOnMount,
    this.staleDuration,
    this.staleDurationResolver,
  });

  final List<Object?> queryKey;
  final QueryFn<TData> queryFn;
  final GcDuration? gcDuration;
  final bool? enabled;
  final TData? initialData;
  final DateTime? initialDataUpdatedAt;
  final PlaceholderData<TData, TError>? placeholderData;
  final Duration? refetchInterval;
  final RefetchOnMount? refetchOnMount;
  final RefetchOnResume? refetchOnResume;
  final RetryResolver<TError>? retry;
  final bool? retryOnMount;
  final StaleDuration? staleDuration;
  final StaleDurationResolver<TData, TError>? staleDurationResolver;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QueryOptions<TData, TError> &&
        _equality.equals(queryKey, other.queryKey) &&
        identical(queryFn, other.queryFn) &&
        gcDuration == other.gcDuration &&
        enabled == other.enabled &&
        _equality.equals(initialData, other.initialData) &&
        initialDataUpdatedAt == other.initialDataUpdatedAt &&
        identical(placeholderData, other.placeholderData) &&
        refetchInterval == other.refetchInterval &&
        refetchOnMount == other.refetchOnMount &&
        refetchOnResume == other.refetchOnResume &&
        identical(retry, other.retry) &&
        retryOnMount == other.retryOnMount &&
        staleDuration == other.staleDuration &&
        identical(staleDurationResolver, other.staleDurationResolver);
  }

  @override
  int get hashCode => Object.hash(
        _equality.hash(queryKey),
        identityHashCode(queryFn),
        gcDuration,
        enabled,
        _equality.hash(initialData),
        initialDataUpdatedAt,
        identityHashCode(placeholderData),
        refetchInterval,
        refetchOnMount,
        refetchOnResume,
        identityHashCode(retry),
        retryOnMount,
        staleDuration,
        identityHashCode(staleDurationResolver),
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
      gcDuration: gcDuration ?? defaults.gcDuration,
      initialData: initialData,
      initialDataUpdatedAt: initialDataUpdatedAt,
      placeholderData: placeholderData,
      refetchInterval: refetchInterval ?? defaults.refetchInterval,
      refetchOnMount: refetchOnMount ?? defaults.refetchOnMount,
      refetchOnResume: refetchOnResume ?? defaults.refetchOnResume,
      retry: retry ?? defaults.retry as RetryResolver<TError>?,
      retryOnMount: retryOnMount ?? defaults.retryOnMount,
      staleDuration: staleDuration ?? defaults.staleDuration,
      staleDurationResolver: staleDurationResolver,
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
      gcDuration: switch ((options.gcDuration, gcDuration)) {
        (null, null) => null,
        (final a?, null) => a,
        (null, final b?) => b,
        (final a?, final b?) => a > b ? a : b,
      },
      initialData: switch ((options.initialData, initialData)) {
        (null, null) => null,
        (final TData a, null) => a,
        (null, final TData b) => b,
        (final TData a, final TData _) => a,
      },
      initialDataUpdatedAt: switch ((
        options.initialDataUpdatedAt,
        initialDataUpdatedAt
      )) {
        (null, null) => null,
        (final a?, null) => a,
        (null, final b?) => b,
        (final a?, final b?) => a.isBefore(b) ? a : b,
      },
      placeholderData: options.placeholderData ?? placeholderData,
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
      staleDuration: switch ((options.staleDuration, staleDuration)) {
        (null, null) => null,
        (final a?, null) => a,
        (null, final b?) => b,
        (StaleDurationStatic(), _) => StaleDuration.static,
        (_, StaleDurationStatic()) => StaleDuration.static,
        (StaleDurationInfinity(), _) => StaleDuration.infinity,
        (_, StaleDurationInfinity()) => StaleDuration.infinity,
        (StaleDurationDuration a, StaleDurationDuration b) => a < b ? a : b,
      },
      staleDurationResolver:
          options.staleDurationResolver ?? staleDurationResolver,
    );
  }
}

extension QueryOptionsCopyWith<TData, TError> on QueryOptions<TData, TError> {
  QueryOptions<TData, TError> copyWith({
    List<Object?>? queryKey,
    QueryFn<TData>? queryFn,
    bool? enabled,
    GcDuration? gcDuration,
    TData? initialData,
    DateTime? initialDataUpdatedAt,
    PlaceholderData<TData, TError>? placeholderData,
    Duration? refetchInterval,
    RefetchOnMount? refetchOnMount,
    RefetchOnResume? refetchOnResume,
    RetryResolver<TError>? retry,
    bool? retryOnMount,
    StaleDuration? staleDuration,
    StaleDurationResolver<TData, TError>? staleDurationResolver,
  }) {
    return QueryOptions<TData, TError>(
      queryKey ?? this.queryKey,
      queryFn ?? this.queryFn,
      enabled: enabled ?? this.enabled,
      gcDuration: gcDuration ?? this.gcDuration,
      initialData: initialData ?? this.initialData,
      initialDataUpdatedAt: initialDataUpdatedAt ?? this.initialDataUpdatedAt,
      placeholderData: placeholderData ?? this.placeholderData,
      refetchInterval: refetchInterval ?? this.refetchInterval,
      refetchOnMount: refetchOnMount ?? this.refetchOnMount,
      refetchOnResume: refetchOnResume ?? this.refetchOnResume,
      retry: retry ?? this.retry,
      retryOnMount: retryOnMount ?? this.retryOnMount,
      staleDuration: staleDuration ?? this.staleDuration,
      staleDurationResolver:
          staleDurationResolver ?? this.staleDurationResolver,
    );
  }
}
