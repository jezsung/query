import 'dart:async';

/// Exception thrown when a query is aborted.
///
/// This exception is thrown by [AbortSignal.throwIfAborted] when the signal
/// has been aborted, and by the [Retryer] when it detects an abort during
/// retry attempts.
///
/// Aligned with TanStack Query's CancelledError.
class AbortedException implements Exception {
  /// Creates an aborted exception.
  const AbortedException({
    this.revert = true,
    this.silent = false,
  });

  /// Whether to revert to the previous query state when aborted.
  ///
  /// When true, the query state will be restored to what it was before
  /// the fetch started. This is useful for optimistic updates.
  final bool revert;

  /// Whether to suppress error notifications when aborted.
  ///
  /// When true, the abort will not trigger error callbacks or update
  /// the query's error state.
  final bool silent;

  @override
  String toString() => 'AbortedException: Query was aborted'
      '${revert ? ' (reverting)' : ''}'
      '${silent ? ' (silent)' : ''}';
}

/// A read-only signal that indicates whether an operation has been aborted.
///
/// This is passed to query functions via [QueryFunctionContext] and allows the
/// function to check if it should stop execution or clean up resources.
///
/// The signal provides multiple ways to check for abort:
/// - [isAborted]: Boolean check for immediate status
/// - [whenAbort]: A future that completes when aborted (like [Completer.future])
/// - [throwIfAborted]: Throws [AbortedException] if aborted
///
/// Aligned with TanStack Query's AbortSignal pattern.
///
/// Example:
/// ```dart
/// queryFn: (context) async {
///   // Race against abort signal
///   await Future.any([
///     someOperation(),
///     context.signal.future,
///   ]);
///   context.signal.throwIfAborted();
///
///   // Or register a cleanup callback
///   context.signal.future.whenComplete(() => cleanup());
///
///   // Or check manually
///   if (context.signal.isAborted) {
///     return cachedData;
///   }
///
///   // Or throw if aborted
///   context.signal.throwIfAborted();
/// }
/// ```
class AbortSignal {
  AbortSignal._(this._controller);

  final AbortController _controller;

  /// Whether this signal has been aborted.
  ///
  /// Accessing this property marks the signal as consumed, which affects
  /// the cancellation behavior when observers are removed.
  bool get isAborted {
    _controller._markConsumed();
    return _controller._isAborted;
  }

  /// A future that completes when this signal is aborted.
  ///
  /// This follows the [Completer.future] pattern. Use it to:
  /// - Race against the abort signal with [Future.any]
  /// - Register callbacks with [Future.whenComplete] or [Future.then]
  ///
  /// Example:
  /// ```dart
  /// // Race against abort
  /// await Future.any([operation(), signal.future]);
  /// signal.throwIfAborted();
  ///
  /// // Register cleanup callback
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
  /// The exception will have the same [revert] and [silent] flags that were
  /// passed to [AbortController.abort].
  ///
  /// Use this to create early exit points in your query function.
  ///
  /// Example:
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

/// Controller that manages an [AbortSignal] and can trigger abort.
///
/// This is used internally by the Query class to create and control
/// the abort signal for each fetch operation.
///
/// Aligned with TanStack Query's AbortController pattern.
///
/// Example:
/// ```dart
/// final controller = AbortController();
/// final signal = controller.signal;
///
/// // Pass signal to query function
/// queryFn(QueryFunctionContext(signal: signal, ...));
///
/// // Later, abort the operation
/// controller.abort();
/// ```
class AbortController {
  /// Creates a new abort controller.
  AbortController();

  final Completer<void> _completer = Completer<void>();
  bool _isAborted = false;
  bool _wasConsumed = false;
  bool _revert = true;
  bool _silent = false;

  /// The signal associated with this controller.
  ///
  /// This signal can be passed to query functions and will reflect
  /// the aborted state when [abort] is called.
  late final AbortSignal signal = AbortSignal._(this);

  /// Whether the signal was consumed by the query function.
  ///
  /// This is true if the query function accessed [AbortSignal.isAborted],
  /// [AbortSignal.whenAbort], or called [AbortSignal.throwIfAborted].
  ///
  /// This information is used to optimize cancellation behavior:
  /// - If consumed: The query function supports cancellation, so abort it
  /// - If not consumed: The query function doesn't check for abort,
  ///   so let it complete but don't use the result
  bool get wasConsumed => _wasConsumed;

  /// Aborts the signal.
  ///
  /// When [revert] is true (default), the query state will be restored to
  /// what it was before the fetch started.
  ///
  /// When [silent] is true, the cancellation will not trigger error callbacks
  /// or update the query's error state.
  ///
  /// After calling this:
  /// - [AbortSignal.isAborted] will return true
  /// - [AbortSignal.whenAbort] will complete
  /// - [AbortSignal.throwIfAborted] will throw [AbortedException]
  ///
  /// Calling abort multiple times has no additional effect.
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
