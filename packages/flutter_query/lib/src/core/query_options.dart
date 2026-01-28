import 'default_query_options.dart';
import 'query_function_context.dart';
import 'query_key.dart';
import 'utils.dart';

/// Options for configuring a QueryObserver.
///
/// Contains all configuration that affects the QueryObserver instance,
/// including query identity, fetch behavior, and observer-specific settings.
class QueryObserverOptions<TData, TError> {
  QueryObserverOptions(
    List<Object?> queryKey,
    this.queryFn, {
    this.retry,
    this.gcDuration,
    this.seed,
    this.seedUpdatedAt,
    this.meta,
    this.enabled,
    this.staleDuration,
    this.placeholder,
    this.refetchOnMount,
    this.refetchOnResume,
    this.refetchInterval,
    this.retryOnMount,
  }) : queryKey = QueryKey(queryKey);

  final QueryKey queryKey;
  final QueryFn<TData> queryFn;
  final RetryResolver<TError>? retry;
  final GcDuration? gcDuration;
  final TData? seed;
  final DateTime? seedUpdatedAt;
  final Map<String, dynamic>? meta;
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

class GcDurationInfinity implements GcDuration {
  const GcDurationInfinity._();

  @override
  bool operator ==(Object other) => other is GcDurationInfinity;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'GcDuration.infinity';
}

/// Extension to add comparison operators for GcDurationValue.
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

  bool operator <(GcDuration other) => compareTo(other) < 0;
  bool operator <=(GcDuration other) => compareTo(other) <= 0;
  bool operator >(GcDuration other) => compareTo(other) > 0;
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

class StaleDurationInfinity implements StaleDuration {
  const StaleDurationInfinity._();

  @override
  bool operator ==(Object other) => other is StaleDurationInfinity;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'StaleDuration.infinity';
}

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
