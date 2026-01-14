import 'package:collection/collection.dart';

import 'abort_signal.dart';
import 'infinite_data.dart';
import 'query_client.dart';
import 'query_key.dart';

/// Context passed to infinite query functions.
///
/// Extends the standard query context with pagination-specific fields:
/// - [pageParam]: The page parameter for the current fetch
/// - [direction]: Whether fetching forward (next) or backward (previous)
///
/// This aligns with TanStack Query v5's QueryFunctionContext for infinite queries.
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

  /// The QueryClient instance managing this query.
  final QueryClient client;

  /// The abort signal for this query execution.
  ///
  /// Use this to check if the query has been cancelled and to integrate
  /// with HTTP clients that support cancellation.
  final AbortSignal signal;

  /// Additional metadata stored on the query options.
  ///
  /// Use this to pass information through to query functions that can be
  /// used for logging, analytics, or other custom logic.
  final Map<String, dynamic> meta;

  /// The page parameter for the current page being fetched.
  ///
  /// For the initial fetch, this is [InfiniteQueryObserverOptions.initialPageParam].
  /// For subsequent fetches, this is the value returned by [getNextPageParam]
  /// or [getPreviousPageParam].
  final TPageParam pageParam;

  /// The direction of the current fetch.
  ///
  /// [FetchDirection.forward] when fetching the next page,
  /// [FetchDirection.backward] when fetching the previous page.
  final FetchDirection direction;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InfiniteQueryFunctionContext<TPageParam> &&
          QueryKey(queryKey) == QueryKey(other.queryKey) &&
          client == other.client &&
          _equality.equals(meta, other.meta) &&
          _equality.equals(pageParam, other.pageParam) &&
          direction == other.direction;

  @override
  int get hashCode => Object.hash(
        QueryKey(queryKey),
        client,
        _equality.hash(meta),
        _equality.hash(pageParam),
        direction,
      );
}

const DeepCollectionEquality _equality = DeepCollectionEquality();
