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
typedef Retry<TError> = Duration? Function(int retryCount, TError error);
