import 'abort_signal.dart';
import 'options/retry.dart';

class Retryer<TData, TError> {
  Retryer({
    required this.fn,
    required this.retry,
    this.onFail,
    this.signal,
  });

  final Future<TData> Function() fn;
  final RetryResolver<TError> retry;
  final void Function(int failureCount, TError error)? onFail;
  final AbortSignal? signal;

  int _retryCount = 0;
  Future<TData>? _future;
  Future<TData> get future => _future ?? start();

  Future<TData> start() {
    return _future ??= _execute();
  }

  Future<TData> _execute() async {
    while (true) {
      if (signal != null && signal!.isAborted) {
        signal!.throwIfAborted();
      }

      try {
        return await fn();
      } on AbortedException {
        rethrow;
      } catch (error) {
        if (signal != null && signal!.isAborted) {
          signal!.throwIfAborted();
        }

        if (error is! TError) rethrow;

        final typedError = error as TError;

        final delay = retry(_retryCount, typedError);

        if (delay == null) rethrow;

        _retryCount++;

        onFail?.call(_retryCount, typedError);

        if (signal != null) {
          await Future.any([
            Future.delayed(delay),
            signal!.whenAbort,
          ]);
          signal!.throwIfAborted();
        } else {
          await Future.delayed(delay);
        }
      }
    }
  }
}
