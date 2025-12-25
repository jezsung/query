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
