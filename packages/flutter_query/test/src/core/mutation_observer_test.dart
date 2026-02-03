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

  MutationOptions<String, Object, String, String> createOptions({
    Future<String> Function(String, MutationFunctionContext)? mutationFn,
    List<Object?>? mutationKey,
    Map<String, dynamic>? meta,
    FutureOr<String?> Function(String, MutationFunctionContext)? onMutate,
    FutureOr<void> Function(String, String, String?, MutationFunctionContext)?
        onSuccess,
    FutureOr<void> Function(Object, String, String?, MutationFunctionContext)?
        onError,
    FutureOr<void> Function(
            String?, Object?, String, String?, MutationFunctionContext)?
        onSettled,
    Duration? Function(int, Object)? retry,
    GcDuration? gcDuration,
  }) {
    return MutationOptions<String, Object, String, String>(
      mutationFn:
          mutationFn ?? (variables, context) async => 'result: $variables',
      mutationKey: mutationKey,
      meta: meta,
      onMutate: onMutate,
      onSuccess: onSuccess,
      onError: onError,
      onSettled: onSettled,
      retry: retry,
      gcDuration: gcDuration,
    );
  }

  group('subscribe', () {
    test(
        'SHOULD notify listeners '
        'WHEN result changes', withFakeAsync((async) {
      final observer = MutationObserver(client, createOptions());
      var calls = 0;
      MutationResult? capturedResult;

      observer.subscribe((result) {
        calls++;
        capturedResult = result;
      });

      observer.mutate('test');
      async.flushMicrotasks();

      expect(calls, greaterThan(0));
      expect(capturedResult, isNotNull);
    }));

    test(
        'SHOULD NOT notify '
        'WHEN unsubscribe has been called', withFakeAsync((async) {
      final observer = MutationObserver(client, createOptions());
      var calls = 0;

      final unsubscribe = observer.subscribe((result) {
        calls++;
      });

      unsubscribe();

      observer.mutate('test');
      async.flushMicrotasks();

      expect(calls, equals(0));
    }));

    test(
        'SHOULD support multiple simultaneous subscriptions'
        '', withFakeAsync((async) {
      final observer = MutationObserver(client, createOptions());
      var calls1 = 0;
      var calls2 = 0;

      observer.subscribe((result) => calls1++);
      observer.subscribe((result) => calls2++);

      observer.mutate('test');
      async.flushMicrotasks();

      expect(calls1, greaterThan(0));
      expect(calls2, greaterThan(0));
      expect(calls1, equals(calls2));
    }));

    test(
        'SHOULD NOT remove other subscriptions '
        'WHEN one unsubscribe is called', withFakeAsync((async) {
      final observer = MutationObserver(client, createOptions());
      var calls1 = 0;
      var calls2 = 0;

      final unsubscribe1 = observer.subscribe((result) => calls1++);
      observer.subscribe((result) => calls2++);

      unsubscribe1();

      observer.mutate('test');
      async.flushMicrotasks();

      expect(calls1, equals(0));
      expect(calls2, greaterThan(0));
    }));
  });

  group('mutate', () {
    test(
        'SHOULD transition to pending state immediately and synchronously'
        '', withFakeAsync((async) {
      final observer = MutationObserver(
        client,
        createOptions(mutationFn: (v, c) async => 'success'),
      );

      observer.mutate('');

      expect(observer.result.status, MutationStatus.pending);
      expect(observer.result.submittedAt, clock.now());
      expect(observer.result.isPending, isTrue);
    }));

    test(
        'SHOULD transition to success state with data on completion'
        '', withFakeAsync((async) {
      final observer = MutationObserver(
        client,
        createOptions(mutationFn: (v, c) async => 'success'),
      );

      observer.mutate('');

      expect(observer.result.isPending, isTrue);

      async.flushMicrotasks();

      expect(observer.result.status, MutationStatus.success);
      expect(observer.result.data, equals('success'));
      expect(observer.result.isSuccess, isTrue);
    }));

    test(
        'SHOULD transition to error state on failure'
        '', withFakeAsync((async) {
      final error = Exception();
      final observer = MutationObserver(
        client,
        createOptions(mutationFn: (v, c) async => throw error),
      );

      observer.mutateAsync('').ignore();

      expect(observer.result.isPending, true);

      async.flushMicrotasks();

      expect(observer.result.status, MutationStatus.error);
      expect(observer.result.error, same(error));
      expect(observer.result.failureCount, 1);
      expect(observer.result.failureReason, same(error));
      expect(observer.result.isError, isTrue);
    }));

    test(
        'SHOULD pass in variables to mutationFn and MutationResult'
        '', withFakeAsync((async) {
      String? capturedVariables;
      final observer = MutationObserver(
        client,
        createOptions(mutationFn: (variables, _) async {
          capturedVariables = variables;
          return 'success';
        }),
      );

      observer.mutate('variables');

      expect(capturedVariables, 'variables');
      expect(observer.result.variables, 'variables');

      async.flushMicrotasks();

      expect(capturedVariables, 'variables');
      expect(observer.result.variables, 'variables');
    }));

    test(
        'SHOULD return Future that resolves with data'
        '', withFakeAsync((async) {
      final observer = MutationObserver(
        client,
        createOptions(mutationFn: (v, c) async => 'success'),
      );
      String? resolvedData;

      observer.mutateAsync('').then((data) => resolvedData = data);

      expect(resolvedData, isNull);

      async.flushMicrotasks();

      expect(resolvedData, equals('success'));
    }));

    test(
        'SHOULD return Future that rejects with error'
        '', withFakeAsync((async) {
      final error = Exception();
      final observer = MutationObserver(
        client,
        createOptions(mutationFn: (v, c) async => throw error),
      );
      Object? caughtError;

      observer.mutateAsync('').then((_) {}).catchError((e) {
        caughtError = e;
      });

      expect(caughtError, isNull);

      async.flushMicrotasks();

      expect(caughtError, same(error));
    }));

    test(
        'SHOULD replace previous mutation '
        'WHEN called multiple times', withFakeAsync((async) {
      final observer = MutationObserver(
        client,
        createOptions(mutationFn: (v, c) async => v),
      );

      observer.mutate('first');
      async.flushMicrotasks();

      observer.mutate('second');
      async.flushMicrotasks();

      expect(observer.result.data, equals('second'));
      expect(observer.result.variables, equals('second'));
    }));

    test(
        'SHOULD ONLY track latest mutation'
        '', withFakeAsync((async) {
      final completer1 = Completer<String>();
      final completer2 = Completer<String>();
      var calls = 0;

      final observer = MutationObserver(
        client,
        createOptions(mutationFn: (v, c) {
          calls++;
          return calls == 1 ? completer1.future : completer2.future;
        }),
      );

      observer.mutate('first');
      async.flushMicrotasks();

      observer.mutate('second');
      async.flushMicrotasks();

      // Complete the first mutation (observer should no longer be attached)
      completer1.complete('first result');
      async.flushMicrotasks();

      // Result should still be pending since second mutation hasn't completed
      expect(observer.result.isPending, isTrue);

      completer2.complete('second result');
      async.flushMicrotasks();

      expect(observer.result.isSuccess, isTrue);
      expect(observer.result.data, equals('second result'));
    }));

    test(
        'SHOULD create new cache every time it gets called'
        '', withFakeAsync((async) {
      final observer = MutationObserver(
        client,
        createOptions(
          mutationFn: (v, c) async => 'success',
          // Prevent GC so mutations remain in cache for the duration of the test
          gcDuration: GcDuration.infinity,
        ),
      );

      observer.mutate('');
      expect(cache.getAll().length, 1);

      observer.mutate('');
      expect(cache.getAll().length, 2);

      observer.mutate('');
      expect(cache.getAll().length, 3);
    }));
  });

  group('reset', () {
    test(
        'SHOULD revert to idle state'
        '', withFakeAsync((async) {
      final observer = MutationObserver(
        client,
        createOptions(mutationFn: (v, c) async => 'success'),
      );

      observer.mutate('');
      async.flushMicrotasks();

      expect(observer.result.isSuccess, isTrue);

      observer.reset();

      expect(observer.result.status, MutationStatus.idle);
      expect(observer.result.data, isNull);
      expect(observer.result.variables, isNull);
      expect(observer.result.submittedAt, isNull);
      expect(observer.result.isIdle, isTrue);
    }));

    test(
        'SHOULD notify listeners of state change'
        '', withFakeAsync((async) {
      final observer = MutationObserver(
        client,
        createOptions(mutationFn: (v, c) async => 'success'),
      );
      var calls = 0;
      MutationResult? capturedResult;

      observer.subscribe((result) {
        calls++;
        capturedResult = result;
      });

      observer.mutate('');

      expect(calls, 1);
      expect(capturedResult!.isPending, isTrue);

      observer.reset();

      expect(calls, 2);
      expect(capturedResult!.isIdle, isTrue);
    }));

    test(
        'SHOULD allow new mutations after reset'
        '', withFakeAsync((async) {
      final observer = MutationObserver(
        client,
        createOptions(mutationFn: (v, c) async => v),
      );

      observer.mutate('first');
      async.flushMicrotasks();

      observer.reset();

      observer.mutate('second');
      async.flushMicrotasks();

      expect(observer.result.isSuccess, isTrue);
      expect(observer.result.data, equals('second'));
    }));

    test(
        'SHOULD detach from underlying mutation'
        '', withFakeAsync((async) {
      final observer = MutationObserver(
        client,
        createOptions(
          mutationFn: (v, c) async => v,
          mutationKey: const ['key'],
        ),
      );

      observer.mutate('');
      async.flushMicrotasks();

      final mutation = cache.find(mutationKey: const ['key'])!;
      expect(mutation.hasObservers, isTrue);

      observer.reset();

      expect(mutation.hasObservers, isFalse);
    }));
  });

  group('dispose', () {
    test(
        'SHOULD clear all listeners'
        '', withFakeAsync((async) {
      final observer = MutationObserver(client, createOptions());
      var calls = 0;

      observer.subscribe((result) => calls++);
      observer.subscribe((result) => calls++);

      observer.onUnmount();

      observer.mutate('');
      async.flushMicrotasks();

      expect(calls, equals(0));
    }));

    test(
        'SHOULD be safe to call multiple times'
        '', () {
      final observer = MutationObserver(client, createOptions());

      expect(() {
        observer.onUnmount();
        observer.onUnmount();
        observer.onUnmount();
      }, returnsNormally);
    });

    test(
        'SHOULD detach from underlying mutation'
        '', withFakeAsync((async) {
      final observer = MutationObserver(
        client,
        createOptions(
          mutationFn: (v, c) async => v,
          mutationKey: const ['key'],
        ),
      );

      observer.mutate('');
      async.flushMicrotasks();

      final mutation = cache.find(mutationKey: const ['key'])!;
      expect(mutation.hasObservers, isTrue);

      observer.onUnmount();

      expect(mutation.hasObservers, isFalse);
    }));
  });

  group('options', () {
    test(
        'SHOULD apply client defaults'
        '', () {
      final clientWithDefaults = QueryClient(
        defaultMutationOptions: DefaultMutationOptions(
          gcDuration: const GcDuration(minutes: 10),
        ),
      );
      addTearDown(clientWithDefaults.clear);
      final observer = MutationObserver(
        clientWithDefaults,
        MutationOptions<String, Object, String, void>(
          mutationFn: (v, c) async => 'success',
        ),
      );

      expect(observer.options.gcDuration, const GcDuration(minutes: 10));
    });

    test(
        'SHOULD override client defaults'
        '', () {
      final clientWithDefaults = QueryClient(
        defaultMutationOptions: DefaultMutationOptions(
          gcDuration: const GcDuration(minutes: 10),
        ),
      );
      addTearDown(clientWithDefaults.clear);
      final observer = MutationObserver(
        clientWithDefaults,
        MutationOptions<String, Object, String, void>(
          mutationFn: (v, c) async => 'result',
          mutationKey: const ['key'],
          gcDuration: const GcDuration(minutes: 3),
        ),
      );

      expect(observer.options.gcDuration, const GcDuration(minutes: 3));
    });

    test(
        'SHOULD apply client defaults for unspecified fields '
        'WHEN setter is called with new options', () {
      final clientWithDefaults = QueryClient(
        defaultMutationOptions: DefaultMutationOptions(
          gcDuration: const GcDuration(minutes: 10),
        ),
      );
      addTearDown(clientWithDefaults.clear);
      final observer = MutationObserver(
        clientWithDefaults,
        MutationOptions<String, Object, String, void>(
          mutationFn: (v, c) async => 'result',
          gcDuration: const GcDuration(minutes: 5),
        ),
      );

      expect(observer.options.gcDuration, const GcDuration(minutes: 5));

      observer.options = MutationOptions<String, Object, String, void>(
        mutationFn: (v, c) async => 'result',
      );

      expect(observer.options.gcDuration, const GcDuration(minutes: 10));
    });
  });

  group('result', () {
    test(
        'SHOULD reflect current mutation state'
        '', withFakeAsync((async) {
      final observer = MutationObserver(
        client,
        createOptions(
          mutationFn: (v, c) async {
            await Future.delayed(const Duration(seconds: 3));
            return 'success';
          },
        ),
      )..onMount();

      // Initial state
      expect(
        observer.result,
        MutationResult<String, Object, String, String>(
          status: MutationStatus.idle,
          data: null,
          error: null,
          variables: null,
          submittedAt: null,
          failureCount: 0,
          failureReason: null,
          isPaused: false,
          mutate: observer.mutate,
          mutateAsync: observer.mutateAsync,
          reset: observer.reset,
        ),
      );

      observer.mutate('variables');

      // Pending state
      expect(
        observer.result,
        MutationResult<String, Object, String, String>(
          status: MutationStatus.pending,
          data: null,
          error: null,
          variables: 'variables',
          submittedAt: clock.now(),
          failureCount: 0,
          failureReason: null,
          isPaused: false,
          mutate: observer.mutate,
          mutateAsync: observer.mutateAsync,
          reset: observer.reset,
        ),
      );

      async.elapse(const Duration(seconds: 3));

      // Pending state
      expect(
        observer.result,
        MutationResult<String, Object, String, String>(
          status: MutationStatus.success,
          data: 'success',
          error: null,
          variables: 'variables',
          submittedAt: clock.now().subtract(const Duration(seconds: 3)),
          failureCount: 0,
          failureReason: null,
          isPaused: false,
          mutate: observer.mutate,
          mutateAsync: observer.mutateAsync,
          reset: observer.reset,
        ),
      );
    }));

    test(
        'SHOULD NOT trigger duplicate notifications for equal states'
        '', withFakeAsync((async) {
      final observer = MutationObserver(client, createOptions())..onMount();
      var calls = 0;

      observer.subscribe((result) => calls++);

      // Calling reset multiple times should not trigger notifications
      // since the state is already idle
      observer.reset();
      observer.reset();
      observer.reset();

      expect(calls, equals(0));
    }));
  });

  group('MutationOptions.onMutate', () {
    test(
        'SHOULD run and await before mutationFn'
        '', withFakeAsync((async) {
      final observer = MutationObserver(
        client,
        createOptions(
          mutationFn: (v, c) async {
            await Future.delayed(const Duration(seconds: 3));
            return 'success';
          },
          mutationKey: const ['key'],
          onMutate: (v, c) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'onMutateResult';
          },
        ),
      );

      observer.mutate('');
      final mutation = cache.find(mutationKey: const ['key'])!;

      expect(mutation.state.data, isNull);
      expect(mutation.state.onMutateResult, isNull);

      async.elapse(const Duration(seconds: 1));

      expect(mutation.state.data, isNull);
      expect(mutation.state.onMutateResult, 'onMutateResult');

      async.elapse(const Duration(seconds: 3));

      expect(mutation.state.data, 'success');
      expect(mutation.state.onMutateResult, 'onMutateResult');
    }));

    test(
        'SHOULD transition to error state AND '
        'SHOULD NOT run mutationFn '
        'WHEN throws', withFakeAsync((async) {
      int mutationFnCalls = 0;

      final observer = MutationObserver(
        client,
        createOptions(
          mutationFn: (v, c) async {
            mutationFnCalls++;
            await Future.delayed(const Duration(seconds: 3));
            return 'success';
          },
          onMutate: (v, c) async {
            await Future.delayed(const Duration(seconds: 1));
            throw Exception();
          },
        ),
      );

      observer.mutateAsync('').ignore();

      expect(observer.result.isPending, isTrue);

      async.elapse(const Duration(seconds: 1));

      expect(observer.result.isError, isTrue);
      expect(observer.result.error, isA<Exception>());
      expect(mutationFnCalls, 0);

      async.elapse(const Duration(seconds: 3));

      expect(mutationFnCalls, 0);
    }));

    test(
        'SHOULD propagate error '
        'WHEN throws ', withFakeAsync((async) {
      final error = Exception();
      Object? caughtError;

      final observer = MutationObserver(
        client,
        createOptions(
          mutationFn: (v, c) async => 'success',
          onMutate: (v, c) async {
            await Future.delayed(const Duration(seconds: 1));
            throw error;
          },
        ),
      );

      observer.mutateAsync('').then((_) {}).catchError((e) {
        caughtError = e;
      });

      expect(caughtError, isNull);

      async.elapse(const Duration(seconds: 1));

      expect(caughtError, same(error));
    }));

    test(
        'SHOULD receive correct arguments'
        '', withFakeAsync((async) {
      String? receivedVariables;
      MutationFunctionContext? receivedContext;

      final observer = MutationObserver(
        client,
        createOptions(
          mutationFn: (v, c) async {
            await Future.delayed(const Duration(seconds: 3));
            return 'success';
          },
          mutationKey: const ['key'],
          meta: {'meta-key': 'meta-value'},
          onMutate: (variables, context) async {
            receivedVariables = variables;
            receivedContext = context;
            return 'onMutate';
          },
        ),
      );

      observer.mutate('variables');

      expect(receivedVariables, 'variables');
      expect(
        receivedContext,
        MutationFunctionContext(
          client: client,
          mutationKey: const ['key'],
          meta: {'meta-key': 'meta-value'},
        ),
      );
    }));
  });

  group('MutationOptions.onSuccess', () {
    test(
        'SHOULD call on success'
        '', withFakeAsync((async) {
      int calls = 0;

      final observer = MutationObserver(
        client,
        createOptions(
          mutationFn: (v, c) async {
            await Future.delayed(const Duration(seconds: 3));
            return 'success';
          },
          onSuccess: (data, variables, onMutateResult, context) {
            calls++;
          },
        ),
      );

      observer.mutate('');

      async.elapse(const Duration(seconds: 3));

      expect(calls, 1);
    }));

    test(
        'SHOULD NOT call on error'
        '', withFakeAsync((async) {
      int calls = 0;

      final observer = MutationObserver(
        client,
        createOptions(
          mutationFn: (v, c) async {
            await Future.delayed(const Duration(seconds: 3));
            throw Exception();
          },
          onSuccess: (data, variables, onMutateResult, context) {
            calls++;
          },
        ),
      );

      observer.mutateAsync('').ignore();

      async.elapse(const Duration(seconds: 3));

      expect(calls, 0);
    }));

    test(
        'SHOULD receive correct arguments'
        '', withFakeAsync((async) {
      int calls = 0;
      String? receivedData;
      String? receivedVariables;
      String? receivedOnMutateResult;
      MutationFunctionContext? receivedContext;

      final observer = MutationObserver(
        client,
        createOptions(
          mutationFn: (v, c) async {
            await Future.delayed(const Duration(seconds: 3));
            return 'success';
          },
          mutationKey: const ['key'],
          meta: {'meta-key': 'meta-value'},
          onMutate: (v, c) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'onMutateResult';
          },
          onSuccess: (data, variables, onMutateResult, context) {
            calls++;
            receivedData = data;
            receivedVariables = variables;
            receivedOnMutateResult = onMutateResult;
            receivedContext = context;
          },
        ),
      );

      observer.mutate('variables');

      expect(calls, 0);

      async.elapse(const Duration(seconds: 1));

      expect(calls, 0);

      async.elapse(const Duration(seconds: 3));

      expect(calls, 1);
      expect(receivedData, 'success');
      expect(receivedVariables, 'variables');
      expect(receivedOnMutateResult, 'onMutateResult');
      expect(
        receivedContext,
        MutationFunctionContext(
          client: client,
          mutationKey: const ['key'],
          meta: {'meta-key': 'meta-value'},
        ),
      );
    }));
  });

  group('MutationOptions.onError', () {
    test(
        'SHOULD NOT call on success'
        '', withFakeAsync((async) {
      int calls = 0;

      final observer = MutationObserver(
        client,
        createOptions(
          mutationFn: (v, c) async {
            await Future.delayed(const Duration(seconds: 3));
            return 'success';
          },
          onError: (data, variables, onMutateResult, context) {
            calls++;
          },
        ),
      );

      observer.mutate('');

      async.elapse(const Duration(seconds: 3));

      expect(calls, 0);
    }));

    test(
        'SHOULD call on error'
        '', withFakeAsync((async) {
      int calls = 0;

      final observer = MutationObserver(
        client,
        createOptions(
          mutationFn: (v, c) async {
            await Future.delayed(const Duration(seconds: 3));
            throw Exception();
          },
          onError: (data, variables, onMutateResult, context) {
            calls++;
          },
        ),
      );

      observer.mutateAsync('').ignore();

      async.elapse(const Duration(seconds: 3));

      expect(calls, 1);
    }));

    test(
        'SHOULD receive correct arguments'
        '', withFakeAsync((async) {
      final error = Exception();
      int calls = 0;
      Object? receivedError;
      String? receivedVariables;
      String? receivedOnMutateResult;
      MutationFunctionContext? receivedContext;

      final observer = MutationObserver(
        client,
        createOptions(
          mutationFn: (v, c) async {
            await Future.delayed(const Duration(seconds: 3));
            throw error;
          },
          mutationKey: const ['key'],
          meta: {'meta-key': 'meta-value'},
          onMutate: (v, c) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'onMutateResult';
          },
          onError: (error, variables, onMutateResult, context) {
            calls++;
            receivedError = error;
            receivedVariables = variables;
            receivedOnMutateResult = onMutateResult;
            receivedContext = context;
          },
        ),
      );

      observer.mutateAsync('variables').ignore();

      expect(calls, 0);

      async.elapse(const Duration(seconds: 1));

      expect(calls, 0);

      async.elapse(const Duration(seconds: 3));

      expect(calls, 1);
      expect(receivedError, same(error));
      expect(receivedVariables, 'variables');
      expect(receivedOnMutateResult, 'onMutateResult');
      expect(
        receivedContext,
        MutationFunctionContext(
          client: client,
          mutationKey: const ['key'],
          meta: {'meta-key': 'meta-value'},
        ),
      );
    }));
  });

  group('MutationOptions.onSettled', () {
    test(
        'SHOULD call on success'
        '', withFakeAsync((async) {
      int calls = 0;

      final observer = MutationObserver(
        client,
        createOptions(
          mutationFn: (v, c) async {
            await Future.delayed(const Duration(seconds: 3));
            return 'success';
          },
          onSettled: (data, error, variables, onMutateResult, context) {
            calls++;
          },
        ),
      );

      observer.mutate('');

      async.elapse(const Duration(seconds: 3));

      expect(calls, 1);
    }));

    test(
        'SHOULD call on error'
        '', withFakeAsync((async) {
      int calls = 0;

      final observer = MutationObserver(
        client,
        createOptions(
          mutationFn: (v, c) async {
            await Future.delayed(const Duration(seconds: 3));
            throw Exception();
          },
          onSettled: (data, error, variables, onMutateResult, context) {
            calls++;
          },
        ),
      );

      observer.mutateAsync('').ignore();

      async.elapse(const Duration(seconds: 3));

      expect(calls, 1);
    }));

    test(
        'SHOULD receive correct arguments on success'
        '', withFakeAsync((async) {
      int calls = 0;
      String? receivedData;
      Object? receivedError;
      String? receivedVariables;
      String? receivedOnMutateResult;
      MutationFunctionContext? receivedContext;

      final observer = MutationObserver(
        client,
        createOptions(
          mutationFn: (v, c) async {
            await Future.delayed(const Duration(seconds: 3));
            return 'success';
          },
          mutationKey: const ['key'],
          meta: {'meta-key': 'meta-value'},
          onMutate: (v, c) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'onMutateResult';
          },
          onSettled: (data, error, variables, onMutateResult, context) {
            calls++;
            receivedData = data;
            receivedError = error;
            receivedVariables = variables;
            receivedOnMutateResult = onMutateResult;
            receivedContext = context;
          },
        ),
      );

      observer.mutate('variables');

      expect(calls, 0);

      async.elapse(const Duration(seconds: 1));

      expect(calls, 0);

      async.elapse(const Duration(seconds: 3));

      expect(calls, 1);
      expect(receivedData, 'success');
      expect(receivedError, isNull);
      expect(receivedVariables, 'variables');
      expect(receivedOnMutateResult, 'onMutateResult');
      expect(
        receivedContext,
        MutationFunctionContext(
          client: client,
          mutationKey: const ['key'],
          meta: {'meta-key': 'meta-value'},
        ),
      );
    }));
    test(
        'SHOULD receive correct arguments on error'
        '', withFakeAsync((async) {
      final error = Exception();
      int calls = 0;
      String? receivedData;
      Object? receivedError;
      String? receivedVariables;
      String? receivedOnMutateResult;
      MutationFunctionContext? receivedContext;

      final observer = MutationObserver(
        client,
        createOptions(
          mutationFn: (v, c) async {
            await Future.delayed(const Duration(seconds: 3));
            throw error;
          },
          mutationKey: const ['key'],
          meta: {'meta-key': 'meta-value'},
          onMutate: (v, c) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'onMutateResult';
          },
          onSettled: (data, error, variables, onMutateResult, context) {
            calls++;
            receivedData = data;
            receivedError = error;
            receivedVariables = variables;
            receivedOnMutateResult = onMutateResult;
            receivedContext = context;
          },
        ),
      );

      observer.mutateAsync('variables').ignore();

      expect(calls, 0);

      async.elapse(const Duration(seconds: 1));

      expect(calls, 0);

      async.elapse(const Duration(seconds: 3));

      expect(calls, 1);
      expect(receivedData, isNull);
      expect(receivedError, same(error));
      expect(receivedVariables, 'variables');
      expect(receivedOnMutateResult, 'onMutateResult');
      expect(
        receivedContext,
        MutationFunctionContext(
          client: client,
          mutationKey: const ['key'],
          meta: {'meta-key': 'meta-value'},
        ),
      );
    }));
  });

  group('callbacks', () {
    test(
        'SHOULD call callbacks in correct order asynchronously'
        '', withFakeAsync((async) {
      final callOrder = <String>[];

      // Success case
      final observer1 = MutationObserver(
        client,
        createOptions(
          mutationFn: (v, c) async {
            await Future.delayed(const Duration(seconds: 1));
            callOrder.add('mutationFn');
            return 'result';
          },
          onMutate: (v, c) async {
            await Future.delayed(const Duration(seconds: 1));
            callOrder.add('onMutate');
            return 'context';
          },
          onSuccess: (data, v, context, c) async {
            await Future.delayed(const Duration(seconds: 1));
            callOrder.add('onSuccess');
          },
          onSettled: (data, error, v, context, c) async {
            await Future.delayed(const Duration(seconds: 1));
            callOrder.add('onSettled');
          },
        ),
      );

      observer1.mutate('');

      async.elapse(const Duration(seconds: 1));
      expect(callOrder, ['onMutate']);

      async.elapse(const Duration(seconds: 1));
      expect(callOrder, ['onMutate', 'mutationFn']);

      async.elapse(const Duration(seconds: 1));
      expect(callOrder, ['onMutate', 'mutationFn', 'onSuccess']);

      async.elapse(const Duration(seconds: 1));
      expect(callOrder, ['onMutate', 'mutationFn', 'onSuccess', 'onSettled']);

      callOrder.clear();

      // Error case
      final observer2 = MutationObserver(
        client,
        createOptions(
          mutationFn: (v, c) async {
            await Future.delayed(const Duration(seconds: 1));
            callOrder.add('mutationFn');
            throw Exception();
          },
          onMutate: (v, c) async {
            await Future.delayed(const Duration(seconds: 1));
            callOrder.add('onMutate');
            return 'context';
          },
          onError: (error, v, context, c) async {
            await Future.delayed(const Duration(seconds: 1));
            callOrder.add('onError');
          },
          onSettled: (data, error, v, context, c) async {
            await Future.delayed(const Duration(seconds: 1));
            callOrder.add('onSettled');
          },
        ),
      );

      observer2.mutateAsync('').ignore();

      async.elapse(const Duration(seconds: 1));
      expect(callOrder, ['onMutate']);

      async.elapse(const Duration(seconds: 1));
      expect(callOrder, ['onMutate', 'mutationFn']);

      async.elapse(const Duration(seconds: 1));
      expect(callOrder, ['onMutate', 'mutationFn', 'onError']);

      async.elapse(const Duration(seconds: 1));
      expect(callOrder, ['onMutate', 'mutationFn', 'onError', 'onSettled']);
    }));
  });

  group('MutationOptions.retry', () {
    test(
        'SHOULD NOT retry by default'
        '', withFakeAsync((async) {
      int calls = 0;

      final observer = MutationObserver(
        client,
        createOptions(
          mutationFn: (v, c) async {
            calls++;
            await Future.delayed(const Duration(seconds: 3));
            throw Exception();
          },
        ),
      );

      observer.mutateAsync('').ignore();

      async.elapse(const Duration(seconds: 3));

      expect(calls, 1);
      expect(observer.result.isError, isTrue);

      // Wait long enough
      async.elapse(const Duration(hours: 24));

      // Should NOT have retried
      expect(calls, 1);
    }));

    test(
        'SHOULD retry by condition with set delay'
        '', withFakeAsync((async) {
      int calls = 0;

      final observer = MutationObserver(
        client,
        createOptions(
          mutationFn: (v, c) async {
            calls++;
            await Future.delayed(Duration.zero);
            throw Exception();
          },
          retry: (retryCount, error) {
            if (retryCount >= 3) return null;
            return const Duration(seconds: 1);
          },
        ),
      );

      observer.mutateAsync('').ignore();

      async.elapse(Duration.zero);

      // First attempt
      expect(calls, 1);
      expect(observer.result.failureCount, 1);
      expect(observer.result.isPending, isTrue);

      // First retry after 1 second
      async.elapse(const Duration(seconds: 1));
      expect(calls, 2);
      expect(observer.result.failureCount, 2);
      expect(observer.result.isPending, isTrue);

      // Second retry after 1 second
      async.elapse(const Duration(seconds: 1));
      expect(calls, 3);
      expect(observer.result.failureCount, 3);
      expect(observer.result.isPending, isTrue);

      // Third retry after 1 second
      async.elapse(const Duration(seconds: 1));
      expect(calls, 4);
      expect(observer.result.failureCount, 4);
      expect(observer.result.isError, isTrue);

      // Wait long enough
      async.elapse(const Duration(hours: 24));

      // Should NOT have retried
      expect(calls, 4);
      expect(observer.result.failureCount, 4);
    }));

    test(
        'SHOULD retry and succeed'
        '', withFakeAsync((async) {
      int calls = 0;

      final observer = MutationObserver(
        client,
        createOptions(
          mutationFn: (v, c) async {
            calls++;
            await Future.delayed(Duration.zero);
            if (calls < 3) {
              throw Exception();
            }
            return 'success';
          },
          retry: (retryCount, error) {
            if (retryCount >= 5) return null;
            return const Duration(seconds: 1);
          },
        ),
      );

      observer.mutate('');
      async.elapse(Duration.zero);

      expect(calls, 1);
      expect(observer.result.failureCount, 1);
      expect(observer.result.failureReason, isA<Exception>());
      expect(observer.result.isPending, isTrue);

      // First retry fails
      async.elapse(const Duration(seconds: 1));
      expect(calls, 2);
      expect(observer.result.failureCount, 2);
      expect(observer.result.failureReason, isA<Exception>());
      expect(observer.result.isPending, isTrue);

      // Second retry succeeds
      async.elapse(const Duration(seconds: 1));
      expect(calls, 3);
      expect(observer.result.isSuccess, isTrue);
      expect(observer.result.data, 'success');
      // failureCount and failureReason are reset on success
      expect(observer.result.failureCount, 0);
      expect(observer.result.failureReason, isNull);
    }));

    test(
        'SHOULD retry with linear delay increment'
        '', withFakeAsync((async) {
      int calls = 0;

      final observer = MutationObserver(
        client,
        createOptions(
          mutationFn: (v, c) async {
            calls++;
            await Future.delayed(Duration.zero);
            throw Exception();
          },
          retry: (retryCount, error) {
            if (retryCount > 2) return null;
            // Linear delays: 2s, 4s, 6s
            return Duration(seconds: 2 * (retryCount + 1));
          },
        ),
      );

      observer.mutateAsync('').ignore();
      async.elapse(Duration.zero);

      expect(calls, 1);
      expect(observer.result.failureCount, 1);
      expect(observer.result.isPending, isTrue);

      async.elapse(const Duration(seconds: 2));
      expect(calls, 2);
      expect(observer.result.failureCount, 2);
      expect(observer.result.isPending, isTrue);

      async.elapse(const Duration(seconds: 4));
      expect(calls, 3);
      expect(observer.result.failureCount, 3);
      expect(observer.result.isPending, isTrue);

      async.elapse(const Duration(seconds: 6));
      expect(calls, 4);
      expect(observer.result.failureCount, 4);
      expect(observer.result.isError, isTrue);

      // Wait long enough and check
      async.elapse(const Duration(hours: 24));
      expect(calls, 4);
      expect(observer.result.failureCount, 4);
    }));
  });

  group('MutationOptions.gcDuration', () {
    test(
        'SHOULD remove mutation from cache after gcDuration '
        'WHEN observer is disposed', withFakeAsync((async) {
      final observer = MutationObserver(
        client,
        createOptions(
          mutationFn: (v, c) async => 'success',
          mutationKey: const ['key'],
          gcDuration: const GcDuration(minutes: 5),
        ),
      );

      observer.mutate('');
      observer.onUnmount();

      // Keep elapsing time by 10s until mutation is removed from cache
      while (cache.find(mutationKey: const ['key']) != null) {
        async.elapse(const Duration(seconds: 10));
      }

      // Should have elapsed 5 mins
      expect(async.elapsed, const Duration(minutes: 5));
    }));

    test(
        'SHOULD remove mutation from cache after gcDuration '
        'WHEN observer is reset', withFakeAsync((async) {
      final observer = MutationObserver(
        client,
        createOptions(
          mutationFn: (v, c) async => 'success',
          mutationKey: const ['key'],
          gcDuration: const GcDuration(minutes: 6),
        ),
      );

      observer.mutate('');
      observer.reset();

      // Keep elapsing time by 10s until mutation is removed from cache
      while (cache.find(mutationKey: const ['key']) != null) {
        async.elapse(const Duration(seconds: 10));
      }

      // Should have elapsed 6 minutes
      expect(async.elapsed, const Duration(minutes: 6));
    }));

    test(
        'SHOULD NOT remove mutation from cache '
        'WHEN gcDuration == GcDuration.infinity', withFakeAsync((async) {
      final observer = MutationObserver(
        client,
        createOptions(
          mutationFn: (v, c) async => 'success',
          mutationKey: const ['key'],
          gcDuration: GcDuration.infinity,
        ),
      );

      observer.mutate('');
      observer.onUnmount();

      // Mutation should never be removed with infinity duration
      async.elapse(const Duration(days: 365));
      expect(cache.find(mutationKey: const ['key']), isNotNull);
    }));

    test(
        'SHOULD NOT remove pending mutation from cache '
        'WHEN gcDuration elapses', withFakeAsync((async) {
      final completer = Completer<String>();
      final observer = MutationObserver(
        client,
        createOptions(
          mutationFn: (v, c) => completer.future,
          mutationKey: const ['key'],
          gcDuration: const GcDuration(minutes: 10),
        ),
      );

      observer.mutate('');
      observer.onUnmount();

      // Wait for multiple gc cycles while pending - mutation should NOT be removed
      async.elapse(const Duration(minutes: 10));
      expect(cache.find(mutationKey: const ['key']), isNotNull);

      async.elapse(const Duration(minutes: 10));
      expect(cache.find(mutationKey: const ['key']), isNotNull);

      // Complete the mutation after 12 minutes
      completer.complete('success');
      final completedAt = clock.now();

      // Keep elapsing time by 10s until mutation is removed from cache
      while (cache.find(mutationKey: const ['key']) != null) {
        async.elapse(const Duration(seconds: 10));
      }

      // GC timer reschedules itself while pending, so mutation is removed
      // on the next gc cycle after completion
      expect(clock.now().difference(completedAt), const Duration(minutes: 10));
    }));

    test(
        'SHOULD restart gc timer from beginning '
        'WHEN observer reattaches after partial gc duration',
        withFakeAsync((async) {
      final observer = MutationObserver(
        client,
        createOptions(
          mutationFn: (v, c) async => 'success',
          mutationKey: const ['key'],
          gcDuration: const GcDuration(minutes: 10),
        ),
      );

      observer.mutate('');
      observer.onUnmount();

      // Wait part of the gc duration (5 minutes)
      async.elapse(const Duration(minutes: 5));
      expect(cache.find(mutationKey: const ['key']), isNotNull);

      // Mutate again - this creates a new mutation and attaches observer
      observer.mutate('');
      // Dispose again - gc timer restarts from beginning
      observer.onUnmount();
      final disposedAt = clock.now();

      // Keep elapsing time by 10s until mutation is removed from cache
      while (cache.find(mutationKey: const ['key']) != null) {
        async.elapse(const Duration(seconds: 10));
      }

      // Should have elapsed 10 mins since last dispose
      expect(clock.now().difference(disposedAt), const Duration(minutes: 10));
    }));

    test(
        'SHOULD use default gcDuration of 5 minutes '
        'WHEN gcDuration is not specified', withFakeAsync((async) {
      final observer = MutationObserver(
        client,
        MutationOptions<String, Object, String, void>(
          mutationFn: (v, c) async => 'success',
          mutationKey: const ['key'],
        ),
      );

      observer.mutate('');
      observer.onUnmount();

      // Keep elapsing time by 10s until mutation is removed from cache
      while (cache.find(mutationKey: const ['key']) != null) {
        async.elapse(const Duration(seconds: 10));
      }

      // Should have elapsed default 5 minutes
      expect(async.elapsed, const Duration(minutes: 5));
    }));
  });
}
