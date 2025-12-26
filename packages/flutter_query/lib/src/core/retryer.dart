import 'abort_signal.dart';
import 'options/retry.dart';

/// A retry engine that executes async functions with configurable retry logic.
///
/// The Retryer implements TanStack Query v5's retry behavior, executing
/// a function and automatically retrying on failure based on the provided
/// configuration.
///
/// Key features:
/// - Unified retry control via callback (decision + delay)
/// - Failure count tracking
/// - Abort signal support
/// - Lifecycle callbacks
///
/// Example:
/// ```dart
/// final retryer = Retryer<String, Exception>(
///   fn: () async {
///     // Your async operation
///     return await fetchData();
///   },
///   retry: (retryCount, error) {
///     if (retryCount >= 3) return null; // Stop after 3 retries
///     return Duration(seconds: 1 << retryCount); // Exponential backoff
///   },
///   onFail: (failureCount, error) {
///     print('Attempt $failureCount failed: $error');
///   },
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
  /// Creates a new retryer.
  ///
  /// The [fn] is the async function to execute and retry on failure.
  /// The [retry] callback determines whether to retry and the delay.
  /// The [onFail] callback is invoked after each failed attempt.
  /// The [signal] allows external abort control.
  Retryer({
    required this.fn,
    required this.retry,
    this.onFail,
    this.signal,
  });

  /// The async function to execute.
  ///
  /// This function will be called initially and after each failed retry attempt.
  final Future<TData> Function() fn;

  /// The retry callback that determines whether to retry and how long to wait.
  ///
  /// Returns `null` to stop retrying, or a [Duration] to wait before retrying.
  final RetryResolver<TError> retry;

  /// Optional callback invoked after each failed attempt.
  ///
  /// Receives the current failure count (starting from 1 after the first failure)
  /// and the error that occurred.
  ///
  /// This is useful for updating state during retry attempts.
  final void Function(int failureCount, TError error)? onFail;

  /// Optional abort signal for external cancellation control.
  ///
  /// When the signal is aborted, the retryer will stop and throw
  /// [AbortedException].
  final AbortSignal? signal;

  /// The current retry count.
  ///
  /// This starts at 0 and increments after each retry attempt.
  /// It's used to determine whether to retry and to calculate retry delays.
  int _retryCount = 0;

  /// The cached future for this retryer's execution.
  Future<TData>? _future;

  /// The Future for this retryer's execution.
  ///
  /// Returns the same Future on subsequent calls, following the
  /// [Completer.future] pattern. If [start] hasn't been called yet,
  /// this will call it automatically.
  ///
  /// Aligned with TanStack Query's `Retryer.promise` property.
  Future<TData> get future => _future ?? start();

  /// Starts the retry loop and returns the future.
  ///
  /// Subsequent calls return the same future. This method executes the
  /// configured function and automatically retries on failure based on
  /// the retry configuration.
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
  /// - [AbortedException] if the operation was aborted via signal
  /// - The original error if retry callback returns null
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   final result = await retryer.start();
  ///   // Handle success
  /// } catch (error) {
  ///   if (error is AbortedException) {
  ///     // Handle abort
  ///   } else {
  ///     // Handle final failure
  ///   }
  /// }
  /// ```
  Future<TData> start() {
    return _future ??= _execute();
  }

  Future<TData> _execute() async {
    // Retry loop - continues until success, abort, or retry returns null
    while (true) {
      // Check if aborted via signal before starting
      if (signal != null && signal!.isAborted) {
        signal!.throwIfAborted();
      }

      try {
        // Execute the function
        return await fn();
      } on AbortedException {
        // AbortedException should be rethrown directly
        rethrow;
      } catch (error) {
        // Check if aborted via signal after execution
        if (signal != null && signal!.isAborted) {
          signal!.throwIfAborted();
        }

        // Cast error to TError - if it's not TError, rethrow
        if (error is! TError) rethrow;

        // Explicitly cast to TError after type check
        final typedError = error as TError;

        // Call retry callback to get delay (or null to stop)
        final delay = retry(_retryCount, typedError);

        // If null, stop retrying and rethrow the error
        if (delay == null) rethrow;

        // Increment retry count for next attempt
        _retryCount++;

        // Notify failure callback with failureCount (1-indexed for QueryState)
        onFail?.call(_retryCount, typedError);

        // Wait for retry delay, but abort immediately if signal fires
        if (signal != null) {
          await Future.any([
            Future.delayed(delay),
            signal!.whenAbort,
          ]);
          signal!.throwIfAborted();
        } else {
          await Future.delayed(delay);
        }

        // Loop continues - will retry the function
      }
    }
  }
}
