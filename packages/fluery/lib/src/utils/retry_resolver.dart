import 'package:async/async.dart';

typedef ErrorCallback = void Function(Object? error, int retried);

class RetryResolver<T> {
  RetryResolver(
    this.function, {
    this.maxCount = 3,
    this.delayDuration = const Duration(seconds: 3),
    this.onError,
  })  : assert(maxCount >= 1),
        assert(delayDuration >= Duration.zero);

  final Future<T> Function() function;
  final int maxCount;
  final Duration delayDuration;
  final ErrorCallback? onError;

  final CancelableCompleter<T> _completer = CancelableCompleter<T>();

  Future<T> call() async {
    for (int count = 1; count <= maxCount; count++) {
      try {
        final result = await function();
        _completer.complete(result);
        break;
      } catch (error) {
        onError?.call(error, count);

        if (count != maxCount) {
          await Future.delayed(delayDuration);
        }
      }
    }

    return _completer.operation.value;
  }

  Future<void> cancel() async {
    await _completer.operation.cancel();
  }
}
