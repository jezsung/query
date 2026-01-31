import 'mutation.dart';

/// Events emitted by [MutationCache] when its contents change.
///
/// Use pattern matching to handle specific event types:
/// ```dart
/// mutationCache.subscribe((event) {
///   switch (event) {
///     case MutationAddedEvent(:final mutation):
///       print('Mutation added: ${mutation.mutationKey}');
///     case MutationUpdatedEvent(:final mutation):
///       print('Mutation updated: ${mutation.mutationKey}');
///     case MutationRemovedEvent(:final mutation):
///       print('Mutation removed: ${mutation.mutationKey}');
///   }
/// });
/// ```
sealed class MutationCacheEvent {
  const MutationCacheEvent();
}

/// Emitted when a mutation is added to the cache.
final class MutationAddedEvent extends MutationCacheEvent {
  const MutationAddedEvent(this.mutation);

  /// The mutation that was added.
  final Mutation mutation;
}

/// Emitted when a mutation is removed from the cache.
final class MutationRemovedEvent extends MutationCacheEvent {
  const MutationRemovedEvent(this.mutation);

  /// The mutation that was removed.
  final Mutation mutation;
}

/// Emitted when a mutation's state is updated.
final class MutationUpdatedEvent extends MutationCacheEvent {
  const MutationUpdatedEvent(this.mutation);

  /// The mutation whose state was updated.
  final Mutation mutation;
}
