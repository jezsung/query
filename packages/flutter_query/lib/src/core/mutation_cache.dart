import 'package:collection/collection.dart';

import 'mutation.dart';
import 'mutation_options.dart';
import 'mutation_state.dart';
import 'query_client.dart';

/// Cache for storing and managing mutation instances.
///
/// Unlike QueryCache which uses keys for deduplication, MutationCache
/// simply tracks all mutation instances. Each call to `build()` creates
/// a new mutation.
///
/// Aligned with TanStack Query's MutationCache.
class MutationCache {
  late final QueryClient? _client;
  final Set<Mutation> _mutations = {};
  int _mutationIdCounter = 0;

  /// Sets the client reference for this cache.
  ///
  /// This is called by QueryClient during construction to establish
  /// a back-reference needed for passing the client to Mutation instances.
  set client(QueryClient client) => _client = client;

  /// Builds a new mutation instance.
  ///
  /// Unlike queries, each call creates a new mutation - mutations are not
  /// deduplicated by key.
  Mutation<TData, TError, TVariables, TOnMutateResult>
      build<TData, TError, TVariables, TOnMutateResult>(
    MutationOptions<TData, TError, TVariables, TOnMutateResult> options,
  ) {
    assert(_client != null, 'MutationCache must have a client set');
    final mutation = Mutation<TData, TError, TVariables, TOnMutateResult>(
      client: _client!,
      mutationId: _mutationIdCounter++,
      options: options,
    );
    add(mutation);
    return mutation;
  }

  /// Adds a mutation to the cache.
  void add(Mutation mutation) {
    _mutations.add(mutation);
  }

  /// Removes a mutation from the cache.
  void remove(Mutation mutation) {
    mutation.dispose();
    _mutations.remove(mutation);
  }

  /// Returns all mutations in the cache.
  List<Mutation> getAll() {
    return _mutations.toList();
  }

  /// Finds mutations matching the given filters.
  List<Mutation> findAll({
    bool exact = false,
    bool Function(Mutation)? predicate,
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

  /// Finds a single mutation matching the given filters.
  ///
  /// Unlike [findAll], this defaults [exact] to `true`.
  Mutation? find({
    bool exact = true,
    bool Function(Mutation)? predicate,
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

  /// Clears all mutations from the cache.
  void clear() {
    for (final mutation in _mutations) {
      mutation.dispose();
    }
    _mutations.clear();
  }
}
