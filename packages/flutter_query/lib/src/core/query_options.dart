import 'package:meta/meta.dart';

import 'default_query_options.dart';
import 'network_mode.dart';
import 'query_function_context.dart';
import 'query_key.dart';
import 'utils.dart';

/// Options for configuring a QueryObserver.
///
/// Contains all configuration that affects the QueryObserver instance,
/// including query identity, fetch behavior, and observer-specific settings.
class QueryOptions<TData, TError> {
  /// Creates query options.
  QueryOptions(
    this.queryKey,
    this.queryFn, {
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
  });

  /// The key that uniquely identifies this query.
  final List<Object?> queryKey;

  /// The function that fetches data for this query.
  final QueryFn<TData> queryFn;

  /// Whether this query is enabled.
  final bool? enabled;

  /// The network connectivity mode for this query.
  final NetworkMode? networkMode;

  /// How long data is considered fresh before becoming stale.
  final StaleDuration? staleDuration;

  /// How long unused data remains in cache before garbage collection.
  final GcDuration? gcDuration;

  /// Placeholder data shown while the query is loading.
  final TData? placeholder;

  /// Whether to refetch when an observer mounts.
  final RefetchOnMount? refetchOnMount;

  /// Whether to refetch when the app resumes from background.
  final RefetchOnResume? refetchOnResume;

  /// Whether to refetch when network connectivity is restored.
  final RefetchOnReconnect? refetchOnReconnect;

  /// Interval at which to automatically refetch.
  final Duration? refetchInterval;

  /// Retry behavior for failed fetches.
  final RetryResolver<TError>? retry;

  /// Whether to retry a failed query when a new observer mounts.
  final bool? retryOnMount;

  /// Initial data to populate the cache before the first fetch.
  final TData? seed;

  /// The timestamp when the seed data was last updated.
  final DateTime? seedUpdatedAt;

  /// Arbitrary metadata associated with this query.
  final Map<String, dynamic>? meta;

  /// The internal QueryKey object for comparison.
  @internal
  QueryKey get key => QueryKey(queryKey);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueryOptions<TData, TError> &&
          key == other.key &&
          identical(queryFn, other.queryFn) &&
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
        key,
        identityHashCode(queryFn),
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
  String toString() => 'QueryOptions('
      'queryKey: $queryKey, '
      'enabled: $enabled, '
      'networkMode: $networkMode, '
      'staleDuration: $staleDuration, '
      'gcDuration: $gcDuration, '
      'placeholder: $placeholder, '
      'refetchOnMount: $refetchOnMount, '
      'refetchOnResume: $refetchOnResume, '
      'refetchOnReconnect: $refetchOnReconnect, '
      'refetchInterval: $refetchInterval, '
      'retry: $retry, '
      'retryOnMount: $retryOnMount, '
      'seed: $seed, '
      'seedUpdatedAt: $seedUpdatedAt, '
      'meta: $meta)';
}

/// Extension methods for [QueryOptions].
extension QueryOptionsExt<TData, TError> on QueryOptions<TData, TError> {
  /// Returns a copy of these options with values from [defaults] applied.
  QueryOptions<TData, TError> withDefaults(
    DefaultQueryOptions defaults,
  ) {
    return QueryOptions<TData, TError>(
      queryKey,
      queryFn,
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
}

/// Function that fetches data for a query.
///
/// The function receives a [QueryFunctionContext].
typedef QueryFn<TData> = Future<TData> Function(QueryFunctionContext context);

/// Controls how long unused cache data remains in memory before being garbage
/// collected.
///
/// When a query's cache becomes unused, that cache data will be garbage
/// collected after this duration.
///
/// Class hierarchy:
/// ```
/// GcDuration (sealed)
/// ├── GcDurationDuration (extends Duration)
/// └── GcDurationInfinity
/// ```
sealed class GcDuration {
  /// Cache is garbage collected after the specified duration.
  ///
  /// This is the default constructor matching Duration's constructor.
  ///
  /// Example:
  /// ```dart
  /// GcDuration(minutes: 5)
  /// GcDuration(seconds: 30)
  /// GcDuration(hours: 1, minutes: 30)
  /// ```
  const factory GcDuration({
    int days,
    int hours,
    int minutes,
    int seconds,
    int milliseconds,
    int microseconds,
  }) = GcDurationDuration._;

  /// Zero duration - cache is garbage collected immediately when unused.
  ///
  /// Equivalent to `const GcDuration()` but more explicit.
  static const GcDuration zero = GcDurationDuration._(seconds: 0);

  /// Cache is never garbage collected.
  ///
  /// The query data will remain in memory indefinitely.
  /// This is useful for data that should persist for the lifetime of the
  /// application.
  static const GcDuration infinity = GcDurationInfinity._();
}

@internal
class GcDurationDuration extends Duration implements GcDuration {
  const GcDurationDuration._({
    super.days,
    super.hours,
    super.minutes,
    super.seconds,
    super.milliseconds,
    super.microseconds,
  });
}

@internal
class GcDurationInfinity implements GcDuration {
  const GcDurationInfinity._();

  @override
  bool operator ==(Object other) => other is GcDurationInfinity;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'GcDuration.infinity';
}

@internal
extension GcDurationComparision on GcDuration {
  /// Compares this GcDurationValue to another.
  ///
  /// Returns:
  /// - a negative value if this < other
  /// - zero if this == other
  /// - a positive value if this > other
  ///
  /// GcDurationInfinity is always greater than any GcDurationDuration.
  int compareTo(GcDuration other) {
    return switch ((this, other)) {
      (GcDurationInfinity(), GcDurationInfinity()) => 0,
      (GcDurationInfinity(), GcDurationDuration()) => 1,
      (GcDurationDuration(), GcDurationInfinity()) => -1,
      (GcDurationDuration a, GcDurationDuration b) => a.compareTo(b),
    };
  }

  /// Whether this duration is less than [other].
  bool operator <(GcDuration other) => compareTo(other) < 0;

  /// Whether this duration is less than or equal to [other].
  bool operator <=(GcDuration other) => compareTo(other) <= 0;

  /// Whether this duration is greater than [other].
  bool operator >(GcDuration other) => compareTo(other) > 0;

  /// Whether this duration is greater than or equal to [other].
  bool operator >=(GcDuration other) => compareTo(other) >= 0;
}

/// Controls how long query data is considered fresh before becoming stale.
///
/// When data becomes stale, it may be refetched on the next access depending
/// on the refetch configuration.
///
/// Class hierarchy:
/// ```
/// StaleDuration (sealed)
/// ├── StaleDurationValue (extends Duration)
/// ├── StaleDurationInfinity
/// └── StaleDurationStatic
/// ```
sealed class StaleDuration {
  /// Data becomes stale after the specified duration has elapsed since the
  /// last data update.
  ///
  /// This is the default constructor matching Duration's constructor.
  ///
  /// Example:
  /// ```dart
  /// StaleDuration(minutes: 5)             // Stale after 5 minutes
  /// StaleDuration(seconds: 30)            // Stale after 30 seconds
  /// StaleDuration(hours: 1, minutes: 30)  // Stale after 1.5 hours
  /// ```
  const factory StaleDuration({
    int days,
    int hours,
    int minutes,
    int seconds,
    int milliseconds,
    int microseconds,
  }) = StaleDurationValue._;

  /// Zero-duration staleness (data is immediately stale).
  ///
  /// Equivalent to `const StaleDuration()` but more explicit.
  static const StaleDuration zero = StaleDurationValue._();

  /// Data never becomes stale via time-based staleness.
  ///
  /// The query data will remain fresh indefinitely unless manually invalidated.
  /// This is useful for data that rarely changes.
  static const StaleDuration infinity = StaleDurationInfinity._();

  /// Data never becomes stale, even on manual cache invalidation.
  ///
  /// Similar to [StaleDuration.infinity], but indicates that the data is
  /// truly static and should not be refetched under any circumstances.
  static const StaleDuration static = StaleDurationStatic._();
}

@internal
class StaleDurationValue extends Duration implements StaleDuration {
  const StaleDurationValue._({
    super.days,
    super.hours,
    super.minutes,
    super.seconds,
    super.milliseconds,
    super.microseconds,
  });
}

@internal
class StaleDurationInfinity implements StaleDuration {
  const StaleDurationInfinity._();

  @override
  bool operator ==(Object other) => other is StaleDurationInfinity;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'StaleDuration.infinity';
}

@internal
class StaleDurationStatic implements StaleDuration {
  const StaleDurationStatic._();

  @override
  bool operator ==(Object other) => other is StaleDurationStatic;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'StaleDuration.static';
}

/// Controls refetch behavior when an observer mounts.
///
/// Determines whether a query should be refetched when a new observer
/// subscribes to the query.
enum RefetchOnMount {
  /// Refetch only if the cached data is stale.
  ///
  /// The query refetches only when the data is stale, respecting the configured
  /// stale duration option.
  stale,

  /// Never refetch on mount.
  ///
  /// The query will refetch every time an observer mounts, even if the cached
  /// data is stale. Useful when you want to minimize network requests and are
  /// okay with potentially outdated data.
  never,

  /// Always refetch on mount.
  ///
  /// The query will refetch every time an observer mounts, even if the cached
  /// data is still fresh. Useful for data that must always be up-to-date.
  always,
}

/// Controls refetch behavior when the app resumes from background.
///
/// Determines whether queries should be refetched when the application
/// returns to the foreground after being in the background.
enum RefetchOnResume {
  /// Refetch only if the cached data is stale.
  ///
  /// The query refetches only when the data is stale, respecting the configured
  /// stale duration option.
  stale,

  /// Never refetch on resume.
  ///
  /// Queries will not refetch when the app resumes, regardless of staleness.
  /// Useful for reducing unnecessary network requests when background time
  /// is typically short.
  never,

  /// Always refetch on resume.
  ///
  /// Queries will refetch when the app resumes, even if their data is still
  /// fresh. Useful for data that may have changed while the app was in the
  /// background.
  always,
}

/// Controls refetch behavior when network connectivity is restored.
///
/// Determines whether queries should be refetched when the device
/// reconnects to the network after being offline.
///
/// Note: Requires [connectivityChanges] to be provided to [QueryClient].
/// If not provided, this option has no effect.
enum RefetchOnReconnect {
  /// Refetch only if the cached data is stale.
  ///
  /// The query refetches only when the data is stale, respecting the configured
  /// stale duration option.
  stale,

  /// Never refetch on reconnect.
  ///
  /// Queries will not refetch when connectivity is restored, regardless of
  /// staleness. Useful for data that doesn't depend on network freshness.
  never,

  /// Always refetch on reconnect.
  ///
  /// Queries will refetch when connectivity is restored, even if their data
  /// is still fresh. Useful for data that may have changed while offline.
  always,
}

/// A callback that determines whether to retry and how long to wait.
///
/// This provides unified control over retry behavior by combining the retry
/// decision and delay into a single callback.
///
/// The [retryCount] starts at 0 for the first retry decision (after the initial
/// failure) and increments with each subsequent retry attempt.
///
/// Returns:
/// - `null` to stop retrying and propagate the error
/// - `Duration` to retry after waiting that duration
///
/// Example:
/// ```dart
/// // Retry 3 times with exponential backoff
/// retry: (retryCount, error) {
///   if (retryCount >= 3) return null; // Stop after 3 retries
///   return Duration(seconds: 1 << retryCount); // 1s, 2s, 4s
/// }
///
/// // Retry only for specific error types
/// retry: (retryCount, error) {
///   if (retryCount >= 5) return null;
///   if (error is NetworkException) {
///     return Duration(seconds: 1 << retryCount);
///   }
///   return null; // Don't retry other errors
/// }
///
/// // No retries
/// retry: (retryCount, error) => null
/// ```
typedef RetryResolver<TError> = Duration? Function(
  int retryCount,
  TError error,
);
