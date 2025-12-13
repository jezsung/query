/// A concrete gc duration value.
sealed class GcDurationOption {}

/// Garbage collection duration configuration.
///
/// Controls how long unused/inactive cache data remains in memory before being
/// garbage collected. When a query's cache becomes unused or inactive, that
/// cache data will be garbage collected after this duration.
class GcDuration extends Duration implements GcDurationOption {
  /// Cache is garbage collected after the specified duration
  ///
  /// This is the default constructor matching Duration's constructor.
  ///
  /// Example:
  /// ```dart
  /// GcDuration(minutes: 5)  // Default in TanStack Query
  /// GcDuration(seconds: 30)
  /// GcDuration(hours: 1, minutes: 30)
  /// ```
  const GcDuration({
    super.days,
    super.hours,
    super.minutes,
    super.seconds,
    super.milliseconds,
    super.microseconds,
  });

  /// Zero duration - cache is garbage collected immediately when unused
  static const GcDuration zero = GcDuration(seconds: 0);

  /// Cache is never garbage collected.
  ///
  /// Equivalent to TanStack Query's `Infinity` gcTime value.
  /// Useful for data that should persist for the lifetime of the application.
  static const GcDurationInfinity infinity = GcDurationInfinity._();
}

/// Represents infinity - cache is never garbage collected.
class GcDurationInfinity implements GcDurationOption {
  const GcDurationInfinity._();

  @override
  bool operator ==(Object other) => other is GcDurationInfinity;

  @override
  int get hashCode => 0;
}

/// Extension to add comparison operators for GcDurationValue.
extension Comparison on GcDurationOption {
  /// Compares this GcDurationValue to another.
  ///
  /// Returns:
  /// - a negative value if this < other
  /// - zero if this == other
  /// - a positive value if this > other
  ///
  /// GcDurationInfinity is always greater than any GcDuration.
  int compareTo(GcDurationOption other) {
    return switch ((this, other)) {
      (GcDurationInfinity(), GcDurationInfinity()) => 0,
      (GcDurationInfinity(), GcDuration()) => 1,
      (GcDuration(), GcDurationInfinity()) => -1,
      (GcDuration a, GcDuration b) => a.compareTo(b),
    };
  }

  bool operator <(GcDurationOption other) => compareTo(other) < 0;
  bool operator <=(GcDurationOption other) => compareTo(other) <= 0;
  bool operator >(GcDurationOption other) => compareTo(other) > 0;
  bool operator >=(GcDurationOption other) => compareTo(other) >= 0;
}
