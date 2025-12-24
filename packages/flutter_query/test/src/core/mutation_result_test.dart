import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_query/flutter_query.dart';

void main() {
  group('toString', () {
    test(
        'SHOULD return debug-friendly string '
        'WHEN called with default fields', () {
      final result = MutationResult<String, Exception, int, void>(
        status: MutationStatus.idle,
        data: null,
        error: null,
        variables: null,
        submittedAt: null,
        failureCount: 0,
        failureReason: null,
        isPaused: false,
        mutate: (_) async => '',
        reset: () {},
      );

      expect(
        result.toString(),
        'MutationResult('
        'status: MutationStatus.idle, '
        'data: null, '
        'error: null, '
        'variables: null, '
        'submittedAt: null, '
        'failureCount: 0, '
        'failureReason: null, '
        'isPaused: false, '
        'mutate: <Function>, '
        'reset: <Function>)',
      );
    });

    test(
        'SHOULD return debug-friendly string '
        'WHEN called with all fields', () {
      final now = DateTime(2024, 1, 1, 12, 0, 0);
      final error = Exception('test error');
      final result = MutationResult<String, Exception, int, void>(
        status: MutationStatus.success,
        data: 'result',
        error: error,
        variables: 42,
        submittedAt: now,
        failureCount: 2,
        failureReason: error,
        isPaused: true,
        mutate: (_) async => '',
        reset: () {},
      );

      expect(
        result.toString(),
        'MutationResult('
        'status: MutationStatus.success, '
        'data: result, '
        'error: $error, '
        'variables: 42, '
        'submittedAt: $now, '
        'failureCount: 2, '
        'failureReason: $error, '
        'isPaused: true, '
        'mutate: <Function>, '
        'reset: <Function>)',
      );
    });
  });
}
