/// A callback that computes a retry delay based on failure count and error.
///
/// This allows for dynamic retry delay logic that can vary based on the number of
/// failed attempts and the specific error that occurred.
///
/// The [failureCount] starts at 0 for the first failure and increments with
/// each subsequent retry attempt.
///
/// Example:
/// ```dart
/// // Exponential backoff with jitter
/// (failureCount, error) {
///   final baseDelay = Duration(milliseconds: 1000 * (1 << failureCount));
///   final jitter = Random().nextInt(1000);
///   return baseDelay + Duration(milliseconds: jitter);
/// }
/// ```
typedef RetryDelayBuilder<TError> = Duration Function(
  int failureCount,
  TError error,
);

/// Base type for all retry delay options.
///
/// This sealed class hierarchy allows specifying retry delay either as:
/// - A fixed [Duration]
/// - A dynamic callback that computes the delay at runtime
///
/// Aligned with TanStack Query v5's `retryDelay` option which accepts:
/// `number | (failureCount: number, error: TError) => number`
sealed class RetryDelay<TError> {
  const factory RetryDelay({
    int days,
    int hours,
    int minutes,
    int seconds,
    int milliseconds,
    int microseconds,
  }) = RetryDelayDuration._;

  const factory RetryDelay.exponentialBackoff() =
      RetryDelayExponentialBackoff._;

  const factory RetryDelay.resolveWith(RetryDelayBuilder<TError> callback) =
      RetryDelayResolver._;

  /// Computes the delay before the next retry attempt based on the failure
  /// count and the error that occurred.
  Duration resolve(int failureCount, TError error);
}

/// Fixed duration delay between retries.
///
/// The same delay will be used between all retry attempts.
///
/// Aligned with TanStack Query's `retryDelay: number` (milliseconds).
///
/// Example:
/// ```dart
/// // Wait 2 seconds between each retry
/// useQuery<String, Exception>(
///   queryKey: ['data'],
///   queryFn: fetchData,
///   retryDelay: RetryDelay.duration(Duration(seconds: 2)),
/// )
///
/// // Wait 500ms between retries
/// useQuery<String, Exception>(
///   queryKey: ['data'],
///   queryFn: fetchData,
///   retryDelay: RetryDelay.duration(Duration(milliseconds: 500)),
/// )
/// ```
class RetryDelayDuration<TError> extends Duration
    implements RetryDelay<TError> {
  const RetryDelayDuration._({
    super.days,
    super.hours,
    super.minutes,
    super.seconds,
    super.milliseconds,
    super.microseconds,
  });

  @override
  Duration resolve(int failureCount, TError error) => this;
}

/// Exponential backoff retry delay strategy.
///
/// This is the default retry delay strategy in TanStack Query.
///
/// The delay follows the formula: `min(1000 * 2^failureCount, 30000)` milliseconds
///
/// This results in the following delays:
/// - 1st retry: 1 second (2^0 * 1000ms)
/// - 2nd retry: 2 seconds (2^1 * 1000ms)
/// - 3rd retry: 4 seconds (2^2 * 1000ms)
/// - 4th retry: 8 seconds (2^3 * 1000ms)
/// - 5th retry: 16 seconds (2^4 * 1000ms)
/// - 6th+ retry: 30 seconds (capped at 30000ms)
///
/// Aligned with TanStack Query's default `retryDelay` implementation:
/// `Math.min(1000 * 2 ** failureCount, 30000)`
///
/// Example:
/// ```dart
/// useQuery<String, Exception>(
///   queryKey: ['data'],
///   queryFn: fetchData,
///   retry: const Retry.count(3),
///   retryDelay: const RetryDelay.exponentialBackoff(),  // Default behavior
/// )
/// ```
class RetryDelayExponentialBackoff<TError> implements RetryDelay<TError> {
  const RetryDelayExponentialBackoff._();

  @override
  Duration resolve(int failureCount, TError error) {
    // Calculate 2^failureCount using bit shift for efficiency
    // 1 << failureCount is equivalent to 2^failureCount
    final delayMs = 1000 * (1 << failureCount);

    // Cap at 30 seconds (30000ms)
    return Duration(milliseconds: delayMs > 30000 ? 30000 : delayMs);
  }

  @override
  bool operator ==(Object other) => other is RetryDelayExponentialBackoff;

  @override
  int get hashCode => 0;
}

/// Dynamic retry delay via callback function.
///
/// The [callback] receives the current failure count and the error that occurred,
/// and must return a [Duration] indicating how long to wait before retrying.
///
/// This allows for sophisticated delay logic based on:
/// - The number of failed attempts (e.g., exponential backoff)
/// - The type or content of the error
/// - Time of day, network conditions, or other external factors
///
/// Aligned with TanStack Query's function-based `retryDelay` option:
/// `retryDelay: (failureCount, error) => number` (milliseconds)
///
/// Example:
/// ```dart
/// // Different delays based on error type
/// useQuery<String, Exception>(
///   queryKey: ['data'],
///   queryFn: fetchData,
///   retryDelay: RetryDelay.resolveWith<Exception>((failureCount, error) {
///     // Network errors: use exponential backoff
///     if (error is NetworkException) {
///       final delayMs = 1000 * (1 << failureCount);
///       return Duration(milliseconds: min(delayMs, 30000));
///     }
///     // Other errors: fixed 5 second delay
///     return Duration(seconds: 5);
///   }),
/// )
///
/// // Linear backoff instead of exponential
/// useQuery<String, Exception>(
///   queryKey: ['data'],
///   queryFn: fetchData,
///   retryDelay: RetryDelay.resolveWith<Exception>((failureCount, error) {
///     return Duration(seconds: (failureCount + 1) * 2);  // 2s, 4s, 6s, 8s...
///   }),
/// )
///
/// // Add random jitter to exponential backoff
/// useQuery<String, Exception>(
///   queryKey: ['data'],
///   queryFn: fetchData,
///   retryDelay: RetryDelay.resolveWith<Exception>((failureCount, error) {
///     final baseDelay = 1000 * (1 << failureCount);
///     final jitter = Random().nextInt(1000);  // 0-1000ms jitter
///     return Duration(milliseconds: min(baseDelay + jitter, 30000));
///   }),
/// )
/// ```
class RetryDelayResolver<TError> implements RetryDelay<TError> {
  const RetryDelayResolver._(this.callback);

  /// The callback that computes the delay.
  final RetryDelayBuilder<TError> callback;

  @override
  Duration resolve(int failureCount, TError error) =>
      callback(failureCount, error);

  /// Implements equality for change detection in QueryObserver.
  ///
  /// For callback-based delays, equality is based on identity since we can't
  /// compare function implementations.
  @override
  bool operator ==(Object other) =>
      other is RetryDelayResolver<TError> &&
      identical(callback, other.callback);

  @override
  int get hashCode => identityHashCode(callback);
}
