import 'dart:async';

import 'package:meta/meta.dart';

/// A read-only signal indicating whether an operation has been aborted.
///
/// Passed to query functions via [QueryFunctionContext], allowing the function
/// to check if it should stop execution or clean up resources.
///
/// The signal provides multiple ways to detect abort:
/// - [isAborted]: boolean check for immediate status
/// - [whenAbort]: a future that completes when aborted
/// - [throwIfAborted]: throws [AbortedException] if aborted
///
/// ```dart
/// (QueryFunctionContext context) async {
///   // Race against abort signal.
///   await Future.any([
///     someOperation(),
///     context.signal.whenAbort,
///   ]);
///   context.signal.throwIfAborted();
///
///   // Or register a cleanup callback.
///   context.signal.whenAbort.whenComplete(() => cleanup());
///
///   // Or check manually.
///   if (context.signal.isAborted) {
///     return cachedData;
///   }
/// }
/// ```
class AbortSignal {
  AbortSignal._(this._controller);

  final AbortController _controller;

  /// Whether this signal has been aborted.
  ///
  /// Accessing this property marks the signal as consumed.
  bool get isAborted {
    _controller._markConsumed();
    return _controller._isAborted;
  }

  /// A future that completes when this signal is aborted.
  ///
  /// Use this to race against the abort signal with [Future.any] or register
  /// callbacks with [Future.whenComplete].
  ///
  /// ```dart
  /// // Race against abort.
  /// await Future.any([operation(), signal.whenAbort]);
  /// signal.throwIfAborted();
  ///
  /// // Register cleanup callback.
  /// signal.whenAbort.whenComplete(() => cleanup());
  /// ```
  ///
  /// Accessing this property marks the signal as consumed.
  Future<void> get whenAbort {
    _controller._markConsumed();
    return _controller._completer.future;
  }

  /// Throws [AbortedException] if this signal has been aborted.
  ///
  /// The exception has the same [AbortedException.revert] and
  /// [AbortedException.silent] values that were passed to
  /// [AbortController.abort].
  ///
  /// ```dart
  /// queryFn: (context) async {
  ///   final part1 = await fetchPart1();
  ///   context.signal.throwIfAborted();
  ///   final part2 = await fetchPart2();
  ///   return combine(part1, part2);
  /// }
  /// ```
  void throwIfAborted() {
    if (isAborted) {
      throw AbortedException(
        revert: _controller._revert,
        silent: _controller._silent,
      );
    }
  }
}

/// An exception indicating a query or mutation was aborted.
///
/// Thrown by [AbortSignal.throwIfAborted] when the signal has been aborted.
class AbortedException implements Exception {
  /// Creates an exception indicating a query was aborted.
  const AbortedException({
    this.revert = true,
    this.silent = false,
  });

  /// Whether the query state should revert to its previous value.
  ///
  /// When `true`, the query state is restored to what it was before
  /// the fetch started.
  final bool revert;

  /// Whether error notifications should be suppressed.
  ///
  /// When `true`, the abort does not trigger error callbacks or update
  /// the query's error state.
  final bool silent;

  @override
  String toString() => 'AbortedException: Query was aborted'
      '${revert ? ' (reverting)' : ''}'
      '${silent ? ' (silent)' : ''}';
}

/// A controller that manages an [AbortSignal] and can trigger abort.
///
/// Used internally by [Query] to create and control the abort signal for each
/// fetch operation.
@internal
class AbortController {
  /// Creates an abort controller.
  AbortController();

  final Completer<void> _completer = Completer<void>();
  bool _isAborted = false;
  bool _wasConsumed = false;
  bool _revert = true;
  bool _silent = false;

  /// The signal associated with this controller.
  ///
  /// Pass this to query functions; it reflects the aborted state when [abort]
  /// is called.
  late final AbortSignal signal = AbortSignal._(this);

  /// Whether the signal was consumed by the query function.
  ///
  /// Returns `true` if the query function accessed [AbortSignal.isAborted],
  /// [AbortSignal.whenAbort], or called [AbortSignal.throwIfAborted].
  ///
  /// Used to optimize cancellation behavior: if consumed, the query function
  /// supports cancellation, so abort it; if not consumed, let it complete but
  /// discard the result.
  bool get wasConsumed => _wasConsumed;

  /// Aborts the signal.
  ///
  /// When [revert] is `true` (the default), the query state is restored to
  /// what it was before the fetch started. When [silent] is `true`, the
  /// cancellation does not trigger error callbacks or update the query's
  /// error state.
  ///
  /// After calling this, [AbortSignal.isAborted] returns `true`,
  /// [AbortSignal.whenAbort] completes, and [AbortSignal.throwIfAborted]
  /// throws [AbortedException].
  ///
  /// Calling this multiple times has no additional effect.
  void abort({bool revert = true, bool silent = false}) {
    if (!_isAborted) {
      _isAborted = true;
      _revert = revert;
      _silent = silent;
      if (!_completer.isCompleted) {
        _completer.complete();
      }
    }
  }

  void _markConsumed() {
    _wasConsumed = true;
  }
}
