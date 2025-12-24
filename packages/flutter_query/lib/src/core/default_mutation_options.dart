import 'options/gc_duration.dart';
import 'options/retry.dart';

/// Default retry function that never retries.
Duration? _noRetry(int retryCount, Object? error) => null;

/// Default options for mutations that can be set at the QueryClient level.
///
/// These options are applied to all mutations unless overridden by
/// mutation-specific options. Omits `mutationFn` and `mutationKey` since those
/// are mutation-specific, and lifecycle callbacks (`onMutate`, `onSuccess`,
/// `onError`, `onSettled`) since those are context-specific.
///
/// Uses `dynamic`/`Object?` for generic type parameters because defaults apply
/// across all mutation types. Type conversion happens in
/// [MutationOptions.mergeWith].
///
/// Aligned with TanStack Query v5's `DefaultOptions.mutations`.
class DefaultMutationOptions {
  const DefaultMutationOptions({
    this.retry = _noRetry,
    this.gcDuration = const GcDuration(minutes: 5),
  });

  /// Default retry callback.
  ///
  /// By default, mutations do not retry (unlike queries which default to 3).
  final Retry retry;

  /// Default garbage collection duration.
  ///
  /// Defaults to 5 minutes.
  final GcDurationOption gcDuration;

  @override
  String toString() {
    return 'DefaultMutationOptions('
        'retry: <Function>, '
        'gcDuration: $gcDuration)';
  }
}
