import '../core/core.dart';
import '../hooks/use_query.dart' as core;
import 'query_snapshot.dart';

/// A hook for fetching, caching, and subscribing to async data.
///
/// Equivalent to the canonical `useQuery`, but returns a [QuerySnapshot]: a
/// `sealed` type that supports exhaustive pattern matching and exposes
/// non-nullable `data`/`error` in the [QuerySuccess]/[QueryError] variants.
///
/// This is an experimental API exposed via
/// `package:flutter_query/experiments.dart`. See the canonical `useQuery` for
/// the meaning of every option.
///
/// This is an experimental API and may change in a future minor release.
QuerySnapshot<TData, TError> useQuery<TData, TError>(
  List<Object?> queryKey,
  QueryFn<TData> queryFn, {
  bool? enabled,
  NetworkMode? networkMode,
  StaleDuration? staleDuration,
  GcDuration? gcDuration,
  TData? placeholder,
  RefetchOnMount? refetchOnMount,
  RefetchOnResume? refetchOnResume,
  RefetchOnReconnect? refetchOnReconnect,
  Duration? refetchInterval,
  RetryResolver<TError>? retry,
  bool? retryOnMount,
  TData? seed,
  DateTime? seedUpdatedAt,
  Map<String, dynamic>? meta,
  ShouldRebuild<QuerySnapshot<TData, TError>>? shouldRebuild,
  QueryClient? client,
}) {
  final result = core.useQuery<TData, TError>(
    queryKey,
    queryFn,
    enabled: enabled,
    networkMode: networkMode,
    staleDuration: staleDuration,
    gcDuration: gcDuration,
    placeholder: placeholder,
    refetchOnMount: refetchOnMount,
    refetchOnResume: refetchOnResume,
    refetchOnReconnect: refetchOnReconnect,
    refetchInterval: refetchInterval,
    retry: retry,
    retryOnMount: retryOnMount,
    seed: seed,
    seedUpdatedAt: seedUpdatedAt,
    meta: meta,
    shouldRebuild: shouldRebuild == null
        ? null
        : (previous, next) =>
            shouldRebuild(previous.toSnapshot(), next.toSnapshot()),
    client: client,
  );

  return result.toSnapshot();
}
