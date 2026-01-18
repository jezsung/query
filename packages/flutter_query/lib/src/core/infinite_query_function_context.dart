import 'abort_signal.dart';
import 'query_client.dart';
import 'query_key.dart';
import 'query_observer.dart';
import 'utils.dart';

/// Context provided to infinite query functions during execution.
///
/// Shares the fields with [QueryFunctionContext] and adds pagination-specific
/// fields for fetching pages of data.
final class InfiniteQueryFunctionContext<TPageParam> {
  const InfiniteQueryFunctionContext({
    required this.queryKey,
    required this.client,
    required this.signal,
    required this.meta,
    required this.pageParam,
    required this.direction,
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

  /// The page parameter for the current page being fetched.
  ///
  /// For the initial fetch, this is the value from [initialPageParam]. For
  /// subsequent fetches, this is the value returned by `getNextPageParam` or
  /// `getPreviousPageParam`.
  final TPageParam pageParam;

  /// The direction of the current fetch.
  ///
  /// Returns [FetchDirection.forward] when fetching the next page and
  /// [FetchDirection.backward] when fetching the previous page.
  final FetchDirection direction;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InfiniteQueryFunctionContext<TPageParam> &&
          QueryKey(queryKey) == QueryKey(other.queryKey) &&
          client == other.client &&
          deepEq.equals(meta, other.meta) &&
          deepEq.equals(pageParam, other.pageParam) &&
          direction == other.direction;

  @override
  int get hashCode => Object.hash(
        QueryKey(queryKey),
        client,
        deepEq.hash(meta),
        deepEq.hash(pageParam),
        direction,
      );

  @override
  String toString() => 'InfiniteQueryFunctionContext('
      'queryKey: $queryKey, '
      'pageParam: $pageParam, '
      'direction: $direction, '
      'signal: $signal, '
      'meta: $meta)';
}
