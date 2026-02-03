import 'query_client.dart';
import 'utils.dart';

/// Context provided to mutation functions and lifecycle callbacks.
///
/// Contains the client reference, metadata, and mutation key needed to execute
/// a mutation and its associated callbacks such as `onMutate`, `onSuccess`,
/// `onError`, and `onSettled`.
class MutationFunctionContext {
  /// Creates a mutation function context.
  const MutationFunctionContext({
    required this.mutationKey,
    required this.client,
    required this.meta,
  });

  /// The key that identifies this mutation.
  ///
  /// Unlike query keys, mutation keys do not deduplicate mutations. They can
  /// be used to filter or identify mutations in the cache. May be null if no
  /// mutation key was provided in the options.
  final List<Object?>? mutationKey;

  /// The [QueryClient] instance managing this mutation.
  final QueryClient client;

  /// Additional metadata associated with this mutation.
  ///
  /// Contains custom key-value pairs passed through mutation options for use
  /// in logging, analytics, or other application-specific logic.
  final Map<String, dynamic> meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MutationFunctionContext &&
          deepEq.equals(mutationKey, other.mutationKey) &&
          identical(client, other.client) &&
          deepEq.equals(meta, other.meta);

  @override
  int get hashCode => Object.hash(
        deepEq.hash(mutationKey),
        identityHashCode(client),
        deepEq.hash(meta),
      );

  @override
  String toString() => 'MutationFunctionContext('
      'mutationKey: $mutationKey, '
      'client: $client, '
      'meta: $meta)';
}
