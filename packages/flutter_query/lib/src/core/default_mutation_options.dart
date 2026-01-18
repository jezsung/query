import 'query_options.dart';
import 'utils.dart';

class DefaultMutationOptions {
  const DefaultMutationOptions({
    this.gcDuration = const GcDuration(minutes: 5),
    this.retry = retryNever,
  });

  final GcDuration gcDuration;
  final RetryResolver retry;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DefaultMutationOptions &&
          gcDuration == other.gcDuration &&
          identical(retry, other.retry);

  @override
  int get hashCode => Object.hash(
        gcDuration,
        identityHashCode(retry),
      );

  @override
  String toString() {
    return 'DefaultMutationOptions('
        'gcDuration: $gcDuration, '
        'retry: <Function>)';
  }
}
