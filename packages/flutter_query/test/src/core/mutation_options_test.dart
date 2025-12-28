import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_query/src/core/core.dart';

void main() {
  group('toString', () {
    test(
        'SHOULD return debug-friendly string '
        'WHEN called with default fields', () {
      final options = MutationOptions<String, Exception, int, void>(
        mutationFn: (variables, context) async => 'result',
      );

      expect(
        options.toString(),
        'MutationOptions('
        'onMutate: null, '
        'onSuccess: null, '
        'onError: null, '
        'onSettled: null, '
        'mutationKey: null, '
        'retry: null, '
        'gcDuration: null, '
        'meta: null)',
      );
    });

    test(
        'SHOULD return debug-friendly string '
        'WHEN called with all fields', () {
      const gcDuration = GcDuration(minutes: 10);

      final options = MutationOptions<String, Exception, int, void>(
        mutationFn: (variables, context) async => 'result',
        mutationKey: ['users', 'update'],
        meta: {'priority': 'high'},
        onMutate: (variables, context) => null,
        onSuccess: (data, variables, onMutateResult, context) {},
        onError: (error, variables, onMutateResult, context) {},
        onSettled: (data, error, variables, onMutateResult, context) {},
        retry: (_, __) => null,
        gcDuration: gcDuration,
      );

      expect(
        options.toString(),
        'MutationOptions('
        'onMutate: <Function>, '
        'onSuccess: <Function>, '
        'onError: <Function>, '
        'onSettled: <Function>, '
        'mutationKey: [users, update], '
        'retry: <Function>, '
        'gcDuration: $gcDuration, '
        'meta: {priority: high})',
      );
    });
  });
}
