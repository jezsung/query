import 'package:fluery/fluery.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QueryStatusExtension', () {
    test('isIdle returns true for idle status', () {
      expect(QueryStatus.idle.isIdle, isTrue);
    });

    test('isFetching returns true for fetching status', () {
      expect(QueryStatus.fetching.isFetching, isTrue);
    });

    test('isRetrying returns true for retrying status', () {
      expect(QueryStatus.retrying.isRetrying, isTrue);
    });

    test('isSuccess returns true for success status', () {
      expect(QueryStatus.success.isSuccess, isTrue);
    });

    test('isFailure returns true for failure status', () {
      expect(QueryStatus.failure.isFailure, isTrue);
    });
  });
}
