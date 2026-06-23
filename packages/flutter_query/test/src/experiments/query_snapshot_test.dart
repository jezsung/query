import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_query/src/core/core.dart';
import 'package:flutter_query/src/experiments/query_snapshot.dart';

Refetch<TData, TError> _noopRefetch<TData, TError>() =>
    ({bool cancelRefetch = false, bool throwOnError = false}) =>
        throw UnimplementedError();

void main() {
  test('pending result maps to QueryPending with metadata', () {
    final refetch = _noopRefetch<int, Object>();
    final at = DateTime(2026, 6, 20);
    final snapshot = QueryResult<int, Object>(
      status: QueryStatus.pending,
      fetchStatus: FetchStatus.fetching,
      data: null,
      dataUpdatedAt: null,
      dataUpdateCount: 0,
      error: null,
      errorUpdatedAt: at,
      errorUpdateCount: 2,
      failureCount: 3,
      failureReason: 'boom',
      isEnabled: false,
      isStale: true,
      isFetchedAfterMount: true,
      isPlaceholderData: false,
      refetch: refetch,
    ).toSnapshot();

    expect(snapshot, isA<QueryPending<int, Object>>());
    expect(snapshot.dataOrNull, isNull);
    expect(snapshot.isFetching, isTrue);
    expect(snapshot.isPaused, isFalse);
    expect(snapshot.isLoading, isTrue);
    expect(snapshot.errorUpdatedAt, at);
    expect(snapshot.errorUpdateCount, 2);
    expect(snapshot.failureCount, 3);
    expect(snapshot.failureReason, 'boom');
    expect(snapshot.isEnabled, isFalse);
    expect(snapshot.isStale, isTrue);
    expect(snapshot.isFetchedAfterMount, isTrue);
    expect(identical(snapshot.refetch, refetch), isTrue);
  });

  test('success result maps to QuerySuccess with non-null data', () {
    final at = DateTime(2026, 6, 20);
    final snapshot = QueryResult<int, Object>(
      status: QueryStatus.success,
      fetchStatus: FetchStatus.idle,
      data: 42,
      dataUpdatedAt: at,
      dataUpdateCount: 1,
      error: null,
      errorUpdatedAt: null,
      errorUpdateCount: 0,
      failureCount: 0,
      failureReason: null,
      isEnabled: true,
      isStale: false,
      isFetchedAfterMount: false,
      isPlaceholderData: false,
      refetch: _noopRefetch<int, Object>(),
    ).toSnapshot();

    expect(snapshot, isA<QuerySuccess<int, Object>>());
    final success = snapshot as QuerySuccess<int, Object>;
    expect(success.data, 42);
    expect(success.isPlaceholder, isFalse);
    expect(success.dataOrNull, 42);
    expect(success.isIdle, isTrue);
    expect(success.isFetching, isFalse);
    expect(success.dataUpdatedAt, at);
    expect(success.dataUpdateCount, 1);
    expect(success.isFetched, isTrue);
  });

  test('placeholder success sets isPlaceholder', () {
    final snapshot = QueryResult<int, Object>(
      status: QueryStatus.success,
      fetchStatus: FetchStatus.fetching,
      data: 7,
      dataUpdatedAt: null,
      dataUpdateCount: 0,
      error: null,
      errorUpdatedAt: null,
      errorUpdateCount: 0,
      failureCount: 0,
      failureReason: null,
      isEnabled: true,
      isStale: false,
      isFetchedAfterMount: false,
      isPlaceholderData: true,
      refetch: _noopRefetch<int, Object>(),
    ).toSnapshot() as QuerySuccess<int, Object>;

    expect(snapshot.isPlaceholder, isTrue);
    expect(snapshot.isRefetching, isTrue);
  });

  test('error on first load maps to QueryError with null data', () {
    final snapshot = QueryResult<int, Object>(
      status: QueryStatus.error,
      fetchStatus: FetchStatus.idle,
      data: null,
      dataUpdatedAt: null,
      dataUpdateCount: 0,
      error: 'nope',
      errorUpdatedAt: null,
      errorUpdateCount: 1,
      failureCount: 0,
      failureReason: null,
      isEnabled: true,
      isStale: false,
      isFetchedAfterMount: false,
      isPlaceholderData: false,
      refetch: _noopRefetch<int, Object>(),
    ).toSnapshot();

    expect(snapshot, isA<QueryError<int, Object>>());
    final err = snapshot as QueryError<int, Object>;
    expect(err.error, 'nope');
    expect(err.data, isNull);
    expect(err.dataOrNull, isNull);
    expect(err.isLoadingError, isTrue);
    expect(err.isRefetchError, isFalse);
  });

  test('error with prior data preserves it (refetch error)', () {
    final snapshot = QueryResult<int, Object>(
      status: QueryStatus.error,
      fetchStatus: FetchStatus.idle,
      data: 99,
      dataUpdatedAt: null,
      dataUpdateCount: 0,
      error: 'stale',
      errorUpdatedAt: null,
      errorUpdateCount: 0,
      failureCount: 0,
      failureReason: null,
      isEnabled: true,
      isStale: false,
      isFetchedAfterMount: false,
      isPlaceholderData: false,
      refetch: _noopRefetch<int, Object>(),
    ).toSnapshot() as QueryError<int, Object>;

    expect(snapshot.data, 99);
    expect(snapshot.dataOrNull, 99);
    expect(snapshot.isLoadingError, isFalse);
    expect(snapshot.isRefetchError, isTrue);
  });

  test('paused fetch status maps to isPaused', () {
    final snapshot = QueryResult<int, Object>(
      status: QueryStatus.pending,
      fetchStatus: FetchStatus.paused,
      data: null,
      dataUpdatedAt: null,
      dataUpdateCount: 0,
      error: null,
      errorUpdatedAt: null,
      errorUpdateCount: 0,
      failureCount: 0,
      failureReason: null,
      isEnabled: true,
      isStale: false,
      isFetchedAfterMount: false,
      isPlaceholderData: false,
      refetch: _noopRefetch<int, Object>(),
    ).toSnapshot();

    expect(snapshot.isPaused, isTrue);
    expect(snapshot.isFetching, isFalse);
    expect(snapshot.isIdle, isFalse);
  });

  test('value equality holds for identical snapshots', () {
    final refetch = _noopRefetch<int, Object>();
    QuerySnapshot<int, Object> make() => QueryResult<int, Object>(
          status: QueryStatus.success,
          fetchStatus: FetchStatus.idle,
          data: 5,
          dataUpdatedAt: null,
          dataUpdateCount: 1,
          error: null,
          errorUpdatedAt: null,
          errorUpdateCount: 0,
          failureCount: 0,
          failureReason: null,
          isEnabled: true,
          isStale: false,
          isFetchedAfterMount: false,
          isPlaceholderData: false,
          refetch: refetch,
        ).toSnapshot();

    expect(make(), make());
    expect(make().hashCode, make().hashCode);
  });

  test('different variants are not equal', () {
    final refetch = _noopRefetch<int, Object>();
    final pending = QueryResult<int, Object>(
      status: QueryStatus.pending,
      fetchStatus: FetchStatus.fetching,
      data: null,
      dataUpdatedAt: null,
      dataUpdateCount: 0,
      error: null,
      errorUpdatedAt: null,
      errorUpdateCount: 0,
      failureCount: 0,
      failureReason: null,
      isEnabled: true,
      isStale: false,
      isFetchedAfterMount: false,
      isPlaceholderData: false,
      refetch: refetch,
    ).toSnapshot();
    final success = QueryResult<int, Object>(
      status: QueryStatus.success,
      fetchStatus: FetchStatus.idle,
      data: 1,
      dataUpdatedAt: null,
      dataUpdateCount: 0,
      error: null,
      errorUpdatedAt: null,
      errorUpdateCount: 0,
      failureCount: 0,
      failureReason: null,
      isEnabled: true,
      isStale: false,
      isFetchedAfterMount: false,
      isPlaceholderData: false,
      refetch: refetch,
    ).toSnapshot();

    expect(pending == success, isFalse);
  });

  test('QueryPending equality: field-identical snapshots are equal', () {
    final refetch = _noopRefetch<int, Object>();
    final pending1 = QueryResult<int, Object>(
      status: QueryStatus.pending,
      fetchStatus: FetchStatus.fetching,
      data: null,
      dataUpdatedAt: null,
      dataUpdateCount: 0,
      error: null,
      errorUpdatedAt: null,
      errorUpdateCount: 0,
      failureCount: 2,
      failureReason: null,
      isEnabled: true,
      isStale: true,
      isFetchedAfterMount: false,
      isPlaceholderData: false,
      refetch: refetch,
    ).toSnapshot();
    final pending2 = QueryResult<int, Object>(
      status: QueryStatus.pending,
      fetchStatus: FetchStatus.fetching,
      data: null,
      dataUpdatedAt: null,
      dataUpdateCount: 0,
      error: null,
      errorUpdatedAt: null,
      errorUpdateCount: 0,
      failureCount: 2,
      failureReason: null,
      isEnabled: true,
      isStale: true,
      isFetchedAfterMount: false,
      isPlaceholderData: false,
      refetch: refetch,
    ).toSnapshot();

    expect(pending1, pending2);
    expect(pending1.hashCode, pending2.hashCode);
  });

  test('QueryPending equality: different failureCount is not equal', () {
    final refetch = _noopRefetch<int, Object>();
    final pending1 = QueryResult<int, Object>(
      status: QueryStatus.pending,
      fetchStatus: FetchStatus.fetching,
      data: null,
      dataUpdatedAt: null,
      dataUpdateCount: 0,
      error: null,
      errorUpdatedAt: null,
      errorUpdateCount: 0,
      failureCount: 2,
      failureReason: null,
      isEnabled: true,
      isStale: true,
      isFetchedAfterMount: false,
      isPlaceholderData: false,
      refetch: refetch,
    ).toSnapshot();
    final pending2 = QueryResult<int, Object>(
      status: QueryStatus.pending,
      fetchStatus: FetchStatus.fetching,
      data: null,
      dataUpdatedAt: null,
      dataUpdateCount: 0,
      error: null,
      errorUpdatedAt: null,
      errorUpdateCount: 0,
      failureCount: 3,
      failureReason: null,
      isEnabled: true,
      isStale: true,
      isFetchedAfterMount: false,
      isPlaceholderData: false,
      refetch: refetch,
    ).toSnapshot();

    expect(pending1 == pending2, isFalse);
  });

  test('QueryPending equality: different isStale is not equal', () {
    final refetch = _noopRefetch<int, Object>();
    final pending1 = QueryResult<int, Object>(
      status: QueryStatus.pending,
      fetchStatus: FetchStatus.fetching,
      data: null,
      dataUpdatedAt: null,
      dataUpdateCount: 0,
      error: null,
      errorUpdatedAt: null,
      errorUpdateCount: 0,
      failureCount: 2,
      failureReason: null,
      isEnabled: true,
      isStale: true,
      isFetchedAfterMount: false,
      isPlaceholderData: false,
      refetch: refetch,
    ).toSnapshot();
    final pending2 = QueryResult<int, Object>(
      status: QueryStatus.pending,
      fetchStatus: FetchStatus.fetching,
      data: null,
      dataUpdatedAt: null,
      dataUpdateCount: 0,
      error: null,
      errorUpdatedAt: null,
      errorUpdateCount: 0,
      failureCount: 2,
      failureReason: null,
      isEnabled: true,
      isStale: false,
      isFetchedAfterMount: false,
      isPlaceholderData: false,
      refetch: refetch,
    ).toSnapshot();

    expect(pending1 == pending2, isFalse);
  });

  test('QuerySuccess equality: field-identical snapshots are equal', () {
    final refetch = _noopRefetch<int, Object>();
    final success1 = QueryResult<int, Object>(
      status: QueryStatus.success,
      fetchStatus: FetchStatus.idle,
      data: 42,
      dataUpdatedAt: null,
      dataUpdateCount: 1,
      error: null,
      errorUpdatedAt: null,
      errorUpdateCount: 0,
      failureCount: 0,
      failureReason: null,
      isEnabled: true,
      isStale: false,
      isFetchedAfterMount: false,
      isPlaceholderData: false,
      refetch: refetch,
    ).toSnapshot();
    final success2 = QueryResult<int, Object>(
      status: QueryStatus.success,
      fetchStatus: FetchStatus.idle,
      data: 42,
      dataUpdatedAt: null,
      dataUpdateCount: 1,
      error: null,
      errorUpdatedAt: null,
      errorUpdateCount: 0,
      failureCount: 0,
      failureReason: null,
      isEnabled: true,
      isStale: false,
      isFetchedAfterMount: false,
      isPlaceholderData: false,
      refetch: refetch,
    ).toSnapshot();

    expect(success1, success2);
    expect(success1.hashCode, success2.hashCode);
  });

  test('QuerySuccess equality: different dataUpdateCount is not equal', () {
    final refetch = _noopRefetch<int, Object>();
    final success1 = QueryResult<int, Object>(
      status: QueryStatus.success,
      fetchStatus: FetchStatus.idle,
      data: 42,
      dataUpdatedAt: null,
      dataUpdateCount: 1,
      error: null,
      errorUpdatedAt: null,
      errorUpdateCount: 0,
      failureCount: 0,
      failureReason: null,
      isEnabled: true,
      isStale: false,
      isFetchedAfterMount: false,
      isPlaceholderData: false,
      refetch: refetch,
    ).toSnapshot();
    final success2 = QueryResult<int, Object>(
      status: QueryStatus.success,
      fetchStatus: FetchStatus.idle,
      data: 42,
      dataUpdatedAt: null,
      dataUpdateCount: 2,
      error: null,
      errorUpdatedAt: null,
      errorUpdateCount: 0,
      failureCount: 0,
      failureReason: null,
      isEnabled: true,
      isStale: false,
      isFetchedAfterMount: false,
      isPlaceholderData: false,
      refetch: refetch,
    ).toSnapshot();

    expect(success1 == success2, isFalse);
  });

  test('QuerySuccess equality: different isStale is not equal', () {
    final refetch = _noopRefetch<int, Object>();
    final success1 = QueryResult<int, Object>(
      status: QueryStatus.success,
      fetchStatus: FetchStatus.idle,
      data: 42,
      dataUpdatedAt: null,
      dataUpdateCount: 1,
      error: null,
      errorUpdatedAt: null,
      errorUpdateCount: 0,
      failureCount: 0,
      failureReason: null,
      isEnabled: true,
      isStale: false,
      isFetchedAfterMount: false,
      isPlaceholderData: false,
      refetch: refetch,
    ).toSnapshot();
    final success2 = QueryResult<int, Object>(
      status: QueryStatus.success,
      fetchStatus: FetchStatus.idle,
      data: 42,
      dataUpdatedAt: null,
      dataUpdateCount: 1,
      error: null,
      errorUpdatedAt: null,
      errorUpdateCount: 0,
      failureCount: 0,
      failureReason: null,
      isEnabled: true,
      isStale: true,
      isFetchedAfterMount: false,
      isPlaceholderData: false,
      refetch: refetch,
    ).toSnapshot();

    expect(success1 == success2, isFalse);
  });

  test('QueryError equality: field-identical snapshots are equal', () {
    final refetch = _noopRefetch<int, Object>();
    final error1 = QueryResult<int, Object>(
      status: QueryStatus.error,
      fetchStatus: FetchStatus.idle,
      data: 99,
      dataUpdatedAt: null,
      dataUpdateCount: 0,
      error: 'oops',
      errorUpdatedAt: null,
      errorUpdateCount: 1,
      failureCount: 0,
      failureReason: null,
      isEnabled: true,
      isStale: false,
      isFetchedAfterMount: false,
      isPlaceholderData: false,
      refetch: refetch,
    ).toSnapshot();
    final error2 = QueryResult<int, Object>(
      status: QueryStatus.error,
      fetchStatus: FetchStatus.idle,
      data: 99,
      dataUpdatedAt: null,
      dataUpdateCount: 0,
      error: 'oops',
      errorUpdatedAt: null,
      errorUpdateCount: 1,
      failureCount: 0,
      failureReason: null,
      isEnabled: true,
      isStale: false,
      isFetchedAfterMount: false,
      isPlaceholderData: false,
      refetch: refetch,
    ).toSnapshot();

    expect(error1, error2);
    expect(error1.hashCode, error2.hashCode);
  });

  test('QueryError equality: different isPaused (via fetchStatus) is not equal',
      () {
    final refetch = _noopRefetch<int, Object>();
    final error1 = QueryResult<int, Object>(
      status: QueryStatus.error,
      fetchStatus: FetchStatus.idle,
      data: 99,
      dataUpdatedAt: null,
      dataUpdateCount: 0,
      error: 'oops',
      errorUpdatedAt: null,
      errorUpdateCount: 1,
      failureCount: 0,
      failureReason: null,
      isEnabled: true,
      isStale: false,
      isFetchedAfterMount: false,
      isPlaceholderData: false,
      refetch: refetch,
    ).toSnapshot();
    final error2 = QueryResult<int, Object>(
      status: QueryStatus.error,
      fetchStatus: FetchStatus.paused,
      data: 99,
      dataUpdatedAt: null,
      dataUpdateCount: 0,
      error: 'oops',
      errorUpdatedAt: null,
      errorUpdateCount: 1,
      failureCount: 0,
      failureReason: null,
      isEnabled: true,
      isStale: false,
      isFetchedAfterMount: false,
      isPlaceholderData: false,
      refetch: refetch,
    ).toSnapshot();

    expect(error1 == error2, isFalse);
  });

  test('QueryError equality: different errorUpdateCount is not equal', () {
    final refetch = _noopRefetch<int, Object>();
    final error1 = QueryResult<int, Object>(
      status: QueryStatus.error,
      fetchStatus: FetchStatus.idle,
      data: 99,
      dataUpdatedAt: null,
      dataUpdateCount: 0,
      error: 'oops',
      errorUpdatedAt: null,
      errorUpdateCount: 1,
      failureCount: 0,
      failureReason: null,
      isEnabled: true,
      isStale: false,
      isFetchedAfterMount: false,
      isPlaceholderData: false,
      refetch: refetch,
    ).toSnapshot();
    final error2 = QueryResult<int, Object>(
      status: QueryStatus.error,
      fetchStatus: FetchStatus.idle,
      data: 99,
      dataUpdatedAt: null,
      dataUpdateCount: 0,
      error: 'oops',
      errorUpdatedAt: null,
      errorUpdateCount: 2,
      failureCount: 0,
      failureReason: null,
      isEnabled: true,
      isStale: false,
      isFetchedAfterMount: false,
      isPlaceholderData: false,
      refetch: refetch,
    ).toSnapshot();

    expect(error1 == error2, isFalse);
  });

  test('QueryError equality: different preserved data is not equal', () {
    final refetch = _noopRefetch<int, Object>();
    final error1 = QueryResult<int, Object>(
      status: QueryStatus.error,
      fetchStatus: FetchStatus.idle,
      data: 1,
      dataUpdatedAt: null,
      dataUpdateCount: 0,
      error: 'oops',
      errorUpdatedAt: null,
      errorUpdateCount: 1,
      failureCount: 0,
      failureReason: null,
      isEnabled: true,
      isStale: false,
      isFetchedAfterMount: false,
      isPlaceholderData: false,
      refetch: refetch,
    ).toSnapshot();
    final error2 = QueryResult<int, Object>(
      status: QueryStatus.error,
      fetchStatus: FetchStatus.idle,
      data: 2,
      dataUpdatedAt: null,
      dataUpdateCount: 0,
      error: 'oops',
      errorUpdatedAt: null,
      errorUpdateCount: 1,
      failureCount: 0,
      failureReason: null,
      isEnabled: true,
      isStale: false,
      isFetchedAfterMount: false,
      isPlaceholderData: false,
      refetch: refetch,
    ).toSnapshot();

    expect(error1 == error2, isFalse);
  });

  test('nullable type argument: QuerySuccess with null data', () {
    final refetch = _noopRefetch<int?, Object>();
    final snapshot = QueryResult<int?, Object>(
      status: QueryStatus.success,
      fetchStatus: FetchStatus.idle,
      data: null,
      dataUpdatedAt: null,
      dataUpdateCount: 0,
      error: null,
      errorUpdatedAt: null,
      errorUpdateCount: 0,
      failureCount: 0,
      failureReason: null,
      isEnabled: true,
      isStale: false,
      isFetchedAfterMount: false,
      isPlaceholderData: false,
      refetch: refetch,
    ).toSnapshot();

    expect(snapshot, isA<QuerySuccess<int?, Object>>());
    final success = snapshot as QuerySuccess<int?, Object>;
    expect(success.data, isNull);
    expect(success.dataOrNull, isNull);
  });
}
