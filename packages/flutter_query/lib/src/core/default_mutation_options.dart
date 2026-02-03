import 'network_mode.dart';
import 'query_options.dart';
import 'utils.dart';

/// Default options applied to all mutations in a [QueryClient].
///
/// These defaults are used when individual mutations do not specify their own
/// values. Mutation-specific options always take precedence over these defaults.
///
/// Example:
/// ```dart
/// QueryClient(
///   defaultMutationOptions: DefaultMutationOptions(
///     gcDuration: GcDuration(minutes: 10),
///     retry: (retryCount, error) {
///       if (retryCount >= 3) return null;
///       return Duration(seconds: 1 << retryCount);
///     },
///   ),
/// );
/// ```
class DefaultMutationOptions {
  const DefaultMutationOptions({
    this.networkMode = NetworkMode.online,
    this.gcDuration = const GcDuration(minutes: 5),
    this.retry = retryNever,
    this.meta,
  });

  /// The network connectivity mode for mutations.
  ///
  /// - [NetworkMode.online]: Mutations pause when offline and resume when online
  /// - [NetworkMode.always]: Mutations execute regardless of network state
  /// - [NetworkMode.offlineFirst]: First execution runs immediately, retries pause
  ///
  /// Defaults to [NetworkMode.online].
  final NetworkMode networkMode;

  /// How long completed mutation data remains in memory before garbage
  /// collection.
  ///
  /// Defaults to 5 minutes.
  final GcDuration gcDuration;

  /// Retry behavior for failed mutations.
  ///
  /// Defaults to [retryNever], meaning mutations are not retried.
  final RetryResolver retry;

  /// Arbitrary metadata to attach to mutations.
  ///
  /// This metadata is accessible in mutation callbacks.
  /// Defaults to `null`.
  final Map<String, dynamic>? meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DefaultMutationOptions &&
          networkMode == other.networkMode &&
          gcDuration == other.gcDuration &&
          identical(retry, other.retry) &&
          deepEq.equals(meta, other.meta);

  @override
  int get hashCode => Object.hash(
        networkMode,
        gcDuration,
        identityHashCode(retry),
        meta,
      );

  @override
  String toString() => 'DefaultMutationOptions('
      'networkMode: $networkMode, '
      'gcDuration: $gcDuration, '
      'retry: <Function>, '
      'meta: $meta)';
}
