import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_query/src/core/core.dart';

void main() {
  group('toString', () {
    test(
        'SHOULD return debug-friendly string '
        'WHEN idle', () {
      final snapshot = MutationIdle<String, Exception, int>(
        submittedAt: null,
        failureCount: 0,
        failureReason: null,
        isPaused: false,
        mutate: (_) {},
        mutateAsync: (_) async => '',
        reset: () {},
      );

      expect(snapshot.toString(), 'MutationIdle(isPaused: false)');
    });

    test(
        'SHOULD return debug-friendly string '
        'WHEN pending', () {
      final snapshot = MutationPending<String, Exception, int>(
        variables: 42,
        submittedAt: DateTime(2024, 1, 1, 12, 0, 0),
        failureCount: 0,
        failureReason: null,
        isPaused: true,
        mutate: (_) {},
        mutateAsync: (_) async => '',
        reset: () {},
      );

      expect(
        snapshot.toString(),
        'MutationPending(variables: 42, isPaused: true)',
      );
    });

    test(
        'SHOULD return debug-friendly string '
        'WHEN success', () {
      final snapshot = MutationSuccess<String, Exception, int>(
        data: 'result',
        variables: 42,
        submittedAt: DateTime(2024, 1, 1, 12, 0, 0),
        failureCount: 0,
        failureReason: null,
        isPaused: false,
        mutate: (_) {},
        mutateAsync: (_) async => '',
        reset: () {},
      );

      expect(
        snapshot.toString(),
        'MutationSuccess(data: result, variables: 42)',
      );
    });

    test(
        'SHOULD return debug-friendly string '
        'WHEN error', () {
      final error = Exception('test error');
      final snapshot = MutationError<String, Exception, int>(
        error: error,
        variables: 42,
        submittedAt: DateTime(2024, 1, 1, 12, 0, 0),
        failureCount: 2,
        failureReason: error,
        isPaused: false,
        mutate: (_) {},
        mutateAsync: (_) async => '',
        reset: () {},
      );

      expect(
        snapshot.toString(),
        'MutationError(error: $error, variables: 42)',
      );
    });
  });
}
