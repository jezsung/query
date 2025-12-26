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

/// Never retries - returns null for any error.
///
/// This is the default retry behavior for mutations.
///
/// Example:
/// ```dart
/// retry: retryNever
/// ```
Duration? retryNever(int retryCount, Object? error) => null;

/// Creates an exponential backoff retry function.
///
/// Retries up to [maxRetries] times with exponential backoff delays.
/// The delay formula is: min(baseDelay * 2^retryCount, maxDelay).
///
/// Default configuration matches TanStack Query v5:
/// - 3 retries with delays of 1s, 2s, 4s (capped at 30s)
///
/// Parameters:
/// - [maxRetries]: Maximum number of retry attempts (default: 3)
/// - [baseDelay]: Base delay for the first retry (default: 1000ms)
/// - [maxDelay]: Maximum delay cap (default: 30 seconds)
///
/// Example:
/// ```dart
/// // Default: 3 retries with delays of 1s, 2s, 4s
/// retry: retryExponentialBackoff()
///
/// // Custom: 5 retries with 500ms base and 60s max
/// retry: retryExponentialBackoff(
///   maxRetries: 5,
///   baseDelay: Duration(milliseconds: 500),
///   maxDelay: Duration(seconds: 60),
/// )
/// ```
RetryResolver<TError> retryExponentialBackoff<TError>({
  int maxRetries = 3,
  Duration baseDelay = const Duration(seconds: 1),
  Duration maxDelay = const Duration(seconds: 30),
}) {
  return (int retryCount, TError error) {
    if (retryCount >= maxRetries) return null;
    final delayMs = baseDelay.inMilliseconds * (1 << retryCount);
    return Duration(milliseconds: delayMs.clamp(0, maxDelay.inMilliseconds));
  };
}
