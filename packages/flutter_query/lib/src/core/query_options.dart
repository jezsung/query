import 'default_query_options.dart';
import 'query_function_context.dart';
import 'query_key.dart';
import 'utils.dart';

part 'query_observer_options.dart';

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

/// Function that fetches data for a query.
///
/// The function receives a [QueryFunctionContext].
typedef QueryFn<TData> = Future<TData> Function(QueryFunctionContext context);

/// A concrete gc duration value.
sealed class GcDuration {
  /// Cache is garbage collected after the specified duration.
  ///
  /// This is the default constructor matching Duration's constructor.
  ///
  /// Example:
  /// ```dart
  /// GcDuration(minutes: 5)  // Default in TanStack Query
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

  /// Zero duration - cache is garbage collected immediately when unused
  static const GcDuration zero = GcDurationDuration._(seconds: 0);

  /// Cache is never garbage collected.
  ///
  /// Equivalent to TanStack Query's `Infinity` gcTime value.
  /// Useful for data that should persist for the lifetime of the application.
  static const GcDuration infinity = GcDurationInfinity._();
}

/// Garbage collection duration configuration.
///
/// Controls how long unused/inactive cache data remains in memory before being
/// garbage collected. When a query's cache becomes unused or inactive, that
/// cache data will be garbage collected after this duration.
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

/// Represents infinity - cache is never garbage collected.
class GcDurationInfinity implements GcDuration {
  const GcDurationInfinity._();

  @override
  bool operator ==(Object other) => other is GcDurationInfinity;

  @override
  int get hashCode => 0;
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

/// Base type for all stale duration options.
///
/// This sealed class hierarchy allows specifying data staleness either as:
/// - A concrete [StaleDurationValue] (time-based Duration)
/// - [StaleDurationInfinity] (never becomes stale via time)
/// - [StaleDurationStatic] (truly static data)
///
/// Class hierarchy:
/// ```
/// StaleDuration (sealed)
/// ├── StaleDurationValue (extends Duration)
/// ├── StaleDurationInfinity
/// └── StaleDurationStatic
/// ```
///
/// For dynamic staleness based on query state, use the separate
/// `staleDurationResolver` parameter instead.
///
/// Aligned with TanStack Query v5's `staleTime` option which accepts:
/// `number | Infinity | 'static'` for values, or a function for dynamic resolution.
sealed class StaleDuration {
  /// Creates a time-based stale duration with the specified time components.
  ///
  /// Data becomes stale after the specified duration has elapsed since the
  /// last successful fetch.
  ///
  /// Example:
  /// ```dart
  /// StaleDuration(minutes: 5)      // Stale after 5 minutes
  /// StaleDuration(seconds: 30)     // Stale after 30 seconds
  /// StaleDuration(hours: 1, minutes: 30)  // Stale after 1.5 hours
  /// ```
  ///
  /// Aligned with TanStack Query's `staleTime: number`.
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
  ///
  /// Aligned with TanStack Query's `staleTime: 0`.
  static const StaleDuration zero = StaleDurationValue._();

  /// Data never becomes stale via time-based staleness.
  ///
  /// The query data will remain fresh indefinitely unless manually invalidated.
  /// This is useful for data that rarely changes.
  ///
  /// Note: Can still be invalidated manually when invalidation is implemented.
  ///
  /// Aligned with TanStack Query's `staleTime: Infinity`.
  static const StaleDuration infinity = StaleDurationInfinity._();

  /// Data never becomes stale (equivalent to TanStack Query's 'static').
  ///
  /// Similar to [StaleDuration.infinity], but semantically indicates that the data is
  /// truly static and should not be refetched under normal circumstances.
  ///
  /// Aligned with TanStack Query v5's experimental `staleTime: 'static'`.
  // ignore: library_private_types_in_public_api
  static const StaleDuration static = StaleDurationStatic._();
}

/// A time-based stale duration that specifies when query data becomes stale.
///
/// This class extends [Duration] to provide a concrete time period after which
/// query data is considered stale and eligible for refetching.
///
/// Instances are created via the [StaleDuration] factory constructor.
///
/// Aligned with TanStack Query's `staleTime` option when given a number value.
class StaleDurationValue extends Duration implements StaleDuration {
  /// Private constructor - use [StaleDuration()] to create instances.
  const StaleDurationValue._({
    super.days,
    super.hours,
    super.minutes,
    super.seconds,
    super.milliseconds,
    super.microseconds,
  });
}

/// Represents an infinite stale duration - data never becomes stale via time.
///
/// This class is used via [StaleDuration.infinity] and indicates that query
/// data should remain fresh indefinitely unless manually invalidated.
///
/// This is a singleton-like class with value equality - all instances are
/// considered equal to each other.
///
/// Aligned with TanStack Query's `staleTime: Infinity`.
class StaleDurationInfinity implements StaleDuration {
  /// Private constructor - use [StaleDuration.infinity] to access the instance.
  const StaleDurationInfinity._();

  /// All [StaleDurationInfinity] instances are considered equal.
  @override
  bool operator ==(Object other) => other is StaleDurationInfinity;

  /// Constant hash code since all instances are equal.
  @override
  int get hashCode => 0;
}

/// Represents static data that never becomes stale.
///
/// This class is used via [StaleDuration.static] and indicates that query
/// data is truly static and should not be refetched under normal circumstances.
///
/// Semantically similar to [StaleDurationInfinity], but explicitly conveys
/// that the data is unchanging rather than just having an infinite freshness window.
///
/// This is a singleton-like class with value equality - all instances are
/// considered equal to each other.
///
/// Aligned with TanStack Query v5's experimental `staleTime: 'static'` value.
class StaleDurationStatic implements StaleDuration {
  /// Private constructor - use [StaleDuration.static] to access the instance.
  const StaleDurationStatic._();

  /// All [StaleDurationStatic] instances are considered equal.
  @override
  bool operator ==(Object other) => other is StaleDurationStatic;

  /// Constant hash code since all instances are equal.
  @override
  int get hashCode => 0;
}

/// Controls refetch behavior when an observer mounts.
enum RefetchOnMount { stale, never, always }

/// Controls refetch behavior when the app resumes from background.
enum RefetchOnResume { stale, never, always }

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

extension QueryOptionsExt<TData, TError> on QueryOptions<TData, TError> {
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
