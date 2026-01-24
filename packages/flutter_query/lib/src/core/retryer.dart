import 'dart:async';

import 'package:meta/meta.dart';

import 'query_options.dart';

@internal
class Retryer<TData, TError> {
  Retryer(
    this.fn,
    this.retry, {
    this.onFail,
  });

  final Future<TData> Function() fn;
  final RetryResolver<TError> retry;
  final void Function(int failureCount, TError error)? onFail;

  int _retryCount = 0;
  bool _isCancelled = false;
  Completer<TData>? _completer;

  Future<TData> get future {
    if (_completer == null) {
      throw StateError('Retryer is not running');
    }
    return _completer!.future;
  }

  Future<TData> run() {
    if (_completer != null) return _completer!.future;

    _completer = Completer<TData>();
    unawaited(_execute());

    return _completer!.future;
  }

  Future<void> _execute() async {
    while (!_isCancelled) {
      try {
        final result = await fn();
        if (!_isCancelled) {
          _completer!.complete(result);
        }
        return;
        // ignore: nullable_type_in_catch_clause
      } on TError catch (error) {
        if (_isCancelled) return;

        final delay = retry(_retryCount, error);
        if (delay == null) {
          if (!_isCancelled) {
            _completer!.completeError(error as Object);
          }
          return;
        }

        final failureCount = ++_retryCount;
        onFail?.call(failureCount, error);

        await Future.delayed(delay);
      }
    }
  }

  void cancel({Object? error}) {
    if (_isCancelled) return;
    _isCancelled = true;
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.completeError(error ?? Exception());
    }
  }
}
