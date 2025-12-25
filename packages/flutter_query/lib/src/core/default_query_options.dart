import 'options/gc_duration.dart';
import 'options/refetch_on_mount.dart';
import 'options/refetch_on_resume.dart';
import 'options/retry.dart';
import 'options/stale_duration.dart';

/// Default options for queries that can be set at the QueryClient level.
///
/// These options are applied to all queries unless overridden by query-specific
/// options. Omits `queryKey` and `queryFn` since those are always required
/// per-query, and `initialData`, `initialDataUpdatedAt`, `placeholderData`
/// since those are inherently query-specific.
///
/// Uses `dynamic`/`Object?` for generic type parameters because defaults apply
/// across all query types. Type conversion happens in [QueryOptions.mergeWith].
///
/// Aligned with TanStack Query v5's `DefaultOptions.queries` which is:
/// `OmitKeyof<QueryObserverOptions, 'suspense' | 'queryKey'>`
class DefaultQueryOptions {
  const DefaultQueryOptions({
    this.enabled = true,
    this.gcDuration,
    this.refetchInterval,
    this.refetchOnMount = RefetchOnMount.stale,
    this.refetchOnResume = RefetchOnResume.stale,
    this.retry,
    this.retryOnMount = true,
    this.staleDuration,
  });

  /// Whether queries are enabled by default.
  final bool enabled;

  /// Default garbage collection duration.
  final GcDuration? gcDuration;

  /// Default refetch interval.
  final Duration? refetchInterval;

  /// Default refetch behavior on mount.
  final RefetchOnMount refetchOnMount;

  /// Default refetch behavior on app resume.
  final RefetchOnResume refetchOnResume;

  /// Default retry callback.
  final Retry? retry;

  /// Default retry on mount behavior.
  final bool retryOnMount;

  /// Default stale duration.
  final StaleDuration? staleDuration;
}
