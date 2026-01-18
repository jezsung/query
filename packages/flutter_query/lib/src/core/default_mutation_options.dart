import 'query_options.dart';
import 'utils.dart';

class DefaultMutationOptions {
  const DefaultMutationOptions({
    this.retry = retryNever,
    this.gcDuration = const GcDuration(minutes: 5),
  });

  final RetryResolver retry;
  final GcDuration gcDuration;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DefaultMutationOptions &&
          identical(retry, other.retry) &&
          gcDuration == other.gcDuration;

  @override
  int get hashCode => Object.hash(
        identityHashCode(retry),
        gcDuration,
      );

  @override
  String toString() {
    return 'DefaultMutationOptions('
        'retry: <Function>, '
        'gcDuration: $gcDuration)';
  }
}
