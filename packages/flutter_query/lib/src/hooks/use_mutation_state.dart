import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:flutter_query/src/hooks/use_effect_event.dart';
import '../core/core.dart';
import 'use_query_client.dart';

/// A hook that returns mutation states from the mutation cache.
///
/// This hook subscribes to the mutation cache and updates whenever any
/// mutation is added, removed, or updated. Use it to track mutation state
/// across your application.
///
/// The [mutationKey] filters which mutations to include. When [exact] is false
/// (default), all mutations whose keys start with [mutationKey] are included.
/// When true, only mutations with an exactly matching key are included.
///
/// The [predicate] function provides additional filtering based on mutation key
/// and state. Only mutations for which it returns true are included.
///
/// The optional [client] parameter specifies which [QueryClient] to use.
/// If not provided, the nearest [QueryClientProvider] ancestor is used.
///
/// Example:
/// ```dart
/// Widget build(BuildContext context) {
///   final mutations = useMutationState();
///
///   return ListView(
///     children: [
///       for (final state in mutations)
///         ListTile(
///           title: Text('Status: ${state.status}'),
///           subtitle: Text('Variables: ${state.variables}'),
///         ),
///     ],
///   );
/// }
/// ```
///
/// With filtering:
/// ```dart
/// // Get mutations for a specific key
/// final todoMutations = useMutationState(mutationKey: ['todos']);
///
/// // Get pending mutations
/// final pending = useMutationState(
///   predicate: (key, state) => state.status == MutationStatus.pending,
/// );
///
/// // Combine filters
/// final pendingTodos = useMutationState(
///   mutationKey: ['todos'],
///   predicate: (key, state) => state.status == MutationStatus.pending,
/// );
/// ```
List<MutationState> useMutationState({
  List<Object?>? mutationKey,
  bool exact = false,
  bool Function(List<Object?>? mutationKey, MutationState state)? predicate,
  QueryClient? client,
}) {
  final effectiveClient = useQueryClient(client);

  final getStates = useEffectEvent(() {
    return effectiveClient.mutationCache
        .findAll(
          mutationKey: mutationKey,
          exact: exact,
          predicate: predicate,
        )
        .map((mutation) => mutation.state)
        .toList();
  });

  final states = useState(getStates.call());

  useEffect(() {
    final newStates = getStates.call();
    if (!deepEq.equals(states.value, newStates)) {
      states.value = newStates;
    }
    return null;
  }, [mutationKey, exact, predicate]);

  useEffect(() {
    final unsubscribe = effectiveClient.mutationCache.subscribe((event) {
      if (event is MutationAddedEvent ||
          event is MutationRemovedEvent ||
          event is MutationUpdatedEvent) {
        final newStates = getStates.call();
        if (!deepEq.equals(states.value, newStates)) {
          states.value = newStates;
        }
      }
    });
    return unsubscribe;
  }, [effectiveClient]);

  return states.value;
}
