import 'package:meta/meta.dart';

import '../core/core.dart';

/// A Dart-idiomatic, exhaustively matchable snapshot of an infinite query.
///
/// Unlike [InfiniteQueryResult], this is a `sealed` hierarchy: a `switch` over
/// it is checked for exhaustiveness, `data` is non-nullable on
/// [InfiniteQuerySuccess], and `error` is non-nullable on [InfiniteQueryError].
/// The activity axis is exposed via [fetchStatus], with [isFetching] /
/// [isPaused] / [isIdle] as conveniences.
///
/// The three variants mirror [QueryStatus]. A failed next/previous page fetch
/// keeps the overall status [QuerySuccess]-equivalent, so it is surfaced via
/// the [isFetchNextPageError] / [isFetchPreviousPageError] flags rather than as
/// a separate variant.
///
/// This is an experimental API and may change in a future minor release.
sealed class InfiniteQuerySnapshot<TData, TError, TPageParam> {
  /// Creates an infinite query snapshot.
  const InfiniteQuerySnapshot({
    required this.fetchStatus,
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
    required this.fetchNextPage,
    required this.fetchPreviousPage,
    required this.hasNextPage,
    required this.hasPreviousPage,
    required this.isFetchingNextPage,
    required this.isFetchingPreviousPage,
    required this.isFetchNextPageError,
    required this.isFetchPreviousPageError,
  });

  /// The current network activity state of the query.
  final FetchStatus fetchStatus;

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

  /// Refetches all pages of the query.
  final InfiniteRefetch<TData, TError, TPageParam> refetch;

  /// Fetches the next page of data.
  final FetchNextPage<TData, TError, TPageParam> fetchNextPage;

  /// Fetches the previous page of data.
  final FetchPreviousPage<TData, TError, TPageParam> fetchPreviousPage;

  /// Whether there is a next page available.
  final bool hasNextPage;

  /// Whether there is a previous page available.
  final bool hasPreviousPage;

  /// Whether this query is currently fetching the next page.
  final bool isFetchingNextPage;

  /// Whether this query is currently fetching the previous page.
  final bool isFetchingPreviousPage;

  /// Whether the last fetch of the next page resulted in an error.
  final bool isFetchNextPageError;

  /// Whether the last fetch of the previous page resulted in an error.
  final bool isFetchPreviousPageError;

  /// Whether a fetch is currently in progress.
  bool get isFetching => fetchStatus == FetchStatus.fetching;

  /// Whether the fetch is paused (typically offline).
  bool get isPaused => fetchStatus == FetchStatus.paused;

  /// Whether no fetch is in progress.
  bool get isIdle => fetchStatus == FetchStatus.idle;

  /// The accumulated pages, if any.
  InfiniteData<TData, TPageParam>? get dataOrNull;

  /// Whether the query has no resolved data yet.
  bool get isPending => this is InfiniteQueryPending<TData, TError, TPageParam>;

  /// Whether the query has resolved data.
  bool get isSuccess => this is InfiniteQuerySuccess<TData, TError, TPageParam>;

  /// Whether the query is in an error state.
  bool get isError => this is InfiniteQueryError<TData, TError, TPageParam>;

  /// Whether the query is fetching for the first time with no data.
  bool get isLoading => isPending && isFetching;

  /// Whether the query has fetched at least once.
  bool get isFetched => dataUpdateCount > 0 || errorUpdateCount > 0;

  /// Whether the query failed on its initial load with no prior data.
  bool get isLoadingError => isError && dataOrNull == null;

  /// Whether the query failed while refetching with existing data.
  bool get isRefetchError => isError && dataOrNull != null;

  /// Whether the query is refetching all pages in the background.
  bool get isRefetching =>
      isFetching &&
      !isPending &&
      !isFetchingNextPage &&
      !isFetchingPreviousPage;

  /// The list of all fetched pages.
  List<TData> get pages => dataOrNull?.pages ?? const [];

  /// The list of page parameters for all fetched pages.
  List<TPageParam> get pageParams => dataOrNull?.pageParams ?? const [];
}

/// The infinite query has no resolved data yet.
///
/// This is an experimental API and may change in a future minor release.
final class InfiniteQueryPending<TData, TError, TPageParam>
    extends InfiniteQuerySnapshot<TData, TError, TPageParam> {
  /// Creates a pending snapshot.
  const InfiniteQueryPending({
    required super.fetchStatus,
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
    required super.fetchNextPage,
    required super.fetchPreviousPage,
    required super.hasNextPage,
    required super.hasPreviousPage,
    required super.isFetchingNextPage,
    required super.isFetchingPreviousPage,
    required super.isFetchNextPageError,
    required super.isFetchPreviousPageError,
  });

  @override
  InfiniteData<TData, TPageParam>? get dataOrNull => null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InfiniteQueryPending<TData, TError, TPageParam> &&
          fetchStatus == other.fetchStatus &&
          dataUpdatedAt == other.dataUpdatedAt &&
          dataUpdateCount == other.dataUpdateCount &&
          errorUpdatedAt == other.errorUpdatedAt &&
          errorUpdateCount == other.errorUpdateCount &&
          failureCount == other.failureCount &&
          deepEq.equals(failureReason, other.failureReason) &&
          isEnabled == other.isEnabled &&
          isStale == other.isStale &&
          isFetchedAfterMount == other.isFetchedAfterMount &&
          hasNextPage == other.hasNextPage &&
          hasPreviousPage == other.hasPreviousPage &&
          isFetchingNextPage == other.isFetchingNextPage &&
          isFetchingPreviousPage == other.isFetchingPreviousPage &&
          isFetchNextPageError == other.isFetchNextPageError &&
          isFetchPreviousPageError == other.isFetchPreviousPageError;

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        fetchStatus,
        dataUpdatedAt,
        dataUpdateCount,
        errorUpdatedAt,
        errorUpdateCount,
        failureCount,
        deepEq.hash(failureReason),
        isEnabled,
        isStale,
        isFetchedAfterMount,
        hasNextPage,
        hasPreviousPage,
        isFetchingNextPage,
        isFetchingPreviousPage,
        isFetchNextPageError,
        isFetchPreviousPageError,
      ]);

  @override
  String toString() => 'InfiniteQueryPending('
      'fetchStatus: $fetchStatus, '
      'isStale: $isStale, '
      'isEnabled: $isEnabled)';
}

/// The infinite query has resolved data.
///
/// This is an experimental API and may change in a future minor release.
final class InfiniteQuerySuccess<TData, TError, TPageParam>
    extends InfiniteQuerySnapshot<TData, TError, TPageParam> {
  /// Creates a success snapshot.
  const InfiniteQuerySuccess({
    required this.data,
    required this.isPlaceholder,
    required super.fetchStatus,
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
    required super.fetchNextPage,
    required super.fetchPreviousPage,
    required super.hasNextPage,
    required super.hasPreviousPage,
    required super.isFetchingNextPage,
    required super.isFetchingPreviousPage,
    required super.isFetchNextPageError,
    required super.isFetchPreviousPageError,
  });

  /// The accumulated pages and their page parameters.
  final InfiniteData<TData, TPageParam> data;

  /// Whether [data] is placeholder data (not persisted to the cache).
  final bool isPlaceholder;

  @override
  InfiniteData<TData, TPageParam>? get dataOrNull => data;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InfiniteQuerySuccess<TData, TError, TPageParam> &&
          deepEq.equals(data, other.data) &&
          isPlaceholder == other.isPlaceholder &&
          fetchStatus == other.fetchStatus &&
          dataUpdatedAt == other.dataUpdatedAt &&
          dataUpdateCount == other.dataUpdateCount &&
          errorUpdatedAt == other.errorUpdatedAt &&
          errorUpdateCount == other.errorUpdateCount &&
          failureCount == other.failureCount &&
          deepEq.equals(failureReason, other.failureReason) &&
          isEnabled == other.isEnabled &&
          isStale == other.isStale &&
          isFetchedAfterMount == other.isFetchedAfterMount &&
          hasNextPage == other.hasNextPage &&
          hasPreviousPage == other.hasPreviousPage &&
          isFetchingNextPage == other.isFetchingNextPage &&
          isFetchingPreviousPage == other.isFetchingPreviousPage &&
          isFetchNextPageError == other.isFetchNextPageError &&
          isFetchPreviousPageError == other.isFetchPreviousPageError;

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        deepEq.hash(data),
        isPlaceholder,
        fetchStatus,
        dataUpdatedAt,
        dataUpdateCount,
        errorUpdatedAt,
        errorUpdateCount,
        failureCount,
        deepEq.hash(failureReason),
        isEnabled,
        isStale,
        isFetchedAfterMount,
        hasNextPage,
        hasPreviousPage,
        isFetchingNextPage,
        isFetchingPreviousPage,
        isFetchNextPageError,
        isFetchPreviousPageError,
      ]);

  @override
  String toString() => 'InfiniteQuerySuccess('
      'pages: ${data.pages.length}, '
      'isPlaceholder: $isPlaceholder, '
      'fetchStatus: $fetchStatus, '
      'isStale: $isStale)';
}

/// The infinite query encountered an error.
///
/// This is an experimental API and may change in a future minor release.
final class InfiniteQueryError<TData, TError, TPageParam>
    extends InfiniteQuerySnapshot<TData, TError, TPageParam> {
  /// Creates an error snapshot.
  const InfiniteQueryError({
    required this.error,
    required this.data,
    required super.fetchStatus,
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
    required super.fetchNextPage,
    required super.fetchPreviousPage,
    required super.hasNextPage,
    required super.hasPreviousPage,
    required super.isFetchingNextPage,
    required super.isFetchingPreviousPage,
    required super.isFetchNextPageError,
    required super.isFetchPreviousPageError,
  });

  /// The error thrown by the last failed fetch.
  final TError error;

  /// The last successfully accumulated pages, if any, preserved across the
  /// error.
  final InfiniteData<TData, TPageParam>? data;

  @override
  InfiniteData<TData, TPageParam>? get dataOrNull => data;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InfiniteQueryError<TData, TError, TPageParam> &&
          deepEq.equals(error, other.error) &&
          deepEq.equals(data, other.data) &&
          fetchStatus == other.fetchStatus &&
          dataUpdatedAt == other.dataUpdatedAt &&
          dataUpdateCount == other.dataUpdateCount &&
          errorUpdatedAt == other.errorUpdatedAt &&
          errorUpdateCount == other.errorUpdateCount &&
          failureCount == other.failureCount &&
          deepEq.equals(failureReason, other.failureReason) &&
          isEnabled == other.isEnabled &&
          isStale == other.isStale &&
          isFetchedAfterMount == other.isFetchedAfterMount &&
          hasNextPage == other.hasNextPage &&
          hasPreviousPage == other.hasPreviousPage &&
          isFetchingNextPage == other.isFetchingNextPage &&
          isFetchingPreviousPage == other.isFetchingPreviousPage &&
          isFetchNextPageError == other.isFetchNextPageError &&
          isFetchPreviousPageError == other.isFetchPreviousPageError;

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        deepEq.hash(error),
        deepEq.hash(data),
        fetchStatus,
        dataUpdatedAt,
        dataUpdateCount,
        errorUpdatedAt,
        errorUpdateCount,
        failureCount,
        deepEq.hash(failureReason),
        isEnabled,
        isStale,
        isFetchedAfterMount,
        hasNextPage,
        hasPreviousPage,
        isFetchingNextPage,
        isFetchingPreviousPage,
        isFetchNextPageError,
        isFetchPreviousPageError,
      ]);

  @override
  String toString() => 'InfiniteQueryError('
      'error: $error, '
      'pages: ${data?.pages.length}, '
      'fetchStatus: $fetchStatus, '
      'isStale: $isStale)';
}

/// Maps an [InfiniteQueryResult] into the sealed [InfiniteQuerySnapshot]
/// hierarchy.
@internal
extension InfiniteQueryResultSnapshot<TData, TError, TPageParam>
    on InfiniteQueryResult<TData, TError, TPageParam> {
  /// Converts this result into an [InfiniteQuerySnapshot].
  InfiniteQuerySnapshot<TData, TError, TPageParam> toSnapshot() {
    switch (status) {
      case QueryStatus.pending:
        return InfiniteQueryPending<TData, TError, TPageParam>(
          fetchStatus: fetchStatus,
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
          fetchNextPage: fetchNextPage,
          fetchPreviousPage: fetchPreviousPage,
          hasNextPage: hasNextPage,
          hasPreviousPage: hasPreviousPage,
          isFetchingNextPage: isFetchingNextPage,
          isFetchingPreviousPage: isFetchingPreviousPage,
          isFetchNextPageError: isFetchNextPageError,
          isFetchPreviousPageError: isFetchPreviousPageError,
        );
      case QueryStatus.success:
        return InfiniteQuerySuccess<TData, TError, TPageParam>(
          data: data as InfiniteData<TData, TPageParam>,
          isPlaceholder: isPlaceholderData,
          fetchStatus: fetchStatus,
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
          fetchNextPage: fetchNextPage,
          fetchPreviousPage: fetchPreviousPage,
          hasNextPage: hasNextPage,
          hasPreviousPage: hasPreviousPage,
          isFetchingNextPage: isFetchingNextPage,
          isFetchingPreviousPage: isFetchingPreviousPage,
          isFetchNextPageError: isFetchNextPageError,
          isFetchPreviousPageError: isFetchPreviousPageError,
        );
      case QueryStatus.error:
        return InfiniteQueryError<TData, TError, TPageParam>(
          error: error as TError,
          data: data,
          fetchStatus: fetchStatus,
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
          fetchNextPage: fetchNextPage,
          fetchPreviousPage: fetchPreviousPage,
          hasNextPage: hasNextPage,
          hasPreviousPage: hasPreviousPage,
          isFetchingNextPage: isFetchingNextPage,
          isFetchingPreviousPage: isFetchingPreviousPage,
          isFetchNextPageError: isFetchNextPageError,
          isFetchPreviousPageError: isFetchPreviousPageError,
        );
    }
  }
}
