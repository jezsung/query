import 'gc_duration.dart';
import 'retry.dart';

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
    this.retry = retryNever,
    this.gcDuration = const GcDuration(minutes: 5),
  });

  /// Default retry callback.
  ///
  /// By default, mutations do not retry (unlike queries which default to 3).
  final RetryResolver retry;

  /// Default garbage collection duration.
  ///
  /// Defaults to 5 minutes.
  final GcDuration gcDuration;

  @override
  String toString() {
    return 'DefaultMutationOptions('
        'retry: <Function>, '
        'gcDuration: $gcDuration)';
  }
}
