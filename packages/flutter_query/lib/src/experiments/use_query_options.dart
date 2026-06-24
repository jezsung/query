import '../core/core.dart';
import '../hooks/use_query_options.dart' as core;
import 'query_snapshot.dart';

/// A hook for fetching, caching, and subscribing to async data from a
/// pre-built [QueryOptions] object.
///
/// Equivalent to the canonical `useQueryOptions`, but returns a
/// [QuerySnapshot]: a `sealed` type that supports exhaustive pattern matching
/// and exposes non-nullable `data`/`error` in the [QuerySuccess]/[QueryError]
/// variants.
///
/// This is the object-first counterpart to the experimental `useQuery`. See
/// the canonical `useQueryOptions` for the meaning of [options] and [client].
///
/// This is an experimental API exposed via
/// `package:flutter_query/experiments.dart`, and may change in a future minor
/// release.
QuerySnapshot<TData, TError> useQueryOptions<TData, TError>(
  QueryOptions<TData, TError> options, {
  QueryClient? client,
}) {
  final result = core.useQueryOptions<TData, TError>(options, client: client);

  return result.toSnapshot();
}
