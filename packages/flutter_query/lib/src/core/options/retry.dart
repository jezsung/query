/// A callback that determines whether to retry based on failure count and error.
///
/// This allows for dynamic retry logic that can vary based on the number of
/// failed attempts and the specific error that occurred.
///
/// The [failureCount] starts at 0 for the first failure and increments with
/// each subsequent retry attempt.
///
/// Example:
/// ```dart
/// // Retry only for specific error types
/// (failureCount, error) {
///   if (error is NetworkException) return failureCount < 5;
///   if (error is TimeoutException) return failureCount < 2;
///   return false;
/// }
/// ```
typedef RetryBuilder<TError> = bool Function(int failureCount, TError error);

/// Base type for all retry options.
///
/// This sealed class hierarchy allows specifying retry behavior either as:
/// - A concrete value (never, always, or a specific count)
/// - A dynamic callback that computes the retry decision at runtime
///
/// Aligned with TanStack Query v5's `retry` option which accepts:
/// `boolean | number | (failureCount: number, error: TError) => boolean`
sealed class Retry<TError> {
  const factory Retry.never() = RetryNever._;

  const factory Retry.always() = RetryAlways._;

  const factory Retry.count(int count) = RetryCount._;

  const factory Retry.resolveWith(RetryBuilder<TError> callback) =
      RetryResolver._;

  /// Determines whether a retry should be attempted based on the failure count
  /// and the error that occurred.
  bool shouldRetry(int failureCount, TError error);
}

/// Never retry (0 attempts).
///
/// Use this when you want queries to fail immediately without any retry attempts.
///
/// Aligned with TanStack Query's `retry: false` or `retry: 0`.
///
/// Example:
/// ```dart
/// useQuery<String, Exception>(
///   queryKey: ['user'],
///   queryFn: fetchUser,
///   retry: Retry.never(),
/// )
/// ```
class RetryNever<TError> implements Retry<TError> {
  const RetryNever._();

  @override
  bool shouldRetry(int failureCount, TError error) => false;

  @override
  bool operator ==(Object other) => other is RetryNever;

  @override
  int get hashCode => 0;
}

/// Always retry (infinite retries).
///
/// Use this when you want queries to keep retrying until they succeed.
/// Be cautious with this option as it may lead to infinite loops if the
/// error condition never resolves.
///
/// Aligned with TanStack Query's `retry: true`.
///
/// Example:
/// ```dart
/// useQuery<String, Exception>(
///   queryKey: ['status'],
///   queryFn: checkStatus,
///   retry: Retry.always(),
/// )
/// ```
class RetryAlways<TError> implements Retry<TError> {
  const RetryAlways._();

  @override
  bool shouldRetry(int failureCount, TError error) => true;

  @override
  bool operator ==(Object other) => other is RetryAlways;

  @override
  int get hashCode => 1;
}

/// Retry up to a specific count.
///
/// The [count] parameter specifies the maximum number of retry attempts
/// before the query fails permanently.
///
/// Aligned with TanStack Query's `retry: number` (e.g., `retry: 3`).
///
/// Example:
/// ```dart
/// // Retry up to 3 times (TanStack Query default)
/// useQuery<String, Exception>(
///   queryKey: ['data'],
///   queryFn: fetchData,
///   retry: Retry.count(3),
/// )
///
/// // No retries
/// useQuery<String, Exception>(
///   queryKey: ['data'],
///   queryFn: fetchData,
///   retry: Retry.count(0),  // Equivalent to Retry.never()
/// )
/// ```
class RetryCount<TError> implements Retry<TError> {
  const RetryCount._(this.count);

  /// The maximum number of retry attempts.
  final int count;

  @override
  bool shouldRetry(int failureCount, TError error) => failureCount < count;

  @override
  bool operator ==(Object other) => other is RetryCount && other.count == count;

  @override
  int get hashCode => count.hashCode;
}

/// Dynamic retry logic via callback function.
///
/// The [callback] receives the current failure count and the error that occurred,
/// and must return a boolean indicating whether to retry.
///
/// This allows for sophisticated retry logic based on:
/// - The number of failed attempts
/// - The type or content of the error
/// - External state or conditions
///
/// Aligned with TanStack Query's function-based `retry` option:
/// `retry: (failureCount, error) => boolean`
///
/// Example:
/// ```dart
/// // Retry network errors up to 5 times, other errors up to 2 times
/// useQuery<String, Exception>(
///   queryKey: ['data'],
///   queryFn: fetchData,
///   retry: Retry.resolveWith<Exception>((failureCount, error) {
///     if (error is NetworkException) return failureCount < 5;
///     return failureCount < 2;
///   }),
/// )
///
/// // Don't retry validation errors, but retry others
/// useQuery<String, Exception>(
///   queryKey: ['data'],
///   queryFn: fetchData,
///   retry: Retry.resolveWith<Exception>((failureCount, error) {
///     if (error is ValidationException) return false;
///     return failureCount < 3;
///   }),
/// )
/// ```
class RetryResolver<TError> implements Retry<TError> {
  const RetryResolver._(this.callback);

  /// The callback that determines whether to retry.
  final RetryBuilder<TError> callback;

  @override
  bool shouldRetry(int failureCount, TError error) =>
      callback(failureCount, error);

  /// Implements equality for change detection in QueryObserver.
  ///
  /// For callback-based retry, equality is based on identity since we can't
  /// compare function implementations.
  @override
  bool operator ==(Object other) =>
      other is RetryResolver<TError> && identical(callback, other.callback);

  @override
  int get hashCode => identityHashCode(callback);
}
