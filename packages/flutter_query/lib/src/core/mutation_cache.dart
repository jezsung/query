import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'mutation.dart';
import 'mutation_cache_event.dart';
import 'mutation_state.dart';
import 'subscribable.dart';

typedef MutationCacheListener = void Function(MutationCacheEvent event);

@internal
class MutationCache with Subscribable<MutationCacheListener> {
  final Set<Mutation> _mutations = {};
  int _mutationIdCounter = 0;

  @internal
  int getNextMutationId() => _mutationIdCounter++;

  List<Mutation> getAll() {
    return _mutations.toList();
  }

  void add(Mutation mutation) {
    _mutations.add(mutation);
    dispatch(MutationAddedEvent(mutation));
  }

  void remove(Mutation mutation) {
    if (_mutations.remove(mutation)) {
      mutation.dispose();
      dispatch(MutationRemovedEvent(mutation));
    }
  }

  void clear() {
    if (_mutations.isEmpty) return;
    final mutationsToRemove = _mutations.toList();
    _mutations.clear();
    for (final mutation in mutationsToRemove) {
      mutation.dispose();
      dispatch(MutationRemovedEvent(mutation));
    }
  }

  Mutation? find({
    bool exact = true,
    bool Function(List<Object?>? mutationKey, MutationState state)? predicate,
    List<Object?>? mutationKey,
    MutationStatus? status,
  }) {
    return _mutations.firstWhereOrNull((mut) => mut.matches(
          exact: exact,
          predicate: predicate,
          mutationKey: mutationKey,
          status: status,
        ));
  }

  List<Mutation> findAll({
    bool exact = false,
    bool Function(List<Object?>? mutationKey, MutationState state)? predicate,
    List<Object?>? mutationKey,
    MutationStatus? status,
  }) {
    return _mutations
        .where((mut) => mut.matches(
              exact: exact,
              predicate: predicate,
              mutationKey: mutationKey,
              status: status,
            ))
        .toList();
  }

  void dispatch(MutationCacheEvent event) {
    notify((listener) => listener(event));
  }
}
