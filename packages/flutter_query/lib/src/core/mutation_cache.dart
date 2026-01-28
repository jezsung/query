import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'mutation.dart';
import 'mutation_state.dart';

@internal
class MutationCache {
  final Set<Mutation> _mutations = {};
  int _mutationIdCounter = 0;

  @internal
  int getNextMutationId() => _mutationIdCounter++;

  List<Mutation> getAll() {
    return _mutations.toList();
  }

  void add(Mutation mutation) {
    _mutations.add(mutation);
  }

  void remove(Mutation mutation) {
    mutation.dispose();
    _mutations.remove(mutation);
  }

  void clear() {
    for (final mutation in _mutations) {
      mutation.dispose();
    }
    _mutations.clear();
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
}
