import 'package:meta/meta.dart';

/// A mixin that provides subscription capabilities for cache-level notifications.
///
/// This enables classes like [QueryCache] and [MutationCache] to notify
/// listeners when their contents change (items added, removed, or updated).
@internal
mixin Subscribable<TListener extends Function> {
  final Set<TListener> _listeners = {};

  /// Subscribes to notifications.
  ///
  /// Returns an unsubscribe function that removes the listener.
  void Function() subscribe(TListener listener) {
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  /// Notifies all listeners by invoking [callback] with each listener.
  @protected
  void notify(void Function(TListener listener) callback) {
    for (final listener in _listeners) {
      callback(listener);
    }
  }
}
