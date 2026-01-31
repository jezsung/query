import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:flutter_query/src/hooks/use_effect_event.dart';
import '../core/core.dart';
import 'use_query_client.dart';

/// A hook that returns the count of queries currently fetching.
///
/// This hook subscribes to the query cache and updates whenever any query's
/// fetch status changes. Use it to show global loading indicators.
///
/// The [queryKey] filters which queries to count. When [exact] is false
/// (default), all queries whose keys start with [queryKey] are included.
/// When true, only queries with an exactly matching key are counted.
///
/// The [predicate] function provides additional filtering based on query key
/// and state. Only queries for which it returns true are counted.
///
/// The optional [client] parameter specifies which [QueryClient] to use.
/// If not provided, the nearest [QueryClientProvider] ancestor is used.
///
/// Example:
/// ```dart
/// Widget build(BuildContext context) {
///   final fetchingCount = useIsFetching();
///
///   return Stack(
///     children: [
///       // Your content here
///       if (fetchingCount > 0)
///         const Positioned(
///           top: 0,
///           child: LinearProgressIndicator(),
///         ),
///     ],
///   );
/// }
/// ```
///
/// With filtering:
/// ```dart
/// // Count only user-related queries
/// final usersFetching = useIsFetching(queryKey: ['users']);
///
/// // Count with custom predicate
/// final importantFetching = useIsFetching(
///   predicate: (key, state) => key.first == 'important',
/// );
/// ```
int useIsFetching({
  List<Object?>? queryKey,
  bool exact = false,
  bool Function(List<Object?> queryKey, QueryState state)? predicate,
  QueryClient? client,
}) {
  final effectiveClient = useQueryClient(client);

  final computeCount = useEffectEvent(() {
    return effectiveClient.isFetching(
      queryKey: queryKey,
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
  }, [queryKey, exact, predicate]);

  useEffect(() {
    final unsubscribe = effectiveClient.cache.subscribe((event) {
      if (event is QueryAddedEvent ||
          event is QueryRemovedEvent ||
          event is QueryUpdatedEvent) {
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
