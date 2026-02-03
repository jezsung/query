import 'package:meta/meta.dart';

import 'mutation.dart';

@internal
sealed class MutationCacheEvent {
  const MutationCacheEvent();
}

@internal
final class MutationAddedEvent extends MutationCacheEvent {
  const MutationAddedEvent(this.mutation);

  final Mutation mutation;
}

@internal
final class MutationRemovedEvent extends MutationCacheEvent {
  const MutationRemovedEvent(this.mutation);

  final Mutation mutation;
}

@internal
final class MutationUpdatedEvent extends MutationCacheEvent {
  const MutationUpdatedEvent(this.mutation);

  final Mutation mutation;
}
