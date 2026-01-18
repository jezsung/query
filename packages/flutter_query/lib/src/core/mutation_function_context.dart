import 'query_client.dart';
import 'utils.dart';

/// Context provided to mutation functions and lifecycle callbacks.
///
/// Contains the client reference, optional metadata, and mutation key needed
/// to execute a mutation and its associated callbacks such as `onMutate`,
/// `onSuccess`, `onError`, and `onSettled`.
class MutationFunctionContext {
  const MutationFunctionContext({
    required this.client,
    this.meta,
    this.mutationKey,
  });

  /// The [QueryClient] instance managing this mutation.
  final QueryClient client;

  /// Additional metadata associated with this mutation, if provided.
  ///
  /// Contains custom key-value pairs passed through mutation options for use
  /// in logging, analytics, or other application-specific logic.
  final Map<String, dynamic>? meta;

  /// The key that identifies this mutation, if provided.
  ///
  /// Unlike query keys, mutation keys are optional and do not deduplicate
  /// mutations. They can be used to filter or identify mutations in the cache.
  final List<Object?>? mutationKey;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MutationFunctionContext &&
        identical(client, other.client) &&
        deepEq.equals(meta, other.meta) &&
        deepEq.equals(mutationKey, other.mutationKey);
  }

  @override
  int get hashCode => Object.hash(
        identityHashCode(client),
        deepEq.hash(meta),
        deepEq.hash(mutationKey),
      );

  @override
  String toString() {
    return 'MutationFunctionContext('
        'client: $client, '
        'meta: $meta, '
        'mutationKey: $mutationKey)';
  }
}
