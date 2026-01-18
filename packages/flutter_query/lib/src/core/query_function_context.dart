import 'abort_signal.dart';
import 'query_client.dart';
import 'query_key.dart';
import 'utils.dart';

/// Context provided to query functions during execution.
///
/// Contains the query key, client reference, abort signal, and metadata
/// needed to execute a query.
final class QueryFunctionContext {
  const QueryFunctionContext({
    required this.queryKey,
    required this.client,
    required this.signal,
    required this.meta,
  });

  /// The query key that uniquely identifies this query.
  final List<Object?> queryKey;

  /// The [QueryClient] instance managing this query.
  final QueryClient client;

  /// The abort signal for this query execution.
  ///
  /// Use this to check whether the query has been cancelled and to integrate
  /// with HTTP clients that support cancellation.
  final AbortSignal signal;

  /// Additional metadata associated with this query.
  ///
  /// Contains custom key-value pairs passed through query options for use
  /// in logging, analytics, or other application-specific logic.
  final Map<String, dynamic> meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueryFunctionContext &&
          QueryKey(queryKey) == QueryKey(other.queryKey) &&
          client == other.client &&
          deepEq.equals(meta, other.meta);

  @override
  int get hashCode => Object.hash(
        QueryKey(queryKey),
        client,
        deepEq.hash(meta),
      );
}
