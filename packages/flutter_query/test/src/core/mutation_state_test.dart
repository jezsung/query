import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_query/src/core/core.dart';

void main() {
  group('equality', () {
    test(
        'SHOULD be equal '
        'WHEN both states are default', () {
      const state1 = MutationState<String, Exception, int, void>();
      const state2 = MutationState<String, Exception, int, void>();

      expect(state1, equals(state2));
      expect(state1.hashCode, equals(state2.hashCode));
    });

    test(
        'SHOULD be equal '
        'WHEN both states have same values', () {
      final now = DateTime.now();
      final error = Exception('error');
      final state1 = MutationState<String, Exception, int, String>(
        status: MutationStatus.success,
        data: 'result',
        error: error,
        variables: 42,
        onMutateResult: 'context',
        submittedAt: now,
        failureCount: 1,
        failureReason: error,
        isPaused: false,
      );
      final state2 = MutationState<String, Exception, int, String>(
        status: MutationStatus.success,
        data: 'result',
        error: error,
        variables: 42,
        onMutateResult: 'context',
        submittedAt: now,
        failureCount: 1,
        failureReason: error,
        isPaused: false,
      );

      expect(state1, equals(state2));
      expect(state1.hashCode, equals(state2.hashCode));
    });

    test(
        'SHOULD be equal '
        'WHEN comparing identical state', () {
      const state = MutationState<String, Exception, int, void>(
        status: MutationStatus.success,
        data: 'result',
      );

      expect(state, equals(state));
    });

    test(
        'SHOULD NOT be equal '
        'WHEN any param is different', () {
      // status
      const statusState1 = MutationState<String, Exception, int, void>(
        status: MutationStatus.idle,
      );
      const statusState2 = MutationState<String, Exception, int, void>(
        status: MutationStatus.pending,
      );

      expect(statusState1, isNot(equals(statusState2)));

      // data
      const dataState1 = MutationState<String, Exception, int, void>(
        data: 'result1',
      );
      const dataState2 = MutationState<String, Exception, int, void>(
        data: 'result2',
      );

      expect(dataState1, isNot(equals(dataState2)));

      // error
      final errorState1 = MutationState<String, Exception, int, void>(
        error: Exception('error1'),
      );
      final errorState2 = MutationState<String, Exception, int, void>(
        error: Exception('error2'),
      );

      expect(errorState1, isNot(equals(errorState2)));

      // variables
      const variablesState1 = MutationState<String, Exception, int, void>(
        variables: 1,
      );
      const variablesState2 = MutationState<String, Exception, int, void>(
        variables: 2,
      );

      expect(variablesState1, isNot(equals(variablesState2)));

      // onMutateResult
      const onMutateResultState1 =
          MutationState<String, Exception, int, String>(
        onMutateResult: 'context1',
      );
      const onMutateResultState2 =
          MutationState<String, Exception, int, String>(
        onMutateResult: 'context2',
      );

      expect(onMutateResultState1, isNot(equals(onMutateResultState2)));

      // submittedAt
      final now = DateTime.now();
      final submittedAtState1 = MutationState<String, Exception, int, void>(
        submittedAt: now,
      );
      final submittedAtState2 = MutationState<String, Exception, int, void>(
        submittedAt: now.add(const Duration(seconds: 1)),
      );

      expect(submittedAtState1, isNot(equals(submittedAtState2)));

      // failureCount
      const failureCountState1 = MutationState<String, Exception, int, void>(
        failureCount: 1,
      );
      const failureCountState2 = MutationState<String, Exception, int, void>(
        failureCount: 2,
      );

      expect(failureCountState1, isNot(equals(failureCountState2)));

      // failureReason
      final failureReasonState1 = MutationState<String, Exception, int, void>(
        failureReason: Exception('reason1'),
      );
      final failureReasonState2 = MutationState<String, Exception, int, void>(
        failureReason: Exception('reason2'),
      );

      expect(failureReasonState1, isNot(equals(failureReasonState2)));

      // isPaused
      const isPausedState1 = MutationState<String, Exception, int, void>(
        isPaused: false,
      );
      const isPausedState2 = MutationState<String, Exception, int, void>(
        isPaused: true,
      );

      expect(isPausedState1, isNot(equals(isPausedState2)));
    });
  });

  group('deep equality', () {
    test(
        'SHOULD be equal '
        'WHEN params contain equal lists', () {
      // data
      const state1 = MutationState<List<int>, Exception, void, void>(
        data: [1, 2, 3],
      );
      const state2 = MutationState<List<int>, Exception, void, void>(
        data: [1, 2, 3],
      );

      expect(state1, equals(state2));
      expect(state1.hashCode, equals(state2.hashCode));

      // error
      const state3 = MutationState<void, List<int>, void, void>(
        error: [1, 2, 3],
      );
      const state4 = MutationState<void, List<int>, void, void>(
        error: [1, 2, 3],
      );

      expect(state3, equals(state4));
      expect(state3.hashCode, equals(state4.hashCode));

      // variables
      const state5 = MutationState<void, Exception, List<int>, void>(
        variables: [1, 2, 3],
      );
      const state6 = MutationState<void, Exception, List<int>, void>(
        variables: [1, 2, 3],
      );

      expect(state5, equals(state6));
      expect(state5.hashCode, equals(state6.hashCode));

      // onMutateResult
      const state7 = MutationState<void, Exception, void, List<int>>(
        onMutateResult: [1, 2, 3],
      );
      const state8 = MutationState<void, Exception, void, List<int>>(
        onMutateResult: [1, 2, 3],
      );

      expect(state7, equals(state8));
      expect(state7.hashCode, equals(state8.hashCode));

      // failureReason
      const state9 = MutationState<void, List<int>, void, void>(
        failureReason: [1, 2, 3],
      );
      const state10 = MutationState<void, List<int>, void, void>(
        failureReason: [1, 2, 3],
      );

      expect(state9, equals(state10));
      expect(state9.hashCode, equals(state10.hashCode));
    });

    test(
        'SHOULD NOT be equal '
        'WHEN params contain different lists', () {
      // data
      const state1 = MutationState<List<int>, Exception, void, void>(
        data: [1, 2, 3],
      );
      const state2 = MutationState<List<int>, Exception, void, void>(
        data: [1, 2, 4],
      );

      expect(state1, isNot(equals(state2)));

      // error
      const state3 = MutationState<void, List<int>, void, void>(
        error: [1, 2, 3],
      );
      const state4 = MutationState<void, List<int>, void, void>(
        error: [1, 2, 4],
      );

      expect(state3, isNot(equals(state4)));

      // variables
      const state5 = MutationState<void, Exception, List<int>, void>(
        variables: [1, 2, 3],
      );
      const state6 = MutationState<void, Exception, List<int>, void>(
        variables: [1, 2, 4],
      );

      expect(state5, isNot(equals(state6)));

      // onMutateResult
      const state7 = MutationState<void, Exception, void, List<int>>(
        onMutateResult: [1, 2, 3],
      );
      const state8 = MutationState<void, Exception, void, List<int>>(
        onMutateResult: [1, 2, 4],
      );

      expect(state7, isNot(equals(state8)));

      // failureReason
      const state9 = MutationState<void, List<int>, void, void>(
        failureReason: [1, 2, 3],
      );
      const state10 = MutationState<void, List<int>, void, void>(
        failureReason: [1, 2, 4],
      );

      expect(state9, isNot(equals(state10)));
    });

    test(
        'SHOULD be equal '
        'WHEN params contain equal maps', () {
      // data
      const state1 = MutationState<Map<String, int>, Exception, void, void>(
        data: {'a': 1, 'b': 2},
      );
      const state2 = MutationState<Map<String, int>, Exception, void, void>(
        data: {'a': 1, 'b': 2},
      );

      expect(state1, equals(state2));
      expect(state1.hashCode, equals(state2.hashCode));

      // error
      const state3 = MutationState<void, Map<String, int>, void, void>(
        error: {'a': 1, 'b': 2},
      );
      const state4 = MutationState<void, Map<String, int>, void, void>(
        error: {'a': 1, 'b': 2},
      );

      expect(state3, equals(state4));
      expect(state3.hashCode, equals(state4.hashCode));

      // variables
      const state5 = MutationState<void, Exception, Map<String, int>, void>(
        variables: {'a': 1, 'b': 2},
      );
      const state6 = MutationState<void, Exception, Map<String, int>, void>(
        variables: {'a': 1, 'b': 2},
      );

      expect(state5, equals(state6));
      expect(state5.hashCode, equals(state6.hashCode));

      // onMutateResult
      const state7 = MutationState<void, Exception, void, Map<String, int>>(
        onMutateResult: {'a': 1, 'b': 2},
      );
      const state8 = MutationState<void, Exception, void, Map<String, int>>(
        onMutateResult: {'a': 1, 'b': 2},
      );

      expect(state7, equals(state8));
      expect(state7.hashCode, equals(state8.hashCode));

      // failureReason
      const state9 = MutationState<void, Map<String, int>, void, void>(
        failureReason: {'a': 1, 'b': 2},
      );
      const state10 = MutationState<void, Map<String, int>, void, void>(
        failureReason: {'a': 1, 'b': 2},
      );

      expect(state9, equals(state10));
      expect(state9.hashCode, equals(state10.hashCode));
    });

    test(
        'SHOULD NOT be equal '
        'WHEN params contain different maps', () {
      // data
      const state1 = MutationState<Map<String, int>, Exception, void, void>(
        data: {'a': 1, 'b': 2},
      );
      const state2 = MutationState<Map<String, int>, Exception, void, void>(
        data: {'a': 1, 'b': 3},
      );

      expect(state1, isNot(equals(state2)));

      // error
      const state3 = MutationState<void, Map<String, int>, void, void>(
        error: {'a': 1, 'b': 2},
      );
      const state4 = MutationState<void, Map<String, int>, void, void>(
        error: {'a': 1, 'b': 3},
      );

      expect(state3, isNot(equals(state4)));

      // variables
      const state5 = MutationState<void, Exception, Map<String, int>, void>(
        variables: {'a': 1, 'b': 2},
      );
      const state6 = MutationState<void, Exception, Map<String, int>, void>(
        variables: {'a': 1, 'b': 3},
      );

      expect(state5, isNot(equals(state6)));

      // onMutateResult
      const state7 = MutationState<void, Exception, void, Map<String, int>>(
        onMutateResult: {'a': 1, 'b': 2},
      );
      const state8 = MutationState<void, Exception, void, Map<String, int>>(
        onMutateResult: {'a': 1, 'b': 3},
      );

      expect(state7, isNot(equals(state8)));

      // failureReason
      const state9 = MutationState<void, Map<String, int>, void, void>(
        failureReason: {'a': 1, 'b': 2},
      );
      const state10 = MutationState<void, Map<String, int>, void, void>(
        failureReason: {'a': 1, 'b': 3},
      );

      expect(state9, isNot(equals(state10)));
    });

    test(
        'SHOULD be equal '
        'WHEN params contain equal sets', () {
      // data
      const state1 = MutationState<Set<int>, Exception, void, void>(
        data: {1, 2, 3},
      );
      const state2 = MutationState<Set<int>, Exception, void, void>(
        data: {1, 2, 3},
      );

      expect(state1, equals(state2));
      expect(state1.hashCode, equals(state2.hashCode));

      // error
      const state3 = MutationState<void, Set<int>, void, void>(
        error: {1, 2, 3},
      );
      const state4 = MutationState<void, Set<int>, void, void>(
        error: {1, 2, 3},
      );

      expect(state3, equals(state4));
      expect(state3.hashCode, equals(state4.hashCode));

      // variables
      const state5 = MutationState<void, Exception, Set<int>, void>(
        variables: {1, 2, 3},
      );
      const state6 = MutationState<void, Exception, Set<int>, void>(
        variables: {1, 2, 3},
      );

      expect(state5, equals(state6));
      expect(state5.hashCode, equals(state6.hashCode));

      // onMutateResult
      const state7 = MutationState<void, Exception, void, Set<int>>(
        onMutateResult: {1, 2, 3},
      );
      const state8 = MutationState<void, Exception, void, Set<int>>(
        onMutateResult: {1, 2, 3},
      );

      expect(state7, equals(state8));
      expect(state7.hashCode, equals(state8.hashCode));

      // failureReason
      const state9 = MutationState<void, Set<int>, void, void>(
        failureReason: {1, 2, 3},
      );
      const state10 = MutationState<void, Set<int>, void, void>(
        failureReason: {1, 2, 3},
      );

      expect(state9, equals(state10));
      expect(state9.hashCode, equals(state10.hashCode));
    });

    test(
        'SHOULD NOT be equal '
        'WHEN params contain different sets', () {
      // data
      const state1 = MutationState<Set<int>, Exception, void, void>(
        data: {1, 2, 3},
      );
      const state2 = MutationState<Set<int>, Exception, void, void>(
        data: {1, 2, 4},
      );

      expect(state1, isNot(equals(state2)));

      // error
      const state3 = MutationState<void, Set<int>, void, void>(
        error: {1, 2, 3},
      );
      const state4 = MutationState<void, Set<int>, void, void>(
        error: {1, 2, 4},
      );

      expect(state3, isNot(equals(state4)));

      // variables
      const state5 = MutationState<void, Exception, Set<int>, void>(
        variables: {1, 2, 3},
      );
      const state6 = MutationState<void, Exception, Set<int>, void>(
        variables: {1, 2, 4},
      );

      expect(state5, isNot(equals(state6)));

      // onMutateResult
      const state7 = MutationState<void, Exception, void, Set<int>>(
        onMutateResult: {1, 2, 3},
      );
      const state8 = MutationState<void, Exception, void, Set<int>>(
        onMutateResult: {1, 2, 4},
      );

      expect(state7, isNot(equals(state8)));

      // failureReason
      const state9 = MutationState<void, Set<int>, void, void>(
        failureReason: {1, 2, 3},
      );
      const state10 = MutationState<void, Set<int>, void, void>(
        failureReason: {1, 2, 4},
      );

      expect(state9, isNot(equals(state10)));
    });

    test(
        'SHOULD be equal '
        'WHEN params contain equal nested structures', () {
      // data
      const state1 =
          MutationState<Map<String, List<int>>, Exception, void, void>(
        data: {
          'a': [1, 2],
          'b': [3, 4]
        },
      );
      const state2 =
          MutationState<Map<String, List<int>>, Exception, void, void>(
        data: {
          'a': [1, 2],
          'b': [3, 4]
        },
      );

      expect(state1, equals(state2));
      expect(state1.hashCode, equals(state2.hashCode));

      // error
      const state3 = MutationState<void, Map<String, List<int>>, void, void>(
        error: {
          'a': [1, 2],
          'b': [3, 4]
        },
      );
      const state4 = MutationState<void, Map<String, List<int>>, void, void>(
        error: {
          'a': [1, 2],
          'b': [3, 4]
        },
      );

      expect(state3, equals(state4));
      expect(state3.hashCode, equals(state4.hashCode));

      // variables
      const state5 =
          MutationState<void, Exception, Map<String, List<int>>, void>(
        variables: {
          'a': [1, 2],
          'b': [3, 4]
        },
      );
      const state6 =
          MutationState<void, Exception, Map<String, List<int>>, void>(
        variables: {
          'a': [1, 2],
          'b': [3, 4]
        },
      );

      expect(state5, equals(state6));
      expect(state5.hashCode, equals(state6.hashCode));

      // onMutateResult
      const state7 =
          MutationState<void, Exception, void, Map<String, List<int>>>(
        onMutateResult: {
          'a': [1, 2],
          'b': [3, 4]
        },
      );
      const state8 =
          MutationState<void, Exception, void, Map<String, List<int>>>(
        onMutateResult: {
          'a': [1, 2],
          'b': [3, 4]
        },
      );

      expect(state7, equals(state8));
      expect(state7.hashCode, equals(state8.hashCode));

      // failureReason
      const state9 = MutationState<void, Map<String, List<int>>, void, void>(
        failureReason: {
          'a': [1, 2],
          'b': [3, 4]
        },
      );
      const state10 = MutationState<void, Map<String, List<int>>, void, void>(
        failureReason: {
          'a': [1, 2],
          'b': [3, 4]
        },
      );

      expect(state9, equals(state10));
      expect(state9.hashCode, equals(state10.hashCode));
    });

    test(
        'SHOULD NOT be equal '
        'WHEN params contain different nested structures', () {
      // data
      const state1 =
          MutationState<Map<String, List<int>>, Exception, void, void>(
        data: {
          'a': [1, 2],
          'b': [3, 4]
        },
      );
      const state2 =
          MutationState<Map<String, List<int>>, Exception, void, void>(
        data: {
          'a': [1, 2],
          'b': [3, 5]
        },
      );

      expect(state1, isNot(equals(state2)));

      // error
      const state3 = MutationState<void, Map<String, List<int>>, void, void>(
        error: {
          'a': [1, 2],
          'b': [3, 4]
        },
      );
      const state4 = MutationState<void, Map<String, List<int>>, void, void>(
        error: {
          'a': [1, 2],
          'b': [3, 5]
        },
      );

      expect(state3, isNot(equals(state4)));

      // variables
      const state5 =
          MutationState<void, Exception, Map<String, List<int>>, void>(
        variables: {
          'a': [1, 2],
          'b': [3, 4]
        },
      );
      const state6 =
          MutationState<void, Exception, Map<String, List<int>>, void>(
        variables: {
          'a': [1, 2],
          'b': [3, 5]
        },
      );

      expect(state5, isNot(equals(state6)));

      // onMutateResult
      const state7 =
          MutationState<void, Exception, void, Map<String, List<int>>>(
        onMutateResult: {
          'a': [1, 2],
          'b': [3, 4]
        },
      );
      const state8 =
          MutationState<void, Exception, void, Map<String, List<int>>>(
        onMutateResult: {
          'a': [1, 2],
          'b': [3, 5]
        },
      );

      expect(state7, isNot(equals(state8)));

      // failureReason
      const state9 = MutationState<void, Map<String, List<int>>, void, void>(
        failureReason: {
          'a': [1, 2],
          'b': [3, 4]
        },
      );
      const state10 = MutationState<void, Map<String, List<int>>, void, void>(
        failureReason: {
          'a': [1, 2],
          'b': [3, 5]
        },
      );

      expect(state9, isNot(equals(state10)));
    });
  });

  group('toString', () {
    test(
        'SHOULD return debug-friendly string '
        'WHEN called with default fields', () {
      const state = MutationState<String, Exception, int, void>();

      expect(
        state.toString(),
        'MutationState('
        'status: MutationStatus.idle, '
        'data: null, '
        'error: null, '
        'variables: null, '
        'onMutateResult: null, '
        'submittedAt: null, '
        'failureCount: 0, '
        'failureReason: null, '
        'isPaused: false)',
      );
    });

    test(
        'SHOULD return debug-friendly string '
        'WHEN called with all fields', () {
      final now = DateTime(2024, 1, 1, 12, 0, 0);
      final error = Exception('test error');
      final state = MutationState<String, Exception, int, String>(
        status: MutationStatus.success,
        data: 'result',
        error: error,
        variables: 42,
        onMutateResult: 'context',
        submittedAt: now,
        failureCount: 2,
        failureReason: error,
        isPaused: true,
      );

      expect(
        state.toString(),
        'MutationState('
        'status: MutationStatus.success, '
        'data: result, '
        'error: $error, '
        'variables: 42, '
        'onMutateResult: context, '
        'submittedAt: $now, '
        'failureCount: 2, '
        'failureReason: $error, '
        'isPaused: true)',
      );
    });
  });
}
