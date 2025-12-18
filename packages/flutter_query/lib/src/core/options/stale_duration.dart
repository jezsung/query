import '../query.dart';

/// A callback that computes a [StaleDuration] based on the current query state.
///
/// This allows for dynamic stale durations that can vary based on query conditions
/// like error state, data content, or other factors.
///
/// The callback should return a concrete stale duration value (not a resolver).
typedef StaleDurationBuilder<TData, TError> = StaleDuration<TData, TError>
    Function(Query<TData, TError> query);

/// Base type for all stale duration options.
///
/// This sealed class hierarchy allows specifying stale duration either as:
/// - A concrete [StaleDurationValue] (Duration, infinity, or static)
/// - A dynamic [StaleDurationResolver] that computes the duration at runtime
///
/// Class hierarchy:
/// ```
/// StaleDuration<TData, TError> (sealed)
/// ├── StaleDurationValue<TData, TError> (sealed)
/// │   ├── StaleDurationDuration<TData, TError> (extends Duration)
/// │   ├── StaleDurationInfinity<TData, TError>
/// │   └── StaleDurationStatic<TData, TError>
/// └── StaleDurationResolver<TData, TError>
/// ```
///
/// Aligned with TanStack Query v5's `staleTime` option which accepts:
/// `number | Infinity | 'static' | (query) => number | Infinity | 'static'`
sealed class StaleDuration<TData, TError> {
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
  }) = StaleDurationDuration<TData, TError>._;

  /// Creates a zero-duration stale time (data is immediately stale).
  ///
  /// Equivalent to `const StaleDuration()` but more explicit.
  ///
  /// Aligned with TanStack Query's `staleTime: 0`.
  const factory StaleDuration.zero() =
      StaleDurationDuration<TData, TError>._zero;

  /// Data never becomes stale via time-based staleness.
  ///
  /// The query data will remain fresh indefinitely unless manually invalidated.
  /// This is useful for data that rarely changes.
  ///
  /// Note: Can still be invalidated manually when invalidation is implemented.
  ///
  /// Aligned with TanStack Query's `staleTime: Infinity`.
  const factory StaleDuration.infinity() =
      StaleDurationInfinity<TData, TError>._;

  /// Data never becomes stale (equivalent to TanStack Query's 'static').
  ///
  /// Similar to [StaleDuration.infinity], but semantically indicates that the data is
  /// truly static and should not be refetched under normal circumstances.
  ///
  /// Aligned with TanStack Query v5's experimental `staleTime: 'static'`.
  // ignore: library_private_types_in_public_api
  const factory StaleDuration.static() = StaleDurationStatic<TData, TError>._;

  /// Creates a dynamic stale duration that computes based on query state.
  ///
  /// This factory creates a [StaleDurationResolver] that evaluates
  /// the stale duration at runtime based on the current [Query] state.
  ///
  /// This is useful for implementing conditional staleness logic, such as:
  /// - Making failed queries stale immediately for quick retries
  /// - Varying staleness based on data content or size
  /// - Adjusting staleness based on time of day or other external factors
  ///
  /// The [callback] receives the current [Query] instance and must return
  /// a [StaleDurationValue] (StaleDurationDuration, infinity, or static).
  ///
  /// Example:
  /// ```dart
  /// StaleDuration.resolveWith((query) {
  ///   // If query has error, make it stale immediately for quick retry
  ///   if (query.state.error != null) {
  ///     return const StaleDuration();
  ///   }
  ///   // Otherwise, keep fresh for 10 minutes
  ///   return const StaleDuration(minutes: 10);
  /// })
  /// ```
  ///
  /// Aligned with TanStack Query's function-based `staleTime` option.
  const factory StaleDuration.resolveWith(
    StaleDurationBuilder<TData, TError> callback,
  ) = StaleDurationResolver<TData, TError>._;

  /// Resolves this stale duration option to a concrete [StaleDurationValue].
  ///
  /// For concrete values ([StaleDurationDuration], [StaleDurationInfinity],
  /// [StaleDurationStatic]), returns itself.
  /// For [StaleDurationResolver], invokes the callback with the given [query].
  StaleDurationValue<TData, TError> resolve(Query<TData, TError> query);
}

/// A concrete stale duration value (not a function).
///
/// This sealed class represents a resolved stale duration that can be used directly.
/// Subtypes include:
/// - [StaleDurationDuration] - A specific time duration
/// - [StaleDurationInfinity] - Never becomes stale via time (unless manually invalidated)
/// - [StaleDurationStatic] - Never becomes stale (equivalent to TanStack's 'static')
sealed class StaleDurationValue<TData, TError>
    implements StaleDuration<TData, TError> {}

/// A time-based stale duration that specifies when query data becomes stale.
///
/// This class extends [Duration] to provide a concrete time period after which
/// query data is considered stale and eligible for refetching.
///
/// Instances are created via the [StaleDuration] factory constructor.
///
/// Aligned with TanStack Query's `staleTime` option when given a number value.
class StaleDurationDuration<TData, TError> extends Duration
    implements StaleDurationValue<TData, TError> {
  /// Private constructor - use [StaleDuration()] to create instances.
  const StaleDurationDuration._({
    super.days,
    super.hours,
    super.minutes,
    super.seconds,
    super.milliseconds,
    super.microseconds,
  });

  /// Private zero constructor - use [StaleDuration.zero()] to create instances.
  const StaleDurationDuration._zero() : super();

  @override
  StaleDurationValue<TData, TError> resolve(_) => this;
}

/// Represents an infinite stale duration - data never becomes stale via time.
///
/// This class is used via [StaleDuration.infinity()] and indicates that query
/// data should remain fresh indefinitely unless manually invalidated.
///
/// This is a singleton-like class with value equality - all instances are
/// considered equal to each other.
///
/// Aligned with TanStack Query's `staleTime: Infinity`.
class StaleDurationInfinity<TData, TError>
    implements StaleDurationValue<TData, TError> {
  /// Private constructor - use [StaleDuration.infinity()] to create instances.
  const StaleDurationInfinity._();

  @override
  StaleDurationValue<TData, TError> resolve(_) => this;

  /// All [StaleDurationInfinity] instances are considered equal.
  @override
  bool operator ==(Object other) => other is StaleDurationInfinity;

  /// Constant hash code since all instances are equal.
  @override
  int get hashCode => 0;
}

/// Represents static data that never becomes stale.
///
/// This class is used via [StaleDuration.static()] and indicates that query
/// data is truly static and should not be refetched under normal circumstances.
///
/// Semantically similar to [StaleDurationInfinity], but explicitly conveys
/// that the data is unchanging rather than just having an infinite freshness window.
///
/// This is a singleton-like class with value equality - all instances are
/// considered equal to each other.
///
/// Aligned with TanStack Query v5's experimental `staleTime: 'static'` value.
class StaleDurationStatic<TData, TError>
    implements StaleDurationValue<TData, TError> {
  /// Private constructor - use [StaleDuration.static()] to create instances.
  const StaleDurationStatic._();

  @override
  StaleDurationValue<TData, TError> resolve(_) => this;

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
/// Instances are created via [StaleDuration.resolveWith] factory constructor.
///
/// The resolver evaluates the callback each time the stale duration is needed,
/// allowing for dynamic behavior such as:
/// - Different stale times based on success vs error states
/// - Conditional staleness based on data content
/// - Time-of-day dependent freshness windows
///
/// Aligned with TanStack Query's function-based `staleTime` option.
class StaleDurationResolver<TData, TError>
    implements StaleDuration<TData, TError> {
  /// Private constructor - use [StaleDuration.resolveWith] to create instances.
  const StaleDurationResolver._(this._callback);

  /// The callback that computes the stale duration value.
  final StaleDurationBuilder<TData, TError> _callback;

  /// Resolves the stale duration by invoking the callback with the given [query].
  ///
  /// Returns a concrete [StaleDurationValue] that can be used for staleness checks.
  /// If the callback returns another resolver, it will be recursively resolved.
  @override
  StaleDurationValue<TData, TError> resolve(Query<TData, TError> query) =>
      _callback(query).resolve(query);
}
