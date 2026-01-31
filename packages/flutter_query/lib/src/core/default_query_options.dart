import 'query_options.dart';
import 'utils.dart';

/// Default options applied to all queries in a [QueryClient].
///
/// These defaults are used when individual queries do not specify their own
/// values. Query-specific options always take precedence over these defaults.
///
/// Example:
/// ```dart
/// QueryClient(
///   defaultQueryOptions: DefaultQueryOptions(
///     staleDuration: StaleDuration(minutes: 5),
///     gcDuration: GcDuration(minutes: 10),
///     refetchOnMount: RefetchOnMount.always,
///   ),
/// );
/// ```
class DefaultQueryOptions {
  const DefaultQueryOptions({
    this.enabled = true,
    this.staleDuration = StaleDuration.zero,
    this.gcDuration = const GcDuration(minutes: 5),
    this.refetchInterval,
    this.refetchOnMount = RefetchOnMount.stale,
    this.refetchOnResume = RefetchOnResume.stale,
    this.refetchOnReconnect = RefetchOnReconnect.stale,
    this.retry,
    this.retryOnMount = true,
    this.meta,
  });

  /// Whether queries are enabled by default.
  ///
  /// When `false`, queries will not automatically fetch data.
  /// Defaults to `true`.
  final bool enabled;

  /// How long query data is considered fresh before becoming stale.
  ///
  /// Defaults to [StaleDuration.zero], meaning data is immediately stale.
  final StaleDuration staleDuration;

  /// How long unused query data remains in memory before garbage collection.
  ///
  /// Defaults to 5 minutes.
  final GcDuration gcDuration;

  /// Interval at which queries automatically refetch in the background.
  ///
  /// When `null`, automatic refetching is disabled. Defaults to `null`.
  final Duration? refetchInterval;

  /// Whether to refetch when an observer mounts.
  ///
  /// Defaults to [RefetchOnMount.stale].
  final RefetchOnMount refetchOnMount;

  /// Whether to refetch when the app resumes from background.
  ///
  /// Defaults to [RefetchOnResume.stale].
  final RefetchOnResume refetchOnResume;

  /// Whether to refetch when network connectivity is restored.
  ///
  /// Defaults to [RefetchOnReconnect.stale].
  ///
  /// Note: Requires [connectivityChanges] to be provided to [QueryClient].
  /// If not provided, this option has no effect.
  final RefetchOnReconnect refetchOnReconnect;

  /// Retry behavior for failed queries.
  ///
  /// When `null`, uses the query's own retry configuration. Defaults to `null`.
  final RetryResolver? retry;

  /// Whether to retry a failed query when a new observer mounts.
  ///
  /// Defaults to `true`.
  final bool retryOnMount;

  /// Arbitrary metadata to attach to queries.
  ///
  /// This metadata is accessible in the query function via the context.
  /// Defaults to `null`.
  final Map<String, dynamic>? meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DefaultQueryOptions &&
          enabled == other.enabled &&
          staleDuration == other.staleDuration &&
          gcDuration == other.gcDuration &&
          refetchInterval == other.refetchInterval &&
          refetchOnMount == other.refetchOnMount &&
          refetchOnResume == other.refetchOnResume &&
          refetchOnReconnect == other.refetchOnReconnect &&
          identical(retry, other.retry) &&
          retryOnMount == other.retryOnMount &&
          deepEq.equals(meta, other.meta);

  @override
  int get hashCode => Object.hash(
        enabled,
        staleDuration,
        gcDuration,
        refetchInterval,
        refetchOnMount,
        refetchOnResume,
        refetchOnReconnect,
        identityHashCode(retry),
        retryOnMount,
        meta,
      );

  @override
  String toString() => 'DefaultQueryOptions('
      'enabled: $enabled, '
      'staleDuration: $staleDuration, '
      'gcDuration: $gcDuration, '
      'refetchInterval: $refetchInterval, '
      'refetchOnMount: $refetchOnMount, '
      'refetchOnResume: $refetchOnResume, '
      'refetchOnReconnect: $refetchOnReconnect, '
      'retry: $retry, '
      'retryOnMount: $retryOnMount, '
      'meta: $meta)';
}
