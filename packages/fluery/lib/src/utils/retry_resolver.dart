import 'dart:async';

import 'package:async/async.dart';
import 'package:fluery/src/utils/zoned_timer_interceptor.dart';

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
  final ZonedTimerInterceptor _zonedTimerInterceptor = ZonedTimerInterceptor();

  Future<T> call() async {
    for (int count = 1; count <= maxCount; count++) {
      try {
        final result = await function();
        _completer.complete(result);
        break;
      } catch (error) {
        onError?.call(error, count);

        if (count != maxCount) {
          await _zonedTimerInterceptor.run(() => Future.delayed(delayDuration));
        }
      }
    }

    return _completer.operation.value;
  }

  Future<void> cancel() async {
    _zonedTimerInterceptor.cancel();
    await _completer.operation.cancel();
  }
}
