import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:flutter_query/src/hooks/use_effect_event.dart';
import '../core/core.dart';
import 'use_query_client.dart';

/// A hook that returns the count of mutations currently pending.
///
/// This hook subscribes to the mutation cache and updates whenever any
/// mutation's status changes. Use it to show global saving or loading
/// indicators.
///
/// The [mutationKey] filters which mutations to count. When [exact] is false
/// (default), all mutations whose keys start with [mutationKey] are included.
/// When true, only mutations with an exactly matching key are counted.
///
/// The [predicate] function provides additional filtering based on mutation key
/// and state. Only mutations for which it returns true are counted.
///
/// The optional [client] parameter specifies which [QueryClient] to use.
/// If not provided, the nearest [QueryClientProvider] ancestor is used.
///
/// Example:
/// ```dart
/// Widget build(BuildContext context) {
///   final mutatingCount = useIsMutating();
///
///   return Stack(
///     children: [
///       // Your content here
///       if (mutatingCount > 0)
///         const Positioned(
///           bottom: 16,
///           child: Text('Saving...'),
///         ),
///     ],
///   );
/// }
/// ```
///
/// With filtering:
/// ```dart
/// // Count only user-related mutations
/// final usersMutating = useIsMutating(mutationKey: ['users']);
///
/// // Count with custom predicate
/// final importantMutating = useIsMutating(
///   predicate: (key, state) => key?.first == 'important',
/// );
/// ```
int useIsMutating({
  List<Object?>? mutationKey,
  bool exact = false,
  bool Function(List<Object?>? mutationKey, MutationState state)? predicate,
  QueryClient? client,
}) {
  final effectiveClient = useQueryClient(client);

  final computeCount = useEffectEvent(() {
    return effectiveClient.isMutating(
      mutationKey: mutationKey,
      exact: exact,
      predicate: predicate,
    );
  });

  final count = useState(computeCount.call());

  useEffect(() {
    final newCount = computeCount.call();
    if (newCount != count.value) {
      count.value = newCount;
    }
    return null;
  }, [mutationKey, exact, predicate]);

  useEffect(() {
    final unsubscribe = effectiveClient.mutationCache.subscribe((event) {
      if (event is MutationAddedEvent ||
          event is MutationRemovedEvent ||
          event is MutationUpdatedEvent) {
        final newCount = computeCount.call();
        if (newCount != count.value) {
          count.value = newCount;
        }
      }
    });
    return unsubscribe;
  }, [effectiveClient]);

  return count.value;
}
