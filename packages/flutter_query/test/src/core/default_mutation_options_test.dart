import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_query/src/core/core.dart';

void main() {
  group('toString', () {
    test(
        'SHOULD return debug-friendly string '
        'WHEN called with default fields', () {
      const options = DefaultMutationOptions();

      expect(
        options.toString(),
        'DefaultMutationOptions('
        'gcDuration: ${const GcDuration(minutes: 5)}, '
        'retry: <Function>)',
      );
    });

    test(
        'SHOULD return debug-friendly string '
        'WHEN called with all fields', () {
      final options = DefaultMutationOptions(
        retry: (_, __) => const Duration(seconds: 1),
        gcDuration: const GcDuration(minutes: 10),
      );

      expect(
        options.toString(),
        'DefaultMutationOptions('
        'gcDuration: ${const GcDuration(minutes: 10)}, '
        'retry: <Function>)',
      );
    });
  });
}
