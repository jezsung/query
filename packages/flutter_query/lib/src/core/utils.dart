import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// Shared instance for deep collection equality checks.
@internal
const deepEq = DeepCollectionEquality();

/// Deeply merges two maps.
///
/// Values from [incoming] override values in [existing] for the same keys.
/// Nested maps are recursively merged.
///
/// Returns [incoming] if [existing] is null.
/// Returns [existing] if [incoming] is null.
@internal
Map<K, V>? deepMergeMap<K, V>(
  Map<K, V>? existing,
  Map<K, V>? incoming,
) {
  if (existing == null) return incoming;
  if (incoming == null) return existing;

  final result = Map<K, V>.from(existing);
  for (final entry in incoming.entries) {
    final existingValue = result[entry.key];
    final incomingValue = entry.value;

    if (existingValue is Map<K, V> && incomingValue is Map<K, V>) {
      result[entry.key] = deepMergeMap(existingValue, incomingValue) as V;
    } else {
      result[entry.key] = incomingValue;
    }
  }

  return result;
}

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
