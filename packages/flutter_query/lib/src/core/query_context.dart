import 'abort_signal.dart';
import 'query_client.dart';
import 'query_key.dart';

/// Context passed to query functions containing the query key, client, and signal.
///
/// This aligns with TanStack Query v5's QueryFunctionContext pattern,
/// using a more Dart-idiomatic name.
///
/// The [signal] property allows query functions to respond to cancellation:
/// ```dart
/// queryFn: (context) async {
///   // Use with http package
///   final request = AbortableRequest('GET', uri,
///     abortTrigger: context.signal.whenAbort,
///   );
///
///   // Or check manually
///   context.signal.throwIfAborted();
/// }
/// ```
final class QueryContext {
  const QueryContext({
    required this.queryKey,
    required this.client,
    required this.signal,
  });

  /// The query key that uniquely identifies this query.
  final List<Object?> queryKey;

  /// The QueryClient instance managing this query.
  final QueryClient client;

  /// The abort signal for this query execution.
  ///
  /// Use this to check if the query has been cancelled and to integrate
  /// with HTTP clients that support cancellation.
  final AbortSignal signal;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueryContext &&
          QueryKey(queryKey) == QueryKey(other.queryKey) &&
          client == other.client;

  @override
  int get hashCode => Object.hash(QueryKey(queryKey), client);
}
