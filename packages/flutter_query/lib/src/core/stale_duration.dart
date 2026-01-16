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
