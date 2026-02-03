import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// Shared instance for deep collection equality checks.
@internal
const deepEq = DeepCollectionEquality();

@internal
extension MapIterableExt<K, V> on Iterable<Map<K, V>> {
  /// Deeply merges all maps in this iterable.
  ///
  /// Later maps override earlier maps for the same keys.
  /// Nested maps are recursively merged.
  ///
  /// Returns an empty map if the iterable is empty.
  Map<K, V> deepMergeAll() {
    Map<K, V> merge(Map<K, V> base, Map<K, V> other) {
      final result = Map<K, V>.from(base);
      for (final entry in other.entries) {
        final existingValue = result[entry.key];
        final incomingValue = entry.value;

        if (existingValue is Map<K, V> && incomingValue is Map<K, V>) {
          result[entry.key] = merge(existingValue, incomingValue) as V;
        } else {
          result[entry.key] = incomingValue;
        }
      }
      return result;
    }

    final iterator = this.iterator;
    if (!iterator.moveNext()) return const {};
    var result = iterator.current;
    while (iterator.moveNext()) {
      result = merge(result, iterator.current);
    }
    return result;
  }
}

@internal
extension FutureExt<T> on Future<T> {
  Future<void> suppress() => then((_) {}).catchError((_) {});
}

@internal
extension ListExt<T> on List<T> {
  /// Append item to end, removing first item if exceeding [maxLength].
  List<T> appendBounded(T item, [int? maxLength]) {
    final newItems = [...this, item];
    if (maxLength != null && newItems.length > maxLength) {
      return newItems.sublist(1);
    }
    return newItems;
  }

  /// Prepend item to start, removing last item if exceeding [maxLength].
  List<T> prependBounded(T item, [int? maxLength]) {
    final newItems = [item, ...this];
    if (maxLength != null && newItems.length > maxLength) {
      return newItems.sublist(0, newItems.length - 1);
    }
    return newItems;
  }
}

/// Never retries - returns null for any error.
///
/// This is the default retry behavior for mutations.
///
/// Example:
/// ```dart
/// retry: retryNever
/// ```
@internal
Duration? retryNever(int retryCount, Object? error) => null;

/// Exponential backoff retry function.
///
/// Retries up to 3 times with delays of 1s, 2s, 4s (capped at 30s).
///
/// Example:
/// ```dart
/// retry: retryExponentialBackoff
/// ```
@internal
Duration? retryExponentialBackoff(int retryCount, Object? error) {
  if (retryCount < 0) {
    throw ArgumentError.value(retryCount, 'retryCount', 'must be non-negative');
  }

  const maxRetries = 3;
  const baseDelayMs = 1000;
  const maxDelayMs = 30000;

  if (retryCount >= maxRetries) return null;
  final delayMs = baseDelayMs * (1 << retryCount);
  return Duration(milliseconds: delayMs.clamp(0, maxDelayMs));
}
