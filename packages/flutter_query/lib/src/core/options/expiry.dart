/// Base type for all expiry options.
///
/// This sealed class hierarchy allows specifying data expiry either as:
/// - A concrete [ExpiryDuration] (time-based Duration)
/// - [ExpiryInfinity] (never expires via time)
/// - [ExpiryNever] (truly static data)
///
/// Class hierarchy:
/// ```
/// Expiry (sealed)
/// ├── ExpiryDuration (extends Duration)
/// ├── ExpiryInfinity
/// └── ExpiryNever
/// ```
///
/// For dynamic expiry based on query state, use the separate
/// `expiresInResolver` parameter instead.
///
/// Aligned with TanStack Query v5's `staleTime` option which accepts:
/// `number | Infinity | 'static'` for values, or a function for dynamic resolution.
sealed class Expiry {
  /// Creates a time-based expiry with the specified time components.
  ///
  /// Data becomes stale after the specified duration has elapsed since the
  /// last successful fetch.
  ///
  /// Example:
  /// ```dart
  /// Expiry(minutes: 5)      // Stale after 5 minutes
  /// Expiry(seconds: 30)     // Stale after 30 seconds
  /// Expiry(hours: 1, minutes: 30)  // Stale after 1.5 hours
  /// ```
  ///
  /// Aligned with TanStack Query's `staleTime: number`.
  const factory Expiry({
    int days,
    int hours,
    int minutes,
    int seconds,
    int milliseconds,
    int microseconds,
  }) = ExpiryDuration._;

  /// Zero-duration expiry (data is immediately stale).
  ///
  /// Equivalent to `const Expiry()` but more explicit.
  ///
  /// Aligned with TanStack Query's `staleTime: 0`.
  static const Expiry zero = ExpiryDuration._();

  /// Data never becomes stale via time-based staleness.
  ///
  /// The query data will remain fresh indefinitely unless manually invalidated.
  /// This is useful for data that rarely changes.
  ///
  /// Note: Can still be invalidated manually when invalidation is implemented.
  ///
  /// Aligned with TanStack Query's `staleTime: Infinity`.
  static const Expiry infinity = ExpiryInfinity._();

  /// Data never becomes stale (equivalent to TanStack Query's 'static').
  ///
  /// Similar to [Expiry.infinity], but semantically indicates that the data is
  /// truly static and should not be refetched under normal circumstances.
  ///
  /// Aligned with TanStack Query v5's experimental `staleTime: 'static'`.
  // ignore: library_private_types_in_public_api
  static const Expiry never = ExpiryNever._();
}

/// A time-based expiry that specifies when query data becomes stale.
///
/// This class extends [Duration] to provide a concrete time period after which
/// query data is considered stale and eligible for refetching.
///
/// Instances are created via the [Expiry] factory constructor.
///
/// Aligned with TanStack Query's `staleTime` option when given a number value.
class ExpiryDuration extends Duration implements Expiry {
  /// Private constructor - use [Expiry()] to create instances.
  const ExpiryDuration._({
    super.days,
    super.hours,
    super.minutes,
    super.seconds,
    super.milliseconds,
    super.microseconds,
  });
}

/// Represents an infinite expiry - data never becomes stale via time.
///
/// This class is used via [Expiry.infinity] and indicates that query
/// data should remain fresh indefinitely unless manually invalidated.
///
/// This is a singleton-like class with value equality - all instances are
/// considered equal to each other.
///
/// Aligned with TanStack Query's `staleTime: Infinity`.
class ExpiryInfinity implements Expiry {
  /// Private constructor - use [Expiry.infinity] to access the instance.
  const ExpiryInfinity._();

  /// All [ExpiryInfinity] instances are considered equal.
  @override
  bool operator ==(Object other) => other is ExpiryInfinity;

  /// Constant hash code since all instances are equal.
  @override
  int get hashCode => 0;
}

/// Represents static data that never becomes stale.
///
/// This class is used via [Expiry.never] and indicates that query
/// data is truly static and should not be refetched under normal circumstances.
///
/// Semantically similar to [ExpiryInfinity], but explicitly conveys
/// that the data is unchanging rather than just having an infinite freshness window.
///
/// This is a singleton-like class with value equality - all instances are
/// considered equal to each other.
///
/// Aligned with TanStack Query v5's experimental `staleTime: 'static'` value.
class ExpiryNever implements Expiry {
  /// Private constructor - use [Expiry.never] to access the instance.
  const ExpiryNever._();

  /// All [ExpiryNever] instances are considered equal.
  @override
  bool operator ==(Object other) => other is ExpiryNever;

  /// Constant hash code since all instances are equal.
  @override
  int get hashCode => 0;
}
