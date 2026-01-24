import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'query_options.dart';

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

@internal
extension FutureExt<T> on Future<T> {
  Future<void> suppress() => then((_) {}).catchError((_) {});
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

/// Never retries - returns null for any error.
///
/// This is the default retry behavior for mutations.
///
/// Example:
/// ```dart
/// retry: retryNever
/// ```
Duration? retryNever(int retryCount, Object? error) => null;

/// Creates an exponential backoff retry function.
///
/// Retries up to [maxRetries] times with exponential backoff delays.
/// The delay formula is: min(baseDelay * 2^retryCount, maxDelay).
///
/// Default configuration matches TanStack Query v5:
/// - 3 retries with delays of 1s, 2s, 4s (capped at 30s)
///
/// Parameters:
/// - [maxRetries]: Maximum number of retry attempts (default: 3)
/// - [baseDelay]: Base delay for the first retry (default: 1000ms)
/// - [maxDelay]: Maximum delay cap (default: 30 seconds)
///
/// Example:
/// ```dart
/// // Default: 3 retries with delays of 1s, 2s, 4s
/// retry: retryExponentialBackoff()
///
/// // Custom: 5 retries with 500ms base and 60s max
/// retry: retryExponentialBackoff(
///   maxRetries: 5,
///   baseDelay: Duration(milliseconds: 500),
///   maxDelay: Duration(seconds: 60),
/// )
/// ```
RetryResolver<TError> retryExponentialBackoff<TError>({
  int maxRetries = 3,
  Duration baseDelay = const Duration(seconds: 1),
  Duration maxDelay = const Duration(seconds: 30),
}) {
  return (int retryCount, TError error) {
    if (retryCount >= maxRetries) return null;
    final delayMs = baseDelay.inMilliseconds * (1 << retryCount);
    return Duration(milliseconds: delayMs.clamp(0, maxDelay.inMilliseconds));
  };
}
