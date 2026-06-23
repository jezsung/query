import 'package:meta/meta.dart';

import '../core/core.dart';

/// A Dart-idiomatic, exhaustively matchable snapshot of a query's state.
///
/// Unlike [QueryResult], this is a `sealed` hierarchy: a `switch` over it is
/// checked for exhaustiveness, `data` is non-nullable on [QuerySuccess], and
/// `error` is non-nullable on [QueryError]. The activity axis (was
/// `fetchStatus`) is exposed via [isFetching] / [isPaused] / [isIdle].
///
/// This is an experimental API and may change in a future minor release.
@experimental
sealed class QuerySnapshot<TData, TError> {
  /// Creates a query snapshot.
  const QuerySnapshot({
    required this.dataUpdatedAt,
    required this.dataUpdateCount,
    required this.errorUpdatedAt,
    required this.errorUpdateCount,
    required this.failureCount,
    required this.failureReason,
    required this.isEnabled,
    required this.isStale,
    required this.isFetchedAfterMount,
    required this.refetch,
  });

  /// The timestamp when the data was last updated.
  final DateTime? dataUpdatedAt;

  /// The number of times the data has been updated.
  final int dataUpdateCount;

  /// The timestamp when the error was last updated.
  final DateTime? errorUpdatedAt;

  /// The number of times the error has been updated.
  final int errorUpdateCount;

  /// The number of times the current fetch has failed.
  final int failureCount;

  /// The error from the most recent failed fetch attempt.
  final TError? failureReason;

  /// Whether this query is enabled and can fetch.
  final bool isEnabled;

  /// Whether this query's data is considered stale.
  final bool isStale;

  /// Whether this query has been fetched after the observer mounted.
  final bool isFetchedAfterMount;

  /// Refetches the query data.
  final Refetch<TData, TError> refetch;

  /// Whether a fetch is currently in progress.
  bool get isFetching;

  /// Whether the fetch is paused (typically offline).
  bool get isPaused;

  /// Whether no fetch is in progress.
  bool get isIdle => !isFetching && !isPaused;

  /// The last-known data, regardless of the current state.
  TData? get dataOrNull;

  /// Whether the query has no resolved data yet.
  bool get isPending => this is QueryPending<TData, TError>;

  /// Whether the query has resolved data.
  bool get isSuccess => this is QuerySuccess<TData, TError>;

  /// Whether the query is in an error state.
  bool get isError => this is QueryError<TData, TError>;

  /// Whether the query is fetching for the first time with no data.
  bool get isLoading => isPending && isFetching;

  /// Whether the query is refetching in the background.
  bool get isRefetching => isFetching && !isPending;

  /// Whether the query has fetched at least once.
  bool get isFetched => dataUpdateCount > 0 || errorUpdateCount > 0;

  /// Whether the query failed on its initial load with no prior data.
  bool get isLoadingError => isError && dataOrNull == null;

  /// Whether the query failed while refetching with existing data.
  bool get isRefetchError => isError && dataOrNull != null;
}

/// The query has no resolved data yet.
///
/// This is an experimental API and may change in a future minor release.
@experimental
final class QueryPending<TData, TError> extends QuerySnapshot<TData, TError> {
  /// Creates a pending snapshot.
  const QueryPending({
    required this.isFetching,
    required this.isPaused,
    required super.dataUpdatedAt,
    required super.dataUpdateCount,
    required super.errorUpdatedAt,
    required super.errorUpdateCount,
    required super.failureCount,
    required super.failureReason,
    required super.isEnabled,
    required super.isStale,
    required super.isFetchedAfterMount,
    required super.refetch,
  });

  @override
  final bool isFetching;

  @override
  final bool isPaused;

  @override
  TData? get dataOrNull => null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueryPending<TData, TError> &&
          isFetching == other.isFetching &&
          isPaused == other.isPaused &&
          dataUpdatedAt == other.dataUpdatedAt &&
          dataUpdateCount == other.dataUpdateCount &&
          errorUpdatedAt == other.errorUpdatedAt &&
          errorUpdateCount == other.errorUpdateCount &&
          failureCount == other.failureCount &&
          deepEq.equals(failureReason, other.failureReason) &&
          isEnabled == other.isEnabled &&
          isStale == other.isStale &&
          isFetchedAfterMount == other.isFetchedAfterMount;

  @override
  int get hashCode => Object.hash(
        runtimeType,
        isFetching,
        isPaused,
        dataUpdatedAt,
        dataUpdateCount,
        errorUpdatedAt,
        errorUpdateCount,
        failureCount,
        deepEq.hash(failureReason),
        isEnabled,
        isStale,
        isFetchedAfterMount,
      );

  @override
  String toString() => 'QueryPending('
      'isFetching: $isFetching, '
      'isPaused: $isPaused, '
      'isStale: $isStale, '
      'isEnabled: $isEnabled)';
}

/// The query has resolved data.
///
/// This is an experimental API and may change in a future minor release.
@experimental
final class QuerySuccess<TData, TError> extends QuerySnapshot<TData, TError> {
  /// Creates a success snapshot.
  const QuerySuccess({
    required this.data,
    required this.isPlaceholder,
    required this.isFetching,
    required this.isPaused,
    required super.dataUpdatedAt,
    required super.dataUpdateCount,
    required super.errorUpdatedAt,
    required super.errorUpdateCount,
    required super.failureCount,
    required super.failureReason,
    required super.isEnabled,
    required super.isStale,
    required super.isFetchedAfterMount,
    required super.refetch,
  });

  /// The resolved data.
  final TData data;

  /// Whether [data] is placeholder data (not persisted to the cache).
  final bool isPlaceholder;

  @override
  final bool isFetching;

  @override
  final bool isPaused;

  @override
  TData? get dataOrNull => data;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuerySuccess<TData, TError> &&
          deepEq.equals(data, other.data) &&
          isPlaceholder == other.isPlaceholder &&
          isFetching == other.isFetching &&
          isPaused == other.isPaused &&
          dataUpdatedAt == other.dataUpdatedAt &&
          dataUpdateCount == other.dataUpdateCount &&
          errorUpdatedAt == other.errorUpdatedAt &&
          errorUpdateCount == other.errorUpdateCount &&
          failureCount == other.failureCount &&
          deepEq.equals(failureReason, other.failureReason) &&
          isEnabled == other.isEnabled &&
          isStale == other.isStale &&
          isFetchedAfterMount == other.isFetchedAfterMount;

  @override
  int get hashCode => Object.hash(
        runtimeType,
        deepEq.hash(data),
        isPlaceholder,
        isFetching,
        isPaused,
        dataUpdatedAt,
        dataUpdateCount,
        errorUpdatedAt,
        errorUpdateCount,
        failureCount,
        deepEq.hash(failureReason),
        isEnabled,
        isStale,
        isFetchedAfterMount,
      );

  @override
  String toString() => 'QuerySuccess('
      'data: $data, '
      'isPlaceholder: $isPlaceholder, '
      'isFetching: $isFetching, '
      'isStale: $isStale)';
}

/// The query encountered an error.
///
/// This is an experimental API and may change in a future minor release.
@experimental
final class QueryError<TData, TError> extends QuerySnapshot<TData, TError> {
  /// Creates an error snapshot.
  const QueryError({
    required this.error,
    required this.data,
    required this.isFetching,
    required this.isPaused,
    required super.dataUpdatedAt,
    required super.dataUpdateCount,
    required super.errorUpdatedAt,
    required super.errorUpdateCount,
    required super.failureCount,
    required super.failureReason,
    required super.isEnabled,
    required super.isStale,
    required super.isFetchedAfterMount,
    required super.refetch,
  });

  /// The error thrown by the last failed fetch.
  final TError error;

  /// The last successfully resolved data, if any, preserved across the error.
  final TData? data;

  @override
  final bool isFetching;

  @override
  final bool isPaused;

  @override
  TData? get dataOrNull => data;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueryError<TData, TError> &&
          deepEq.equals(error, other.error) &&
          deepEq.equals(data, other.data) &&
          isFetching == other.isFetching &&
          isPaused == other.isPaused &&
          dataUpdatedAt == other.dataUpdatedAt &&
          dataUpdateCount == other.dataUpdateCount &&
          errorUpdatedAt == other.errorUpdatedAt &&
          errorUpdateCount == other.errorUpdateCount &&
          failureCount == other.failureCount &&
          deepEq.equals(failureReason, other.failureReason) &&
          isEnabled == other.isEnabled &&
          isStale == other.isStale &&
          isFetchedAfterMount == other.isFetchedAfterMount;

  @override
  int get hashCode => Object.hash(
        runtimeType,
        deepEq.hash(error),
        deepEq.hash(data),
        isFetching,
        isPaused,
        dataUpdatedAt,
        dataUpdateCount,
        errorUpdatedAt,
        errorUpdateCount,
        failureCount,
        deepEq.hash(failureReason),
        isEnabled,
        isStale,
        isFetchedAfterMount,
      );

  @override
  String toString() => 'QueryError('
      'error: $error, '
      'data: $data, '
      'isFetching: $isFetching, '
      'isStale: $isStale)';
}

/// Maps a [QueryResult] into the sealed [QuerySnapshot] hierarchy.
@internal
extension QueryResultSnapshot<TData, TError> on QueryResult<TData, TError> {
  /// Converts this result into a [QuerySnapshot].
  QuerySnapshot<TData, TError> toSnapshot() {
    final fetching = fetchStatus == FetchStatus.fetching;
    final paused = fetchStatus == FetchStatus.paused;

    switch (status) {
      case QueryStatus.pending:
        return QueryPending<TData, TError>(
          isFetching: fetching,
          isPaused: paused,
          dataUpdatedAt: dataUpdatedAt,
          dataUpdateCount: dataUpdateCount,
          errorUpdatedAt: errorUpdatedAt,
          errorUpdateCount: errorUpdateCount,
          failureCount: failureCount,
          failureReason: failureReason,
          isEnabled: isEnabled,
          isStale: isStale,
          isFetchedAfterMount: isFetchedAfterMount,
          refetch: refetch,
        );
      case QueryStatus.success:
        return QuerySuccess<TData, TError>(
          data: data as TData,
          isPlaceholder: isPlaceholderData,
          isFetching: fetching,
          isPaused: paused,
          dataUpdatedAt: dataUpdatedAt,
          dataUpdateCount: dataUpdateCount,
          errorUpdatedAt: errorUpdatedAt,
          errorUpdateCount: errorUpdateCount,
          failureCount: failureCount,
          failureReason: failureReason,
          isEnabled: isEnabled,
          isStale: isStale,
          isFetchedAfterMount: isFetchedAfterMount,
          refetch: refetch,
        );
      case QueryStatus.error:
        return QueryError<TData, TError>(
          error: error as TError,
          data: data,
          isFetching: fetching,
          isPaused: paused,
          dataUpdatedAt: dataUpdatedAt,
          dataUpdateCount: dataUpdateCount,
          errorUpdatedAt: errorUpdatedAt,
          errorUpdateCount: errorUpdateCount,
          failureCount: failureCount,
          failureReason: failureReason,
          isEnabled: isEnabled,
          isStale: isStale,
          isFetchedAfterMount: isFetchedAfterMount,
          refetch: refetch,
        );
    }
  }
}
