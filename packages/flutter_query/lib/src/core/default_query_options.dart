import 'query_options.dart';

class DefaultQueryOptions {
  const DefaultQueryOptions({
    this.enabled = true,
    this.staleDuration = StaleDuration.zero,
    this.gcDuration = const GcDuration(minutes: 5),
    this.refetchInterval,
    this.refetchOnMount = RefetchOnMount.stale,
    this.refetchOnResume = RefetchOnResume.stale,
    this.retry,
    this.retryOnMount = true,
  });

  final bool enabled;
  final StaleDuration staleDuration;
  final GcDuration gcDuration;
  final Duration? refetchInterval;
  final RefetchOnMount refetchOnMount;
  final RefetchOnResume refetchOnResume;
  final RetryResolver? retry;
  final bool retryOnMount;

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
          identical(retry, other.retry) &&
          retryOnMount == other.retryOnMount;

  @override
  int get hashCode => Object.hash(
        enabled,
        staleDuration,
        gcDuration,
        refetchInterval,
        refetchOnMount,
        refetchOnResume,
        identityHashCode(retry),
        retryOnMount,
      );

  @override
  String toString() => 'DefaultQueryOptions('
      'enabled: $enabled, '
      'staleDuration: $staleDuration, '
      'gcDuration: $gcDuration, '
      'refetchInterval: $refetchInterval, '
      'refetchOnMount: $refetchOnMount, '
      'refetchOnResume: $refetchOnResume, '
      'retry: $retry, '
      'retryOnMount: $retryOnMount)';
}
