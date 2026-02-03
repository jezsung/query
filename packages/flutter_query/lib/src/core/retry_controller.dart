import 'dart:async';

import 'package:meta/meta.dart';

import 'network_mode.dart';
import 'query_options.dart';
import 'utils.dart';

/// Returns true if a fetch can start based on the network mode and online state.
///
/// - [NetworkMode.online]: Can only start when online
/// - [NetworkMode.always]: Can always start
/// - [NetworkMode.offlineFirst]: Can always start (first fetch runs regardless)
bool canFetch(NetworkMode networkMode, bool isOnline) {
  return switch (networkMode) {
    NetworkMode.online => isOnline,
    NetworkMode.always => true,
    NetworkMode.offlineFirst => true,
  };
}

/// Returns true if execution can continue (after a retry delay) based on the
/// network mode and online state.
///
/// - [NetworkMode.online]: Can only continue when online
/// - [NetworkMode.always]: Can always continue
/// - [NetworkMode.offlineFirst]: Can only continue when online (retries pause)
bool canContinue(NetworkMode networkMode, bool isOnline) {
  return switch (networkMode) {
    NetworkMode.online => isOnline,
    NetworkMode.always => true,
    NetworkMode.offlineFirst => isOnline,
  };
}

/// A retry executor with explicit pause/resume control.
///
/// The caller is responsible for deciding when to pause/resume based on
/// external conditions (e.g., network state). The RetryController only provides
/// the mechanism.
@internal
class RetryController<TData, TError> {
  RetryController(
    this.fn, {
    this.retry = retryExponentialBackoff,
    this.onError,
    this.onPause,
    this.onResume,
  });

  final Future<TData> Function() fn;
  final RetryResolver<TError> retry;
  final void Function(int failureCount, TError error)? onError;
  final void Function()? onPause;
  final void Function()? onResume;

  int _retryCount = 0;
  bool _isCancelled = false;
  Completer<TData>? _completer;
  Completer<void>? _delayCompleter;
  Completer<void>? _pauseCompleter;

  bool get _isResolved => (_completer?.isCompleted ?? false) || _isCancelled;

  /// Whether the controller is currently paused.
  bool get isPaused => _pauseCompleter != null;

  /// Whether the controller has been cancelled.
  bool get isCancelled => _isCancelled;

  /// The future that completes when the operation succeeds or fails.
  ///
  /// Throws [StateError] if [start] has not been called.
  Future<TData> get future {
    if (_completer == null) {
      throw StateError('RetryController has not been started');
    }
    return _completer!.future;
  }

  /// Starts execution of the function.
  ///
  /// If [paused] is true, the controller starts in a paused state and waits
  /// for [resume] to be called before executing.
  ///
  /// Returns the same future on subsequent calls.
  Future<TData> start({bool paused = false}) {
    if (_completer != null) {
      return _completer!.future;
    }

    _completer = Completer<TData>();

    if (paused) {
      _pauseCompleter = Completer<void>.sync();
      onPause?.call();
      unawaited(_pauseCompleter!.future.then((_) => _execute()));
    } else {
      unawaited(_execute());
    }

    return _completer!.future;
  }

  /// Pauses execution immediately, interrupting any retry delay.
  ///
  /// Call [resume] to continue execution.
  void pause() {
    if (_isResolved) return;
    if (_pauseCompleter != null) return;

    _pauseCompleter = Completer<void>.sync();
    onPause?.call();

    // Interrupt the retry delay
    final delayCompleter = _delayCompleter;
    if (delayCompleter != null && !delayCompleter.isCompleted) {
      delayCompleter.complete();
    }
  }

  /// Resumes execution if paused.
  void resume() {
    final completer = _pauseCompleter;
    if (completer == null) return;

    _pauseCompleter = null;
    if (!_isResolved) {
      onResume?.call();
    }

    if (!completer.isCompleted) {
      completer.complete();
    }
  }

  /// Cancels execution.
  ///
  /// If [error] is provided, the future completes with that error.
  /// Otherwise, a generic [Exception] is used.
  void cancel({Object? error}) {
    if (_isCancelled) return;
    _isCancelled = true;

    // Capture and clear all completers before completing any of them.
    // This ensures state is consistent when sync completers trigger
    // their continuations.
    final delayCompleter = _delayCompleter;
    _delayCompleter = null;
    final pauseCompleter = _pauseCompleter;
    _pauseCompleter = null;
    final mainCompleter = _completer;

    // Complete all at the end (tail position for sync completer safety)
    if (delayCompleter != null && !delayCompleter.isCompleted) {
      delayCompleter.complete();
    }
    if (pauseCompleter != null && !pauseCompleter.isCompleted) {
      pauseCompleter.complete();
    }
    if (mainCompleter != null && !mainCompleter.isCompleted) {
      mainCompleter.completeError(error ?? Exception());
    }
  }

  Future<void> _execute() async {
    while (!_isCancelled) {
      try {
        final result = await fn();
        if (!_isCancelled) {
          _completer!.complete(result);
        }
        return;
      } catch (error) {
        if (_isCancelled) {
          return;
        }
        if (error is! TError) {
          rethrow;
        }

        _delayCompleter = Completer<void>.sync();

        final delay = retry(_retryCount, error as TError);
        if (delay == null) {
          if (!_isCancelled) {
            _completer!.completeError(error);
          }
          return;
        }

        final failureCount = ++_retryCount;
        onError?.call(failureCount, error as TError);

        if (!_delayCompleter!.isCompleted) {
          await Future.any([
            Future.delayed(delay),
            _delayCompleter!.future,
          ]);
        }

        // If paused, wait for resume
        if (_pauseCompleter != null && !_isCancelled) {
          await _pauseCompleter!.future;
        }
      } finally {
        _delayCompleter = null;
      }
    }
  }
}
