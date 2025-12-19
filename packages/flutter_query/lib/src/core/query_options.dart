import 'default_query_options.dart';
import 'options/gc_duration.dart';
import 'options/placeholder_data.dart';
import 'options/refetch_on_mount.dart';
import 'options/refetch_on_resume.dart';
import 'options/retry.dart';
import 'options/stale_duration.dart';
import 'query_context.dart';

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
  final Future<TData> Function(QueryContext context) queryFn;
  final GcDurationOption? gcDuration;
  final bool? enabled;
  final TData? initialData;
  final DateTime? initialDataUpdatedAt;
  final PlaceholderData<TData, TError>? placeholderData;
  final Duration? refetchInterval;
  final RefetchOnMount? refetchOnMount;
  final RefetchOnResume? refetchOnResume;
  final Retry<TError>? retry;
  final bool? retryOnMount;
  final StaleDuration? staleDuration;
  final StaleDurationResolver<TData, TError>? staleDurationResolver;

  /// Merges this QueryOptions with default options.
  ///
  /// Query-specific options take precedence over defaults.
  /// Handles type conversion for generic types (dynamic/Object? -> TData/TError).
  QueryOptions<TData, TError> mergeWith(DefaultQueryOptions defaults) {
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
      retry: retry ?? defaults.retry as Retry<TError>?,
      retryOnMount: retryOnMount ?? defaults.retryOnMount,
      staleDuration: staleDuration ?? defaults.staleDuration,
      staleDurationResolver: staleDurationResolver,
    );
  }

  /// Creates a copy of this QueryOptions with the given fields replaced.
  QueryOptions<TData, TError> copyWith({
    List<Object?>? queryKey,
    Future<TData> Function(QueryContext context)? queryFn,
    bool? enabled,
    GcDurationOption? gcDuration,
    TData? initialData,
    DateTime? initialDataUpdatedAt,
    PlaceholderData<TData, TError>? placeholderData,
    Duration? refetchInterval,
    RefetchOnMount? refetchOnMount,
    RefetchOnResume? refetchOnResume,
    Retry<TError>? retry,
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
