import 'default_query_options.dart';
import 'options/gc_duration.dart';
import 'options/placeholder_data.dart';
import 'options/refetch_on_mount.dart';
import 'options/refetch_on_resume.dart';
import 'options/retry.dart';
import 'options/retry_delay.dart';
import 'options/stale_duration.dart';
import 'query.dart';
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
    this.retryDelay,
    this.staleDuration,
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
  final RetryDelay<TError>? retryDelay;
  final StaleDuration<TData, TError>? staleDuration;

  /// Merges this QueryOptions with default options.
  ///
  /// Query-specific options take precedence over defaults.
  /// Handles type conversion for generic types (dynamic/Object? -> TData/TError).
  QueryOptions<TData, TError> mergeWith(DefaultQueryOptions defaults) {
    // Convert staleDuration from dynamic to TData
    StaleDuration<TData, TError>? defaultStaleDuration;
    final sd = defaults.staleDuration;
    if (sd != null) {
      defaultStaleDuration = switch (sd) {
        StaleDurationDuration() => StaleDuration<TData, TError>(
            microseconds: sd.inMicroseconds,
          ),
        StaleDurationInfinity() => StaleDuration<TData, TError>.infinity(),
        StaleDurationStatic() => StaleDuration<TData, TError>.static(),
        StaleDurationResolver() =>
          StaleDuration<TData, TError>.resolveWith((query) {
            final resolved = sd.resolve(query as Query<dynamic, Object?>);
            return switch (resolved) {
              StaleDurationDuration() => StaleDuration<TData, TError>(
                  microseconds: resolved.inMicroseconds,
                ),
              StaleDurationInfinity() =>
                StaleDuration<TData, TError>.infinity(),
              StaleDurationStatic() => StaleDuration<TData, TError>.static(),
            };
          }),
      };
    }

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
      retryDelay: retryDelay ?? defaults.retryDelay as RetryDelay<TError>?,
      staleDuration: staleDuration ?? defaultStaleDuration,
    );
  }
}
