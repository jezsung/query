import 'package:test/test.dart';

import 'package:flutter_query/src/core/utils.dart';

void main() {
  group('Function: retryExponentialBackoff', () {
    test(
        'SHOULD return 1s delay '
        'WHEN retryCount == 0', () {
      final delay = retryExponentialBackoff(0, null);
      expect(delay, Duration(seconds: 1));
    });

    test(
        'SHOULD return 2s delay '
        'WHEN retryCount == 1', () {
      final delay = retryExponentialBackoff(1, null);
      expect(delay, Duration(seconds: 2));
    });

    test(
        'SHOULD return 4s delay '
        'WHEN retryCount == 2', () {
      final delay = retryExponentialBackoff(2, null);
      expect(delay, Duration(seconds: 4));
    });

    test(
        'SHOULD return null '
        'WHEN retryCount >= 3', () {
      for (final input in [3, 4, 5, 6, 7, 8, 9, 10, 20, 100]) {
        final delay = retryExponentialBackoff(input, null);
        expect(delay, isNull);
      }
    });

    test(
        'SHOULD throw ArgumentError '
        'WHEN retryCount < 0', () {
      for (final input in [-1, -2, -3, -10, -100]) {
        expect(
          () => retryExponentialBackoff(input, null),
          throwsArgumentError,
        );
      }
    });

    test(
        'SHOULD ignore error parameter'
        '', () {
      final delay1 = retryExponentialBackoff(0, Exception('error'));
      final delay2 = retryExponentialBackoff(0, 'string error');
      final delay3 = retryExponentialBackoff(0, 42);

      expect(delay1, Duration(seconds: 1));
      expect(delay2, Duration(seconds: 1));
      expect(delay3, Duration(seconds: 1));
    });
  });
}
