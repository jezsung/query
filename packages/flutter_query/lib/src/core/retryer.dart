import 'options/retry.dart';

/// Configuration for the [Retryer] class.
///
/// Specifies how retries should be handled for a query fetch operation.
///
/// Aligned with TanStack Query v5's retryer configuration.
class RetryerConfig<TData, TError> {
  /// Creates a retryer configuration.
  ///
  /// The [fn] is the async function to execute and retry on failure.
  /// The [retry] callback determines whether to retry and the delay.
  /// The [onFail] callback is invoked after each failed attempt.
  const RetryerConfig({
    required this.fn,
    required this.retry,
    this.onFail,
  });

  /// The async function to execute.
  ///
  /// This function will be called initially and after each failed retry attempt.
  final Future<TData> Function() fn;

  /// The retry callback that determines whether to retry and how long to wait.
  ///
  /// Returns `null` to stop retrying, or a [Duration] to wait before retrying.
  final Retry<TError> retry;

  /// Optional callback invoked after each failed attempt.
  ///
  /// Receives the current failure count (starting from 1 after the first failure)
  /// and the error that occurred.
  ///
  /// This is useful for updating state during retry attempts.
  final void Function(int failureCount, TError error)? onFail;
}

/// A retry engine that executes async functions with configurable retry logic.
///
/// The Retryer implements TanStack Query v5's retry behavior, executing
/// a function and automatically retrying on failure based on the provided
/// configuration.
///
/// Key features:
/// - Unified retry control via callback (decision + delay)
/// - Failure count tracking
/// - Cancellation support
/// - Lifecycle callbacks
///
/// Example:
/// ```dart
/// final retryer = Retryer<String, Exception>(
///   RetryerConfig(
///     fn: () async {
///       // Your async operation
///       return await fetchData();
///     },
///     retry: (retryCount, error) {
///       if (retryCount >= 3) return null; // Stop after 3 retries
///       return Duration(seconds: 1 << retryCount); // Exponential backoff
///     },
///     onFail: (failureCount, error) {
///       print('Attempt $failureCount failed: $error');
///     },
///   ),
/// );
///
/// try {
///   final result = await retryer.start();
///   print('Success: $result');
/// } catch (error) {
///   print('All retry attempts failed: $error');
/// }
/// ```
///
/// Aligned with TanStack Query's `retryer.ts` implementation.
class Retryer<TData, TError> {
  /// Creates a new retryer with the specified configuration.
  Retryer(this._config);

  /// The retryer configuration.
  final RetryerConfig<TData, TError> _config;

  /// Whether the retryer has been cancelled.
  bool _isCancelled = false;

  /// The current retry count.
  ///
  /// This starts at 0 and increments after each retry attempt.
  /// It's used to determine whether to retry and to calculate retry delays.
  int _retryCount = 0;

  /// Starts the retry loop and returns the result.
  ///
  /// This method executes the configured function and automatically retries
  /// on failure based on the retry configuration.
  ///
  /// The retry flow:
  /// 1. Execute the function
  /// 2. If successful, return the result
  /// 3. If failed:
  ///    a. Call retry callback to get delay (or null to stop)
  ///    b. If null, rethrow the error
  ///    c. Increment retry count and call onFail callback
  ///    d. Wait for the delay
  ///    e. Go back to step 1
  ///
  /// Throws:
  /// - [CancelledException] if the retryer was cancelled during retry
  /// - The original error if retry callback returns null
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   final result = await retryer.start();
  ///   // Handle success
  /// } catch (error) {
  ///   if (error is CancelledException) {
  ///     // Handle cancellation
  ///   } else {
  ///     // Handle final failure
  ///   }
  /// }
  /// ```
  Future<TData> start() async {
    // Retry loop - continues until success, cancellation, or retry returns null
    while (!_isCancelled) {
      try {
        // Execute the function
        return await _config.fn();
      } catch (error) {
        // If cancelled during execution, rethrow immediately
        if (_isCancelled) rethrow;

        // Cast error to TError - if it's not TError, rethrow
        if (error is! TError) rethrow;

        // Explicitly cast to TError after type check
        final typedError = error as TError;

        // Call retry callback to get delay (or null to stop)
        final delay = _config.retry(_retryCount, typedError);

        // If null, stop retrying and rethrow the error
        if (delay == null) rethrow;

        // Increment retry count for next attempt
        _retryCount++;

        // Notify failure callback with failureCount (1-indexed for QueryState)
        _config.onFail?.call(_retryCount, typedError);

        // Wait for retry delay
        await Future.delayed(delay);

        // Loop continues - will retry the function
      }
    }

    // If we exit the loop, it means we were cancelled
    throw const CancelledException();
  }

  /// Cancels the retry operation.
  ///
  /// If a retry is in progress, it will be cancelled and [start] will throw
  /// a [CancelledException].
  ///
  /// This is useful for cleanup when a query is disposed or when the user
  /// navigates away.
  ///
  /// Example:
  /// ```dart
  /// final retryer = Retryer<String, Exception>(config);
  ///
  /// // Start the retry operation
  /// final future = retryer.start();
  ///
  /// // Later, if needed, cancel it
  /// retryer.cancel();
  ///
  /// // The future will throw CancelledException
  /// try {
  ///   await future;
  /// } catch (error) {
  ///   if (error is CancelledException) {
  ///     print('Operation was cancelled');
  ///   }
  /// }
  /// ```
  void cancel() {
    _isCancelled = true;
  }
}

/// Exception thrown when a [Retryer] operation is cancelled.
///
/// This exception is thrown by [Retryer.start] when [Retryer.cancel] is called
/// during a retry operation.
///
/// Example:
/// ```dart
/// try {
///   await retryer.start();
/// } catch (error) {
///   if (error is CancelledException) {
///     // Handle cancellation
///     print('Retry was cancelled');
///   }
/// }
/// ```
class CancelledException implements Exception {
  /// Creates a cancelled exception.
  const CancelledException();

  @override
  String toString() => 'CancelledException: Retryer operation was cancelled';
}
