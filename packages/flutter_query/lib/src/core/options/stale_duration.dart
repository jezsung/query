import '../query.dart';

/// A callback that computes a [StaleDurationValue] based on the current query state.
///
/// This allows for dynamic stale durations that can vary based on query conditions
/// like error state, data content, or other factors.
typedef StaleDurationBuilder<TData, TError> = StaleDurationValue Function(
    Query<TData, TError> query);

/// Base type for all stale duration options.
///
/// This sealed class hierarchy allows specifying stale duration either as:
/// - A concrete [StaleDurationValue] (Duration, infinity, or static)
/// - A dynamic [StaleDurationProvider] that computes the duration at runtime
///
/// Class hierarchy:
/// ```
/// StaleDurationOption (sealed)
/// ├── StaleDurationValue (sealed)
/// │   ├── StaleDuration (extends Duration)
/// │   ├── StaleDurationInfinity
/// │   └── StaleDurationStatic
/// └── StaleDurationProvider<TData, TError>
/// ```
sealed class StaleDurationOption {
  StaleDurationValue resolve(Query query);
}

/// A concrete stale duration value (not a function).
///
/// This sealed class represents a resolved stale duration that can be used directly.
/// Subtypes include:
/// - [StaleDuration] - A specific time duration
/// - [StaleDurationInfinity] - Never becomes stale via time (unless manually invalidated)
/// - [StaleDurationStatic] - Never becomes stale (equivalent to TanStack's 'static')
sealed class StaleDurationValue implements StaleDurationOption {}

/// A time-based stale duration that specifies when query data becomes stale.
///
/// This class extends [Duration] to provide a concrete time period after which
/// query data is considered stale and eligible for refetching.
///
/// Aligned with TanStack Query's `staleTime` option when given a number value.
class StaleDuration extends Duration implements StaleDurationValue {
  /// Creates a stale duration with the specified time components.
  ///
  /// Data becomes stale after the specified duration has elapsed since the
  /// last successful fetch.
  ///
  /// This constructor matches [Duration]'s constructor signature for familiarity.
  ///
  /// Example:
  /// ```dart
  /// StaleDuration(minutes: 5)      // Stale after 5 minutes
  /// StaleDuration(seconds: 30)     // Stale after 30 seconds
  /// StaleDuration(hours: 1, minutes: 30)  // Stale after 1.5 hours
  /// ```
  const StaleDuration({
    super.days,
    super.hours,
    super.minutes,
    super.seconds,
    super.milliseconds,
    super.microseconds,
  });

  /// Zero duration - data is immediately stale after fetching.
  ///
  /// This is useful when you want queries to always refetch on mount or
  /// when they become active again.
  ///
  /// Aligned with TanStack Query's `staleTime: 0`.
  static const StaleDuration zero = StaleDuration(seconds: 0);

  /// Data never becomes stale via time-based staleness.
  ///
  /// The query data will remain fresh indefinitely unless manually invalidated.
  /// This is useful for data that rarely changes.
  ///
  /// Note: Can still be invalidated manually when invalidation is implemented.
  ///
  /// Aligned with TanStack Query's `staleTime: Infinity`.
  static const StaleDurationInfinity infinity = StaleDurationInfinity._();

  /// Data never becomes stale (equivalent to TanStack Query's 'static').
  ///
  /// Similar to [infinity], but semantically indicates that the data is
  /// truly static and should not be refetched under normal circumstances.
  ///
  /// Aligned with TanStack Query v5's experimental 'static' staleTime value.
  static const StaleDurationStatic static = StaleDurationStatic._();

  /// Creates a dynamic stale duration that computes based on query state.
  ///
  /// This factory method creates a [StaleDurationProvider] that evaluates
  /// the stale duration at runtime based on the current [Query] state.
  ///
  /// This is useful for implementing conditional staleness logic, such as:
  /// - Making failed queries stale immediately for quick retries
  /// - Varying staleness based on data content or size
  /// - Adjusting staleness based on time of day or other external factors
  ///
  /// The [callback] receives the current [Query] instance and must return
  /// a [StaleDurationValue] (StaleDuration, infinity, or static).
  ///
  /// Example:
  /// ```dart
  /// StaleDuration.resolveWith<User, Exception>((query) {
  ///   // If query has error, make it stale immediately for quick retry
  ///   if (query.state.error != null) {
  ///     return StaleDuration.zero;
  ///   }
  ///   // Otherwise, keep fresh for 10 minutes
  ///   return StaleDuration(minutes: 10);
  /// })
  /// ```
  ///
  /// Aligned with TanStack Query's function-based `staleTime` option.
  static StaleDurationProvider<TData, TError> resolveWith<TData, TError>(
    StaleDurationBuilder<TData, TError> callback,
  ) {
    return StaleDurationProvider<TData, TError>._(callback);
  }

  @override
  StaleDurationValue resolve(_) => this;
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
class StaleDurationInfinity implements StaleDurationValue {
  /// Private constructor to enforce usage via [StaleDuration.infinity].
  const StaleDurationInfinity._();

  @override
  StaleDurationValue resolve(_) => this;

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
class StaleDurationStatic implements StaleDurationValue {
  /// Private constructor to enforce usage via [StaleDuration.static].
  const StaleDurationStatic._();

  @override
  StaleDurationValue resolve(_) => this;

  /// All [StaleDurationStatic] instances are considered equal.
  @override
  bool operator ==(Object other) => other is StaleDurationStatic;

  /// Constant hash code since all instances are equal.
  @override
  int get hashCode => 0;
}

/// A dynamic stale duration that computes its value based on query state.
///
/// This class wraps a [StaleDurationBuilder] callback that is invoked at runtime
/// to determine the stale duration based on the current [Query] state.
///
/// Instances are created via [StaleDuration.resolveWith] factory method.
///
/// The provider evaluates the callback each time the stale duration is needed,
/// allowing for dynamic behavior such as:
/// - Different stale times based on success vs error states
/// - Conditional staleness based on data content
/// - Time-of-day dependent freshness windows
///
/// Aligned with TanStack Query's function-based `staleTime` option.
class StaleDurationProvider<TData, TError> implements StaleDurationOption {
  /// Private constructor - use [StaleDuration.resolveWith] to create instances.
  const StaleDurationProvider._(this._callback);

  /// The callback that computes the stale duration value.
  final StaleDurationBuilder<TData, TError> _callback;

  /// Resolves the stale duration by invoking the callback with the given [query].
  ///
  /// Returns a concrete [StaleDurationValue] that can be used for staleness checks.
  @override
  StaleDurationValue resolve(covariant Query<TData, TError> query) =>
      _callback(query);
}
