import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_query/src/core/core.dart';
import '../../utils.dart';

void main() {
  late QueryClient client;
  late MutationCache cache;

  setUp(() {
    client = QueryClient();
    cache = client.mutationCache;
  });

  tearDown(() {
    client.clear();
  });

  group('Constructor: cached', () {
    test(
        'SHOULD cache mutation'
        '', () {
      final mutation = Mutation<String, Object, String, void>.cached(client);

      expect(cache.getAll(), contains(mutation));
    });

    test(
        'SHOULD assign unique mutationId to each mutation'
        '', () {
      final mutation1 = Mutation<String, Object, String, void>.cached(client);
      final mutation2 = Mutation<String, Object, String, void>.cached(client);
      final mutation3 = Mutation<String, Object, String, void>.cached(client);

      expect(mutation1.mutationId, isNot(equals(mutation2.mutationId)));
      expect(mutation2.mutationId, isNot(equals(mutation3.mutationId)));
      expect(mutation3.mutationId, isNot(equals(mutation1.mutationId)));
    });

    test(
        'SHOULD create different mutations for same key (no deduplication)'
        '', () {
      final mutation1 = Mutation<String, Object, String, void>.cached(
        client,
        mutationKey: const ['key'],
      );
      final mutation2 = Mutation<String, Object, String, void>.cached(
        client,
        mutationKey: const ['key'],
      );

      expect(mutation1, isNot(same(mutation2)));
      expect(cache.getAll(), hasLength(2));
    });

    test(
        'SHOULD use default GC duration of 5 minutes '
        'WHEN gcDuration == null', withFakeAsync((async) {
      final mutation = Mutation<String, Object, String, String>.cached(client);

      async.elapse(const Duration(minutes: 4, seconds: 59));
      expect(cache.getAll(), contains(mutation));

      async.elapse(const Duration(seconds: 1));
      expect(cache.getAll(), isNot(contains(mutation)));
    }));

    test(
        'SHOULD use provided GC duration '
        'WHEN gcDuration != null', withFakeAsync((async) {
      final mutation = Mutation<String, Object, String, String>.cached(
        client,
        gcDuration: const GcDuration(minutes: 3),
      );

      async.elapse(const Duration(minutes: 2, seconds: 59));
      expect(cache.getAll(), contains(mutation));

      async.elapse(const Duration(seconds: 1));
      expect(cache.getAll(), isNot(contains(mutation)));
    }));
  });

  group('Property: mutationId', () {
    test(
        'SHOULD increment by 1 on every instance'
        '', () {
      final mutation1 = Mutation<String, Object, String, void>(client);
      final mutation2 = Mutation<String, Object, String, void>(client);
      final mutation3 = Mutation<String, Object, String, void>(client);
      final mutation4 = Mutation<String, Object, String, void>(client);
      final mutation5 = Mutation<String, Object, String, void>(client);

      expect(mutation2.mutationId, mutation1.mutationId + 1);
      expect(mutation3.mutationId, mutation2.mutationId + 1);
      expect(mutation4.mutationId, mutation3.mutationId + 1);
      expect(mutation5.mutationId, mutation4.mutationId + 1);
    });
  });

  group('Property: mutationKey', () {
    test(
        'SHOULD return same mutationKey passed to constructor'
        '', () {
      final mutation1 = Mutation<String, Object, String, String>(
        client,
        mutationKey: const ['key', 1],
      );
      final mutation2 = Mutation<String, Object, String, String>.cached(
        client,
        mutationKey: const ['key', 2],
      );

      expect(mutation1.mutationKey, const ['key', 1]);
      expect(mutation2.mutationKey, const ['key', 2]);
    });

    test(
        'SHOULD return null '
        'WHEN not passed to constructor', () {
      final mutation1 = Mutation<String, Object, String, String>(client);
      final mutation2 = Mutation<String, Object, String, String>.cached(client);

      expect(mutation1.mutationKey, isNull);
      expect(mutation2.mutationKey, isNull);
    });
  });

  group('Method: execute', () {
    test(
        'SHOULD transition state to success'
        '', withFakeAsync((async) {
      Object expectedData = Object();
      Object? capturedData;

      final mutation = Mutation<Object, Object, String, String>.cached(client);

      expect(mutation.state.status, MutationStatus.idle);
      expect(mutation.state.data, isNull);
      expect(mutation.state.variables, isNull);
      expect(mutation.state.submittedAt, isNull);

      mutation.execute(
        'variables',
        (v, c) async {
          await Future.delayed(const Duration(seconds: 1));
          return expectedData;
        },
      ).then((data) {
        capturedData = data;
      });

      expect(mutation.state.status, MutationStatus.pending);
      expect(mutation.state.data, isNull);
      expect(mutation.state.variables, 'variables');
      expect(mutation.state.submittedAt, clock.now());

      async.elapse(const Duration(seconds: 1));

      expect(mutation.state.status, MutationStatus.success);
      expect(mutation.state.data, same(expectedData));
      expect(mutation.state.variables, 'variables');
      expect(mutation.state.submittedAt, clock.secondsAgo(1));
      expect(capturedData, same(expectedData));
    }));

    test(
        'SHOULD transition state to error'
        '', withFakeAsync((async) {
      final expectedError = Exception();
      Object? capturedError;

      final mutation = Mutation<String, Object, String, String>.cached(client);

      expect(mutation.state.status, MutationStatus.idle);
      expect(mutation.state.error, isNull);
      expect(mutation.state.variables, isNull);
      expect(mutation.state.submittedAt, isNull);
      expect(mutation.state.failureCount, 0);
      expect(mutation.state.failureReason, isNull);

      mutation.execute(
        'variables',
        (variables, context) async {
          await Future.delayed(const Duration(seconds: 1));
          throw expectedError;
        },
      ).catchError((error) {
        capturedError = error;
        return 'error';
      });

      expect(mutation.state.status, MutationStatus.pending);
      expect(mutation.state.error, isNull);
      expect(mutation.state.variables, 'variables');
      expect(mutation.state.submittedAt, clock.now());
      expect(mutation.state.failureCount, 0);
      expect(mutation.state.failureReason, isNull);

      async.elapse(const Duration(seconds: 1));

      expect(mutation.state.status, MutationStatus.error);
      expect(mutation.state.error, same(expectedError));
      expect(mutation.state.variables, 'variables');
      expect(mutation.state.submittedAt, clock.secondsAgo(1));
      expect(mutation.state.failureCount, 1);
      expect(mutation.state.failureReason, same(expectedError));
      expect(capturedError, same(expectedError));
    }));

    test(
        'SHOULD reset error state on success'
        '', withFakeAsync((async) {
      final mutation = Mutation<String, Object, String, String>.cached(client);

      // First execution fails
      mutation.execute(
        'variables',
        (v, c) async {
          await Future.delayed(const Duration(seconds: 1));
          throw Exception();
        },
      ).ignore();
      async.elapse(const Duration(seconds: 1));

      expect(mutation.state.error, isA<Exception>());
      expect(mutation.state.failureCount, 1);
      expect(mutation.state.failureReason, isA<Exception>());

      // Second execution succeeds
      mutation.execute(
        'variables',
        (v, c) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data';
        },
      );
      async.elapse(const Duration(seconds: 1));

      expect(mutation.state.error, isNull);
      expect(mutation.state.failureCount, 0);
      expect(mutation.state.failureReason, isNull);
    }));

    test(
        'SHOULD pass deep-merged meta through context to mutationFn'
        '', withFakeAsync((async) {
      client.defaultMutationOptions = DefaultMutationOptions(
        meta: {'default': 'default'},
      );

      Map<String, dynamic>? capturedMeta;

      final mutation = Mutation<String, Object, String, void>.cached(client);

      Map<String, dynamic>? captureMeta([Map<String, dynamic>? meta]) {
        mutation.execute(
          'variables',
          (variables, context) async {
            capturedMeta = context.meta;
            return 'data';
          },
          meta: meta,
        );
        async.flushMicrotasks();
        return capturedMeta;
      }

      expect(captureMeta(), {
        'default': 'default',
      });

      expect(captureMeta({'key': 'value'}), {
        'default': 'default',
        'key': 'value',
      });

      // Observer meta should be merged
      final observer1 = MutationObserver<String, Object, String, void>(
        client,
        MutationOptions(
          mutationFn: (variables, context) async {
            capturedMeta = context.meta;
            return 'data';
          },
          meta: {
            'observer': 1,
            'extra-1': 'value-1',
            'nested': {
              'extra-1': 'value-1',
            },
          },
        ),
      )..onMount();
      mutation.addObserver(observer1);

      expect(captureMeta(), {
        'default': 'default',
        'observer': 1,
        'extra-1': 'value-1',
        'nested': {
          'extra-1': 'value-1',
        },
      });

      final observer2 = MutationObserver<String, Object, String, void>(
        client,
        MutationOptions(
          mutationFn: (variables, context) async {
            capturedMeta = context.meta;
            return 'data';
          },
          meta: {
            'observer': 2,
            'extra-2': 'value-2',
            'nested': {
              'extra-2': 'value-2',
            },
          },
        ),
      )..onMount();
      mutation.addObserver(observer2);

      expect(captureMeta(), {
        'default': 'default',
        'observer': 2,
        'extra-1': 'value-1',
        'extra-2': 'value-2',
        'nested': {
          'extra-1': 'value-1',
          'extra-2': 'value-2',
        },
      });

      mutation.removeObserver(observer2);

      expect(captureMeta(), {
        'default': 'default',
        'observer': 1,
        'extra-1': 'value-1',
        'nested': {
          'extra-1': 'value-1',
        },
      });

      mutation.removeObserver(observer1);

      expect(captureMeta(), {
        'default': 'default',
      });
    }));

    group('Parameter: onMutate', () {
      test(
          'SHOULD call before mutationFn'
          '', withFakeAsync((async) {
        final callOrder = <String>[];

        final mutation = Mutation<String, Object, String, void>.cached(client);

        mutation.execute(
          'variables',
          (v, c) async {
            await Future.delayed(const Duration(seconds: 1));
            callOrder.add('mutationFn');
            return 'data';
          },
          onMutate: (variables, context) async {
            await Future.delayed(const Duration(seconds: 1));
            callOrder.add('onMutate');
          },
        ).ignore();

        async.elapse(const Duration(seconds: 1));
        expect(callOrder, ['onMutate']);

        async.elapse(const Duration(seconds: 1));
        expect(callOrder, ['onMutate', 'mutationFn']);
      }));

      test(
          'SHOULD receive correct arguments'
          '', withFakeAsync((async) {
        String? capturedVariables;
        MutationFunctionContext? capturedContext;

        final mutation = Mutation<String, Object, String, void>.cached(
          client,
          mutationKey: const ['key'],
        );

        mutation.execute(
          'variables',
          (v, c) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'data';
          },
          onMutate: (variables, context) {
            capturedVariables = variables;
            capturedContext = context;
          },
          meta: {'key': 'value'},
        );
        async.flushMicrotasks();

        expect(capturedVariables, 'variables');
        expect(capturedContext, isA<MutationFunctionContext>());
        expect(capturedContext!.mutationKey, const ['key']);
        expect(capturedContext!.client, same(client));
        expect(capturedContext!.meta, {'key': 'value'});
      }));

      test(
          'SHOULD store returned value in state'
          '', withFakeAsync((async) {
        final expectedReturnedValue = Object();

        final mutation =
            Mutation<String, Object, String, Object>.cached(client);

        mutation.execute(
          'variables',
          (v, c) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'data';
          },
          onMutate: (variables, context) {
            return expectedReturnedValue;
          },
        );
        async.flushMicrotasks();

        expect(mutation.state.onMutateResult, same(expectedReturnedValue));
      }));
    });

    group('Parameter: onSuccess', () {
      test(
          'SHOULD call after mutationFn succeeds'
          '', withFakeAsync((async) {
        final callOrder = <String>[];

        final mutation =
            Mutation<String, Object, String, String>.cached(client);

        mutation.execute(
          'variables',
          (v, c) async {
            await Future.delayed(const Duration(seconds: 1));
            callOrder.add('mutationFn');
            return 'data';
          },
          onSuccess: (data, variables, onMutateResult, context) async {
            await Future.delayed(const Duration(seconds: 1));
            callOrder.add('onSuccess');
          },
        );

        async.elapse(const Duration(seconds: 1));
        expect(callOrder, ['mutationFn']);

        async.elapse(const Duration(seconds: 1));
        expect(callOrder, ['mutationFn', 'onSuccess']);
      }));

      test(
          'SHOULD receive correct arguments'
          '', withFakeAsync((async) {
        String? capturedData;
        String? capturedVariables;
        String? capturedOnMutateResult;
        MutationFunctionContext? capturedContext;

        final mutation = Mutation<String, Object, String, String>.cached(
          client,
          mutationKey: const ['key'],
        );

        mutation.execute(
          'variables',
          (v, c) async => 'data',
          meta: {'key': 'value'},
          onMutate: (v, c) => 'onMutateResult',
          onSuccess: (data, variables, onMutateResult, context) {
            capturedData = data;
            capturedVariables = variables;
            capturedOnMutateResult = onMutateResult;
            capturedContext = context;
          },
        );
        async.flushMicrotasks();

        expect(capturedData, 'data');
        expect(capturedVariables, 'variables');
        expect(capturedOnMutateResult, 'onMutateResult');
        expect(capturedContext, isA<MutationFunctionContext>());
        expect(capturedContext!.mutationKey, const ['key']);
        expect(capturedContext!.client, same(client));
        expect(capturedContext!.meta, {'key': 'value'});
      }));

      test(
          'SHOULD NOT call '
          'WHEN mutationFn throws', withFakeAsync((async) {
        var onSuccessCalled = false;
        var onErrorCalled = false;

        final mutation = Mutation<String, Object, String, void>.cached(client);

        mutation.execute(
          'variables',
          (v, c) async {
            await Future.delayed(const Duration(seconds: 1));
            throw Exception();
          },
          onSuccess: (data, variables, onMutateResult, context) {
            onSuccessCalled = true;
          },
          onError: (data, variables, onMutateResult, context) {
            onErrorCalled = true;
          },
        ).ignore();
        async.elapse(const Duration(seconds: 1));

        expect(onSuccessCalled, isFalse);
        expect(onErrorCalled, isTrue);
      }));
    });

    group('Parameter: onError', () {
      test(
          'SHOULD call after mutationFn throws'
          '', withFakeAsync((async) {
        final callOrder = <String>[];

        final mutation = Mutation<String, Object, String, void>.cached(client);

        mutation.execute(
          'variables',
          (v, c) async {
            await Future.delayed(const Duration(seconds: 1));
            callOrder.add('mutationFn');
            throw Exception();
          },
          onError: (error, variables, onMutateResult, context) async {
            await Future.delayed(const Duration(seconds: 1));
            callOrder.add('onError');
          },
        ).ignore();

        async.elapse(const Duration(seconds: 1));
        expect(callOrder, ['mutationFn']);

        async.elapse(const Duration(seconds: 1));
        expect(callOrder, ['mutationFn', 'onError']);
      }));

      test(
          'SHOULD receive correct arguments'
          '', withFakeAsync((async) {
        final expectedError = Exception();
        Object? capturedError;
        String? capturedVariables;
        String? capturedOnMutateResult;
        MutationFunctionContext? capturedContext;

        final mutation = Mutation<String, Object, String, String>.cached(
          client,
          mutationKey: const ['key'],
        );

        mutation
            .execute(
              'variables',
              (v, c) async => throw expectedError,
              meta: {'key': 'value'},
              onMutate: (v, c) => 'onMutateResult',
              onError: (error, variables, onMutateResult, context) {
                capturedError = error;
                capturedVariables = variables;
                capturedOnMutateResult = onMutateResult;
                capturedContext = context;
              },
            )
            .ignore();
        async.flushMicrotasks();

        expect(capturedError, same(expectedError));
        expect(capturedVariables, 'variables');
        expect(capturedOnMutateResult, 'onMutateResult');
        expect(capturedContext, isA<MutationFunctionContext>());
        expect(capturedContext!.mutationKey, const ['key']);
        expect(capturedContext!.client, same(client));
        expect(capturedContext!.meta, {'key': 'value'});
      }));

      test(
          'SHOULD NOT call '
          'WHEN mutationFn succeeds', withFakeAsync((async) {
        var onSuccessCalled = false;
        var onErrorCalled = false;

        final mutation = Mutation<String, Object, String, void>.cached(client);

        mutation.execute(
          'variables',
          (v, c) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'data';
          },
          onSuccess: (data, variables, onMutateResult, context) {
            onSuccessCalled = true;
          },
          onError: (error, variables, onMutateResult, context) {
            onErrorCalled = true;
          },
        );
        async.elapse(const Duration(seconds: 1));

        expect(onErrorCalled, isFalse);
        expect(onSuccessCalled, isTrue);
      }));
    });

    group('Parameter: onSettled', () {
      test(
          'SHOULD call after onSuccess'
          '', withFakeAsync((async) {
        final callOrder = <String>[];
        final mutation =
            Mutation<String, Object, String, String>.cached(client);

        mutation.execute(
          'variables',
          (v, c) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'data';
          },
          onSuccess: (data, variables, onMutateResult, context) async {
            await Future.delayed(const Duration(seconds: 1));
            callOrder.add('onSuccess');
          },
          onSettled: (data, error, variables, onMutateResult, context) async {
            await Future.delayed(const Duration(seconds: 1));
            callOrder.add('onSettled');
          },
        );

        async.elapse(const Duration(seconds: 2));
        expect(callOrder, ['onSuccess']);

        async.elapse(const Duration(seconds: 1));
        expect(callOrder, ['onSuccess', 'onSettled']);
      }));

      test(
          'SHOULD call after onError'
          '', withFakeAsync((async) {
        final callOrder = <String>[];
        final mutation =
            Mutation<String, Object, String, String>.cached(client);

        mutation.execute(
          'variables',
          (v, c) async {
            await Future.delayed(const Duration(seconds: 1));
            throw Exception();
          },
          onError: (error, variables, onMutateResult, context) async {
            await Future.delayed(const Duration(seconds: 1));
            callOrder.add('onError');
          },
          onSettled: (data, error, variables, onMutateResult, context) async {
            await Future.delayed(const Duration(seconds: 1));
            callOrder.add('onSettled');
          },
        ).ignore();

        async.elapse(const Duration(seconds: 2));
        expect(callOrder, ['onError']);

        async.elapse(const Duration(seconds: 1));
        expect(callOrder, ['onError', 'onSettled']);
      }));

      test(
          'SHOULD receive correct arguments '
          'WHEN mutationFn succeeds', withFakeAsync((async) {
        String? capturedData;
        Object? capturedError;
        String? capturedVariables;
        String? capturedOnMutateResult;
        MutationFunctionContext? capturedContext;

        final mutation = Mutation<String, Object, String, String>.cached(
          client,
          mutationKey: const ['key'],
        );

        mutation.execute(
          'variables',
          (v, c) async => 'data',
          meta: {'key': 'value'},
          onMutate: (v, c) => 'onMutateResult',
          onSettled: (data, error, variables, onMutateResult, context) {
            capturedData = data;
            capturedError = error;
            capturedVariables = variables;
            capturedOnMutateResult = onMutateResult;
            capturedContext = context;
          },
        );
        async.flushMicrotasks();

        expect(capturedData, 'data');
        expect(capturedError, isNull);
        expect(capturedVariables, 'variables');
        expect(capturedOnMutateResult, 'onMutateResult');
        expect(capturedContext, isA<MutationFunctionContext>());
        expect(capturedContext!.mutationKey, const ['key']);
        expect(capturedContext!.client, same(client));
        expect(capturedContext!.meta, {'key': 'value'});
      }));

      test(
          'SHOULD receive correct arguments '
          'WHEN mutationFn throws', withFakeAsync((async) {
        final expectedError = Exception();
        String? capturedData;
        Object? capturedError;
        String? capturedVariables;
        String? capturedOnMutateResult;
        MutationFunctionContext? capturedContext;

        final mutation = Mutation<String, Object, String, String>.cached(
          client,
          mutationKey: const ['key'],
        );

        mutation
            .execute(
              'variables',
              (v, c) async => throw expectedError,
              meta: {'key': 'value'},
              onMutate: (v, c) => 'onMutateResult',
              onSettled: (data, error, variables, onMutateResult, context) {
                capturedData = data;
                capturedError = error;
                capturedVariables = variables;
                capturedOnMutateResult = onMutateResult;
                capturedContext = context;
              },
            )
            .ignore();
        async.flushMicrotasks();

        expect(capturedData, isNull);
        expect(capturedError, same(expectedError));
        expect(capturedVariables, 'variables');
        expect(capturedOnMutateResult, 'onMutateResult');
        expect(capturedContext, isA<MutationFunctionContext>());
        expect(capturedContext!.mutationKey, const ['key']);
        expect(capturedContext!.client, same(client));
        expect(capturedContext!.meta, {'key': 'value'});
      }));
    });

    group('Parameter: retry', () {
      test(
          'SHOULD NOT retry '
          'WHEN retry == null', withFakeAsync((async) {
        var calls = 0;
        final mutation =
            Mutation<String, Object, String, String>.cached(client);

        mutation.execute(
          'variables',
          (v, c) async {
            await Future.delayed(const Duration(seconds: 1));
            calls++;
            throw Exception();
          },
        ).ignore();

        async.elapse(const Duration(seconds: 1));
        expect(calls, 1);

        async.elapse(const Duration(days: 365));
        expect(calls, 1);
      }));

      test(
          'SHOULD retry with delay '
          'WHEN retry returns Duration', withFakeAsync((async) {
        final mutation =
            Mutation<String, Object, String, String>.cached(client);

        mutation.execute(
          'variables',
          (v, c) async => throw Exception(),
          retry: (retryCount, error) {
            if (retryCount < 2) {
              return const Duration(seconds: 1);
            }
            return null;
          },
        ).ignore();

        // Initial attempt
        async.flushMicrotasks();
        expect(mutation.state.status, MutationStatus.pending);
        expect(mutation.state.failureCount, 1);

        // First retry
        async.elapse(const Duration(seconds: 1));
        expect(mutation.state.status, MutationStatus.pending);
        expect(mutation.state.failureCount, 2);

        // Second retry - should stop
        async.elapse(const Duration(seconds: 1));
        expect(mutation.state.status, MutationStatus.error);
        expect(mutation.state.failureCount, 3);

        // Should NOT retry further
        async.elapse(const Duration(days: 365));
        expect(mutation.state.status, MutationStatus.error);
        expect(mutation.state.failureCount, 3);
      }));

      test(
          'SHOULD stop retrying '
          'WHEN retry returns null', withFakeAsync((async) {
        var calls = 0;
        final mutation =
            Mutation<String, Object, String, String>.cached(client);

        mutation.execute(
          'variables',
          (v, c) async {
            calls++;
            throw Exception();
          },
          retry: (retryCount, error) => null,
        ).ignore();

        async.flushMicrotasks();
        expect(calls, 1);

        async.elapse(const Duration(days: 365));
        expect(calls, 1);
      }));

      test(
          'SHOULD reset failureCount and failureReason '
          'WHEN succeeds after retries', withFakeAsync((async) {
        var calls = 0;
        final error = Exception('temporary');
        final mutation =
            Mutation<String, Object, String, String>.cached(client);

        mutation.execute(
          'variables',
          (v, c) async {
            calls++;
            if (calls < 3) throw error;
            return 'data';
          },
          retry: (retryCount, error) => const Duration(seconds: 1),
        );

        // First attempt fails
        async.flushMicrotasks();
        expect(mutation.state.failureCount, 1);
        expect(mutation.state.failureReason, error);

        // Second attempt fails
        async.elapse(const Duration(seconds: 1));
        expect(mutation.state.failureCount, 2);
        expect(mutation.state.failureReason, error);

        // Third attempt succeeds
        async.elapse(const Duration(seconds: 1));
        expect(mutation.state.status, MutationStatus.success);
        expect(mutation.state.failureCount, 0);
        expect(mutation.state.failureReason, isNull);
      }));
    });
  });

  group('Method: tryRemove', () {
    test(
        'SHOULD remove mutation from cache'
        '', () {
      final mutation = Mutation<String, Object, String, String>.cached(client);

      expect(cache.getAll(), contains(mutation));

      mutation.tryRemove();

      expect(cache.getAll(), isNot(contains(mutation)));
    });

    test(
        'SHOULD NOT remove mutation '
        'WHEN mutation has observers', () {
      final observer = MutationObserver(
        client,
        MutationOptions<String, Object, String, String>(
          mutationFn: (v, c) async => 'data',
        ),
      );
      final mutation = Mutation<String, Object, String, String>.cached(client);
      mutation.addObserver(observer);

      expect(mutation.hasObservers, isTrue);
      expect(cache.getAll(), contains(mutation));

      mutation.tryRemove();

      expect(cache.getAll(), contains(mutation));
    });

    test(
        'SHOULD NOT remove mutation and reschedule GC '
        'WHEN mutation status is in pending', withFakeAsync((async) {
      final mutation = Mutation<String, Object, String, String>.cached(
        client,
        gcDuration: const GcDuration(minutes: 3),
      );

      mutation.execute(
        'variables',
        (variables, context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data';
        },
      );

      expect(cache.getAll(), contains(mutation));
      expect(mutation.state.status, MutationStatus.pending);

      mutation.tryRemove();

      expect(cache.getAll(), contains(mutation));

      // Should have rescheduled GC
      async.elapse(const Duration(minutes: 2, seconds: 59));
      expect(cache.getAll(), contains(mutation));
      async.elapse(const Duration(seconds: 1));
      expect(cache.getAll(), isNot(contains(mutation)));
    }));
  });

  group('Extension: MutationExt.matches', () {
    test(
        'SHOULD match '
        'WHEN no filters provided', () {
      final mutation = Mutation<String, Object, String, String>.cached(client);

      expect(mutation.matches(), isTrue);
    });

    test(
        'SHOULD match exact key '
        'WHEN exact == true AND key matches', () {
      final mutation = Mutation<String, Object, String, String>.cached(
        client,
        mutationKey: const ['users', '1'],
      );

      expect(
        mutation.matches(exact: true, mutationKey: const ['users', '1']),
        isTrue,
      );
    });

    test(
        'SHOULD NOT match '
        'WHEN exact == true AND key differs', () {
      final mutation = Mutation<String, Object, String, String>.cached(
        client,
        mutationKey: const ['users', '1'],
      );

      expect(
        mutation.matches(exact: true, mutationKey: const ['users', '2']),
        isFalse,
      );
    });

    test(
        'SHOULD match partial key'
        '', () {
      final mutation = Mutation<String, Object, String, String>.cached(
        client,
        mutationKey: const ['users', '1', 'profile'],
      );

      expect(
        mutation.matches(mutationKey: const ['users', '1']),
        isTrue,
      );
    });

    test(
        'SHOULD NOT match '
        'WHEN mutation has no key but filter has key', () {
      final mutation = Mutation<String, Object, String, String>.cached(client);

      expect(
        mutation.matches(mutationKey: const ['users']),
        isFalse,
      );
    });

    test(
        'SHOULD match status'
        '', () {
      final mutation = Mutation<String, Object, String, String>.cached(client);

      expect(
        mutation.matches(status: MutationStatus.idle),
        isTrue,
      );
    });

    test(
        'SHOULD NOT match status'
        '', () {
      final mutation = Mutation<String, Object, String, String>.cached(client);

      expect(
        mutation.matches(status: MutationStatus.pending),
        isFalse,
      );
    });

    test(
        'SHOULD match predicate'
        '', () {
      final mutation = Mutation<String, Object, String, String>.cached(
        client,
        mutationKey: const ['users'],
      );

      expect(
        mutation.matches(predicate: (key, state) => key != null),
        isTrue,
      );
    });

    test(
        'SHOULD NOT match predicate'
        '', () {
      final mutation = Mutation<String, Object, String, String>.cached(client);

      expect(
        mutation.matches(predicate: (key, state) => key != null),
        isFalse,
      );
    });

    test(
        'SHOULD require ALL filters to match (AND logic)'
        '', () {
      final mutation = Mutation<String, Object, String, String>.cached(
        client,
        mutationKey: const ['users', '1'],
      );

      // All match
      expect(
        mutation.matches(
          mutationKey: const ['users'],
          exact: false,
          status: MutationStatus.idle,
          predicate: (key, state) => true,
        ),
        isTrue,
      );

      // One doesn't match
      expect(
        mutation.matches(
          mutationKey: const ['users'],
          exact: false,
          status: MutationStatus.pending, // This doesn't match
          predicate: (key, state) => true,
        ),
        isFalse,
      );
    });

    test(
        'SHOULD NOT match partial key '
        'WHEN filter is longer than key', () {
      final mutation = Mutation<String, Object, String, String>.cached(
        client,
        mutationKey: const ['users'],
      );

      expect(
        mutation.matches(exact: false, mutationKey: const ['users', '1']),
        isFalse,
      );
    });
  });
}
