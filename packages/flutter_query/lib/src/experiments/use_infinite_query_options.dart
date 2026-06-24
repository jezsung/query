import '../core/core.dart';
import '../hooks/use_infinite_query_options.dart' as core;
import 'infinite_query_snapshot.dart';

/// A hook for fetching and caching paginated data from a pre-built
/// [InfiniteQueryOptions] object.
///
/// Equivalent to the canonical `useInfiniteQueryOptions`, but returns an
/// [InfiniteQuerySnapshot]: a `sealed` type that supports exhaustive pattern
/// matching and exposes non-nullable `data`/`error` in the
/// [InfiniteQuerySuccess]/[InfiniteQueryError] variants.
///
/// This is the object-first counterpart to the experimental
/// `useInfiniteQuery`. See the canonical `useInfiniteQueryOptions` for the
/// meaning of [options] and [client].
///
/// This is an experimental API exposed via
/// `package:flutter_query/experiments.dart`, and may change in a future minor
/// release.
InfiniteQuerySnapshot<TData, TError, TPageParam>
    useInfiniteQueryOptions<TData, TError, TPageParam>(
  InfiniteQueryOptions<TData, TError, TPageParam> options, {
  ShouldRebuild<InfiniteQuerySnapshot<TData, TError, TPageParam>>?
      shouldRebuild,
  QueryClient? client,
}) {
  final result = core.useInfiniteQueryOptions<TData, TError, TPageParam>(
    options,
    shouldRebuild: shouldRebuild == null
        ? null
        : (previous, next) =>
            shouldRebuild(previous.toSnapshot(), next.toSnapshot()),
    client: client,
  );

  return result.toSnapshot();
}
