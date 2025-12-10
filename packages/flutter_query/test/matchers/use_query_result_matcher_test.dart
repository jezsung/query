import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_query/src/core/query.dart';
import 'package:flutter_query/src/hooks/use_query.dart';
import 'use_query_result_matcher.dart';

const _undefined = Object();

extension CopyWith<TData, TError> on UseQueryResult<TData, TError> {
  UseQueryResult<TData, TError> copyWith({
    QueryStatus? status,
    FetchStatus? fetchStatus,
    Object? data = _undefined,
    Object? dataUpdatedAt = _undefined,
    Object? error = _undefined,
    Object? errorUpdatedAt = _undefined,
    int? errorUpdateCount,
    bool? isEnabled,
    StaleDuration? staleDuration,
  }) {
    return UseQueryResult<TData, TError>(
      status: status ?? this.status,
      fetchStatus: fetchStatus ?? this.fetchStatus,
      data: data == _undefined ? this.data : data as TData?,
      dataUpdatedAt: dataUpdatedAt == _undefined
          ? this.dataUpdatedAt
          : dataUpdatedAt as DateTime?,
      error: error == _undefined ? this.error : error as TError?,
      errorUpdatedAt: errorUpdatedAt == _undefined
          ? this.errorUpdatedAt
          : errorUpdatedAt as DateTime?,
      errorUpdateCount: errorUpdateCount ?? this.errorUpdateCount,
      isEnabled: isEnabled ?? this.isEnabled,
      staleDuration: staleDuration ?? StaleDuration.zero,
    );
  }
}

Matcher matchesUseQueryResult<TData, TError>(
  UseQueryResult<TData, TError> result,
) {
  return isUseQueryResult(
    status: result.status,
    fetchStatus: result.fetchStatus,
    data: result.data,
    dataUpdatedAt: result.dataUpdatedAt,
    error: result.error,
    errorUpdatedAt: result.errorUpdatedAt,
    errorUpdateCount: result.errorUpdateCount,
    isEnabled: result.isEnabled,
  );
}

void main() {
  group('isUseQueryResult matcher', () {
    test('SHOULD match WHEN all fields match', () {
      final result1 = UseQueryResult(
        status: QueryStatus.success,
        fetchStatus: FetchStatus.idle,
        data: 'test data',
        dataUpdatedAt: DateTime(2024, 1, 1),
        error: null,
        errorUpdatedAt: null,
        errorUpdateCount: 0,
        isEnabled: true,
        staleDuration: StaleDuration.zero,
      );
      final result2 = result1.copyWith();

      expect(result1, matchesUseQueryResult(result2));
    });

    test('SHOULD NOT match WHEN status differs', () {
      final result1 = UseQueryResult(
        status: QueryStatus.error,
        fetchStatus: FetchStatus.idle,
        data: null,
        dataUpdatedAt: null,
        error: 'error',
        errorUpdatedAt: null,
        errorUpdateCount: 0,
        isEnabled: true,
        staleDuration: StaleDuration.zero,
      );
      final result2 = result1.copyWith(status: QueryStatus.success);

      expect(result1, isNot(matchesUseQueryResult(result2)));
    });

    test('SHOULD NOT match WHEN fetchStatus differs', () {
      final result1 = UseQueryResult(
        status: QueryStatus.success,
        fetchStatus: FetchStatus.fetching,
        data: 'test data',
        dataUpdatedAt: null,
        error: null,
        errorUpdatedAt: null,
        errorUpdateCount: 0,
        isEnabled: true,
        staleDuration: StaleDuration.zero,
      );
      final result2 = result1.copyWith(fetchStatus: FetchStatus.idle);

      expect(result1, isNot(matchesUseQueryResult(result2)));
    });

    test('SHOULD NOT match WHEN data differs', () {
      final result1 = UseQueryResult(
        status: QueryStatus.success,
        fetchStatus: FetchStatus.idle,
        data: 'actual data',
        dataUpdatedAt: null,
        error: null,
        errorUpdatedAt: null,
        errorUpdateCount: 0,
        isEnabled: true,
        staleDuration: StaleDuration.zero,
      );
      final result2 = result1.copyWith(data: 'expected data');

      expect(result1, isNot(matchesUseQueryResult(result2)));
    });

    test('SHOULD NOT match WHEN dataUpdatedAt differs', () {
      final result1 = UseQueryResult(
        status: QueryStatus.success,
        fetchStatus: FetchStatus.idle,
        data: 'test data',
        dataUpdatedAt: DateTime(2024, 1, 1),
        error: null,
        errorUpdatedAt: null,
        errorUpdateCount: 0,
        isEnabled: true,
        staleDuration: StaleDuration.zero,
      );
      final result2 = result1.copyWith(dataUpdatedAt: DateTime(2024, 1, 2));

      expect(result1, isNot(matchesUseQueryResult(result2)));
    });

    test('SHOULD NOT match WHEN error differs', () {
      final result1 = UseQueryResult(
        status: QueryStatus.error,
        fetchStatus: FetchStatus.idle,
        data: null,
        dataUpdatedAt: null,
        error: 'actual error',
        errorUpdatedAt: null,
        errorUpdateCount: 1,
        isEnabled: true,
        staleDuration: StaleDuration.zero,
      );
      final result2 = result1.copyWith(error: 'expected error');

      expect(result1, isNot(matchesUseQueryResult(result2)));
    });

    test('SHOULD NOT match WHEN errorUpdatedAt differs', () {
      final result1 = UseQueryResult(
        status: QueryStatus.error,
        fetchStatus: FetchStatus.idle,
        data: null,
        dataUpdatedAt: null,
        error: 'error',
        errorUpdatedAt: DateTime(2024, 1, 1),
        errorUpdateCount: 1,
        isEnabled: true,
        staleDuration: StaleDuration.zero,
      );
      final result2 = result1.copyWith(errorUpdatedAt: DateTime(2024, 1, 2));

      expect(result1, isNot(matchesUseQueryResult(result2)));
    });

    test('SHOULD NOT match WHEN errorUpdateCount differs', () {
      final result1 = UseQueryResult(
        status: QueryStatus.success,
        fetchStatus: FetchStatus.idle,
        data: 'test data',
        dataUpdatedAt: DateTime(2024, 1, 1),
        error: null,
        errorUpdatedAt: null,
        errorUpdateCount: 5,
        isEnabled: true,
        staleDuration: StaleDuration.zero,
      );
      final result2 = result1.copyWith(errorUpdateCount: 0);

      expect(result1, isNot(matchesUseQueryResult(result2)));
    });

    test('SHOULD NOT match WHEN isEnabled differs', () {
      final result1 = UseQueryResult(
        status: QueryStatus.success,
        fetchStatus: FetchStatus.idle,
        data: 'test data',
        dataUpdatedAt: null,
        error: null,
        errorUpdatedAt: null,
        errorUpdateCount: 0,
        isEnabled: false,
        staleDuration: StaleDuration.zero,
      );
      final result2 = result1.copyWith(isEnabled: true);

      expect(result1, isNot(matchesUseQueryResult(result2)));
    });

    test('SHOULD match dataUpdatedAt using Matcher', () {
      final result = UseQueryResult(
        status: QueryStatus.success,
        fetchStatus: FetchStatus.idle,
        data: 'test',
        dataUpdatedAt: DateTime(2024, 1, 1),
        error: null,
        errorUpdatedAt: null,
        errorUpdateCount: 0,
        isEnabled: true,
        staleDuration: StaleDuration.zero,
      );

      expect(
        result,
        isUseQueryResult(
          status: QueryStatus.success,
          fetchStatus: FetchStatus.idle,
          data: 'test',
          dataUpdatedAt: isNotNull, // Matcher instead of exact DateTime
          error: null,
          errorUpdatedAt: null,
          errorUpdateCount: 0,
          isEnabled: true,
        ),
      );

      expect(
        result,
        isUseQueryResult(
          status: QueryStatus.success,
          fetchStatus: FetchStatus.idle,
          data: 'test',
          dataUpdatedAt: isA<DateTime>(), // Type matcher
          error: null,
          errorUpdatedAt: null,
          errorUpdateCount: 0,
          isEnabled: true,
        ),
      );
    });

    test('SHOULD match errorUpdatedAt using Matcher', () {
      final result = UseQueryResult(
        status: QueryStatus.error,
        fetchStatus: FetchStatus.idle,
        data: null,
        dataUpdatedAt: null,
        error: 'error',
        errorUpdatedAt: DateTime(2024, 1, 1),
        errorUpdateCount: 1,
        isEnabled: true,
        staleDuration: StaleDuration.zero,
      );

      expect(
        result,
        isUseQueryResult(
          status: QueryStatus.error,
          fetchStatus: FetchStatus.idle,
          data: null,
          dataUpdatedAt: null,
          error: 'error',
          errorUpdatedAt: isNotNull, // Matcher instead of exact DateTime
          errorUpdateCount: 1,
          isEnabled: true,
        ),
      );

      expect(
        result,
        isUseQueryResult(
          status: QueryStatus.error,
          fetchStatus: FetchStatus.idle,
          data: null,
          dataUpdatedAt: null,
          error: 'error',
          errorUpdatedAt: isA<DateTime>(), // Type matcher
          errorUpdateCount: 1,
          isEnabled: true,
        ),
      );
    });

    test('SHOULD NOT match dataUpdatedAt WHEN Matcher fails', () {
      final result = UseQueryResult(
        status: QueryStatus.success,
        fetchStatus: FetchStatus.idle,
        data: 'test',
        dataUpdatedAt: null,
        error: null,
        errorUpdatedAt: null,
        errorUpdateCount: 0,
        isEnabled: true,
        staleDuration: StaleDuration.zero,
      );

      expect(
        result,
        isNot(isUseQueryResult(
          status: QueryStatus.success,
          fetchStatus: FetchStatus.idle,
          data: 'test',
          dataUpdatedAt: isNotNull, // Will fail since dataUpdatedAt is null
          error: null,
          errorUpdatedAt: null,
          errorUpdateCount: 0,
          isEnabled: true,
        )),
      );
    });
  });
}
