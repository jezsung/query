import 'package:collection/collection.dart';

import 'query_client.dart';

const _equality = DeepCollectionEquality();

/// Context passed to mutation function and callbacks.
///
/// Contains references to the client, metadata, and mutation key that can be
/// used within the mutation function and lifecycle callbacks.
///
/// Aligned with TanStack Query's MutationFunctionContext.
class MutationFunctionContext {
  const MutationFunctionContext({
    required this.client,
    this.meta,
    this.mutationKey,
  });

  /// The QueryClient instance.
  final QueryClient client;

  /// Optional metadata associated with the mutation.
  final Map<String, dynamic>? meta;

  /// The mutation key, if provided.
  final List<Object?>? mutationKey;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MutationFunctionContext &&
        identical(client, other.client) &&
        _equality.equals(meta, other.meta) &&
        _equality.equals(mutationKey, other.mutationKey);
  }

  @override
  int get hashCode => Object.hash(
        identityHashCode(client),
        _equality.hash(meta),
        _equality.hash(mutationKey),
      );

  @override
  String toString() {
    return 'MutationFunctionContext('
        'client: $client, '
        'meta: $meta, '
        'mutationKey: $mutationKey)';
  }
}
