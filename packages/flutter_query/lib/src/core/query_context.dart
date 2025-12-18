import 'query_client.dart';
import 'query_key.dart';

/// Context passed to query functions containing the query key and client.
///
/// This aligns with TanStack Query v5's QueryFunctionContext pattern,
/// using a more Dart-idiomatic name.
final class QueryContext {
  const QueryContext({
    required this.queryKey,
    required this.client,
  });

  /// The query key that uniquely identifies this query.
  final List<Object?> queryKey;

  /// The QueryClient instance managing this query.
  final QueryClient client;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueryContext &&
          QueryKey(queryKey) == QueryKey(other.queryKey) &&
          client == other.client;

  @override
  int get hashCode => Object.hash(QueryKey(queryKey), client);
}
