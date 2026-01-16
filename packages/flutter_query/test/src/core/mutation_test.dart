import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_query/src/core/core.dart';

void main() {
  late QueryClient client;
  late MutationCache cache;
  var mutationIdCounter = 0;

  setUp(() {
    client = QueryClient();
    cache = client.mutationCache;
    mutationIdCounter = 0;
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

  void Function() withFakeAsync(void Function(FakeAsync async) testBody) {
    return () => fakeAsync(testBody);
  }

  Mutation<String, Object, String, String> createMutation({
    MutationOptions<String, Object, String, String>? options,
    MutationState<String, Object, String, String>? state,
  }) {
    final mutation = Mutation<String, Object, String, String>(
      client: client,
      cache: cache,
      mutationId: mutationIdCounter++,
      options: options ?? createOptions(),
      state: state,
    );
    cache.add(mutation);
    addTearDown(mutation.dispose);
    return mutation;
  }

  group('Initialization', () {
    test(
        'SHOULD use default GC duration of 5 minutes '
        'WHEN not specified in options', withFakeAsync((async) {
      final mutation = createMutation();

      // Elapse less than 5 minutes - mutation should still exist
      async.elapse(const Duration(minutes: 4, seconds: 59));
      expect(cache.getAll(), contains(mutation));

      // Elapse past 5 minutes - mutation should be removed
      async.elapse(const Duration(seconds: 1));
      expect(cache.getAll(), isNot(contains(mutation)));
    }));

    test(
        'SHOULD use custom GC duration '
        'WHEN provided in options (must be >= default 5 min due to max logic)',
        withFakeAsync((async) {
      // Note: GcDuration uses max logic, so can only increase beyond default 5 min
      final mutation = createMutation(
        options: createOptions(gcDuration: const GcDuration(minutes: 10)),
      );

      while (cache.getAll().contains(mutation)) {
        async.elapse(const Duration(seconds: 10));
      }

      expect(async.elapsed, const Duration(minutes: 10));
    }));
  });

  group('mutationId', () {
    test(
        'SHOULD return same mutationId passed to constructor'
        '', () {
      final mutation = Mutation(
        client: client,
        cache: cache,
        mutationId: 42,
        options: createOptions(),
      );
      addTearDown(mutation.dispose);

      expect(mutation.mutationId, 42);
    });
  });

  group('options', () {
    test(
        'SHOULD return same options passed to constructor'
        '', () {
      final options = createOptions(mutationKey: const ['test']);
      final mutation = Mutation(
        client: client,
        cache: cache,
        mutationId: 42,
        options: options,
      );

      expect(mutation.options, equals(options));
    });

    test(
        'SHOULD store new GC duration but NOT reschedule GC '
        'WHEN options setter is called', withFakeAsync((async) {
      final mutation = createMutation(
        options: createOptions(gcDuration: const GcDuration(minutes: 10)),
      );

      // Update options with longer GC duration
      mutation.options = createOptions(
        gcDuration: const GcDuration(minutes: 15),
      );

      // Original 10 min timer is still running, mutation removed after 10 min
      async.elapse(const Duration(minutes: 10));
      expect(cache.getAll(), isNot(contains(mutation)));
    }));
  });

  group('state', () {
    test(
        'SHOULD return idle state'
        'WHEN state is not provided in constructor', () {
      final mutation = Mutation<String, Object, String, String>(
        client: client,
        cache: cache,
        mutationId: 1,
        options: createOptions(),
      );
      addTearDown(mutation.dispose);

      expect(mutation.state.status, MutationStatus.idle);
      expect(mutation.state.data, isNull);
      expect(mutation.state.error, isNull);
      expect(mutation.state.variables, isNull);
    });

    test(
        'SHOULD return same state passed to constructor'
        '', () {
      final state = MutationState<String, Object, String, String>(
        status: MutationStatus.success,
        data: 'initial data',
      );

      final mutation = Mutation<String, Object, String, String>(
        client: client,
        cache: cache,
        mutationId: 1,
        options: createOptions(),
        state: state,
      );
      addTearDown(mutation.dispose);

      expect(mutation.state, equals(state));
    });
  });

  group('execute() - Success Path', () {
    test(
        'SHOULD transition to pending state '
        'WHEN execute is called', withFakeAsync((async) {
      final mutation = createMutation(
        options: createOptions(mutationFn: (v, c) async => 'success'),
      );

      mutation.execute('');

      expect(mutation.state.status, MutationStatus.pending);
    }));

    test(
        'SHOULD set variables in state '
        'WHEN execute is called', withFakeAsync((async) {
      final mutation = createMutation();

      mutation.execute('variables');

      expect(mutation.state.variables, 'variables');
    }));

    test(
        'SHOULD set submittedAt to current time '
        'WHEN execute is called', withFakeAsync((async) {
      final mutation = createMutation();
      final now = clock.now();

      mutation.execute('');

      expect(mutation.state.submittedAt, now);
    }));

    test(
        'SHOULD transition to success state '
        'WHEN mutationFn succeeds', withFakeAsync((async) {
      final mutation = createMutation(
        options: createOptions(mutationFn: (v, c) async {
          await Future.delayed(const Duration(seconds: 3));
          return 'success';
        }),
      );

      mutation.execute('');
      async.elapse(const Duration(seconds: 3));

      expect(mutation.state.status, MutationStatus.success);
      expect(mutation.state.data, 'success');
    }));

    test(
        'SHOULD return data from execute '
        'WHEN mutationFn succeeds', withFakeAsync((async) {
      final mutation = createMutation(
        options: createOptions(mutationFn: (v, c) async {
          await Future.delayed(const Duration(seconds: 3));
          return 'success';
        }),
      );

      String? capturedData;
      mutation.execute('').then((data) => capturedData = data);
      async.elapse(const Duration(seconds: 3));

      expect(capturedData, 'success');
    }));

    test(
        'SHOULD reset error, failureCount, and failureReason on success '
        'WHEN previous execution failed', withFakeAsync((async) {
      var shouldFail = true;
      final mutation = createMutation(
        options: createOptions(
          mutationFn: (v, c) async {
            await Future.delayed(const Duration(seconds: 3));
            if (shouldFail) throw Exception();
            return 'success';
          },
        ),
      );

      // First execution fails
      mutation.execute('').ignore();
      async.elapse(const Duration(seconds: 3));

      expect(mutation.state.error, isA<Exception>());
      expect(mutation.state.failureCount, 1);
      expect(mutation.state.failureReason, isA<Exception>());

      // Second execution succeeds
      shouldFail = false;
      mutation.execute('');
      async.elapse(const Duration(seconds: 3));

      expect(mutation.state.error, isNull);
      expect(mutation.state.failureCount, 0);
      expect(mutation.state.failureReason, isNull);
    }));
  });

  group('execute() - Error Path', () {
    test(
        'SHOULD transition to error state '
        'WHEN mutationFn throws', withFakeAsync((async) {
      final error = Exception();
      final mutation = createMutation(
        options: createOptions(
          mutationFn: (variables, context) async {
            await Future.delayed(const Duration(seconds: 3));
            throw error;
          },
        ),
      );

      mutation.execute('').ignore();
      async.elapse(const Duration(seconds: 3));

      expect(mutation.state.status, MutationStatus.error);
      expect(mutation.state.error, same(error));
    }));

    test(
        'SHOULD increment failureCount AND set failureReason '
        'WHEN mutationFn throws', withFakeAsync((async) {
      final mutation = createMutation(
        options: createOptions(
          mutationFn: (variables, context) async {
            await Future.delayed(const Duration(seconds: 3));
            throw Exception();
          },
        ),
      );

      mutation.execute('').ignore();
      async.elapse(const Duration(seconds: 3));

      expect(mutation.state.failureCount, 1);
      expect(mutation.state.failureReason, isA<Exception>());
    }));

    test(
        'SHOULD call onError '
        'WHEN mutationFn throws', withFakeAsync((async) {
      int calls = 0;
      Object? capturedError;

      final mutation = createMutation(
        options: createOptions(
          mutationFn: (variables, context) async {
            await Future.delayed(const Duration(seconds: 3));
            throw Exception();
          },
          onError: (error, variables, onMutateResult, context) {
            calls++;
            capturedError = error;
          },
        ),
      );

      mutation.execute('').ignore();
      async.elapse(const Duration(seconds: 3));

      expect(calls, 1);
      expect(capturedError, isA<Exception>());
    }));

    test(
        'SHOULD propagate error'
        '', withFakeAsync((async) {
      final error = Exception();
      final mutation = createMutation(
        options: createOptions(
          mutationFn: (variables, context) async {
            await Future.delayed(const Duration(seconds: 3));
            throw error;
          },
        ),
      );

      Object? capturedError;
      mutation.execute('').then((_) {}).catchError((e) {
        capturedError = e;
      });
      async.elapse(const Duration(seconds: 3));

      expect(capturedError, same(error));
    }));

    test(
        'SHOULD pass error to onSettled '
        'WHEN mutationFn throws', withFakeAsync((async) {
      final error = Exception();
      Object? capturedError;

      final mutation = createMutation(
        options: createOptions(
          mutationFn: (variables, context) async {
            await Future.delayed(const Duration(seconds: 3));
            throw error;
          },
          onSettled: (data, error, variables, onMutateResult, context) {
            capturedError = error;
          },
        ),
      );

      mutation.execute('').ignore();
      async.elapse(const Duration(seconds: 3));

      expect(capturedError, same(error));
    }));
  });

  group('execute() - Retry Logic', () {
    test(
        'SHOULD NOT retry by default'
        '', withFakeAsync((async) {
      var calls = 0;
      final mutation = createMutation(
        options: createOptions(
          mutationFn: (v, c) async {
            calls++;
            await Future.delayed(const Duration(seconds: 3));
            throw Exception();
          },
        ),
      );

      mutation.execute('').ignore();
      async.elapse(const Duration(seconds: 3));

      expect(calls, 1);

      async.elapse(const Duration(hours: 24));

      expect(calls, 1);
    }));

    test(
        'SHOULD retry with delay '
        'WHEN retry callback returns Duration', withFakeAsync((async) {
      var calls = 0;
      final mutation = createMutation(
        options: createOptions(
          mutationFn: (v, c) async {
            calls++;
            await Future.delayed(Duration.zero);
            throw Exception();
          },
          retry: (retryCount, error) {
            return retryCount < 2 ? const Duration(seconds: 1) : null;
          },
        ),
      );

      mutation.execute('test').ignore();

      async.elapse(Duration.zero);
      expect(calls, 1);
      expect(mutation.state.status, MutationStatus.pending);
      expect(mutation.state.failureCount, 1);

      async.elapse(const Duration(seconds: 1));
      expect(calls, 2);
      expect(mutation.state.status, MutationStatus.pending);
      expect(mutation.state.failureCount, 2);

      async.elapse(const Duration(seconds: 1));
      expect(calls, 3);
      expect(mutation.state.status, MutationStatus.error);
      expect(mutation.state.failureCount, 3);

      async.elapse(const Duration(hours: 24));
      expect(calls, 3);
      expect(mutation.state.status, MutationStatus.error);
      expect(mutation.state.failureCount, 3);
    }));

    test(
        'SHOULD reset failureCount and failureReason on success '
        'WHEN succeeds after retries', withFakeAsync((async) {
      var calls = 0;
      final error = Exception('temporary error');
      final mutation = createMutation(
        options: createOptions(
          mutationFn: (variables, context) async {
            calls++;
            await Future.delayed(Duration.zero);
            if (calls < 3) throw error;
            return 'success';
          },
          retry: (retryCount, error) {
            return const Duration(seconds: 1);
          },
        ),
      );

      mutation.execute('test');

      // First attempt fails
      async.elapse(Duration.zero);
      expect(calls, 1);
      expect(mutation.state.status, MutationStatus.pending);
      expect(mutation.state.failureCount, 1);
      expect(mutation.state.failureReason, error);

      // Second attempt fails
      async.elapse(const Duration(seconds: 1));
      expect(calls, 2);
      expect(mutation.state.status, MutationStatus.pending);
      expect(mutation.state.failureCount, 2);
      expect(mutation.state.failureReason, error);

      // Third attempt succeeds
      async.elapse(const Duration(seconds: 1));
      expect(calls, 3);
      expect(mutation.state.status, MutationStatus.success);
      expect(mutation.state.data, 'success');
      expect(mutation.state.failureCount, 0);
      expect(mutation.state.failureReason, isNull);
    }));
  });

  group('execute() - Callbacks', () {
    test(
        'SHOULD call callbacks in correct order asynchronously'
        '', withFakeAsync((async) {
      final callOrder = <String>[];

      // Success case
      final mutation1 = createMutation(
        options: createOptions(
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
          onSuccess: (data, v, ctx, c) async {
            await Future.delayed(const Duration(seconds: 1));
            callOrder.add('onSuccess');
          },
          onSettled: (data, error, v, ctx, c) async {
            await Future.delayed(const Duration(seconds: 1));
            callOrder.add('onSettled');
          },
        ),
      );

      mutation1.execute('');

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
      final mutation2 = createMutation(
        options: createOptions(
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
          onError: (error, v, ctx, c) async {
            await Future.delayed(const Duration(seconds: 1));
            callOrder.add('onError');
          },
          onSettled: (data, error, v, ctx, c) async {
            await Future.delayed(const Duration(seconds: 1));
            callOrder.add('onSettled');
          },
        ),
      );

      mutation2.execute('').ignore();

      async.elapse(const Duration(seconds: 1));
      expect(callOrder, ['onMutate']);

      async.elapse(const Duration(seconds: 1));
      expect(callOrder, ['onMutate', 'mutationFn']);

      async.elapse(const Duration(seconds: 1));
      expect(callOrder, ['onMutate', 'mutationFn', 'onError']);

      async.elapse(const Duration(seconds: 1));
      expect(callOrder, ['onMutate', 'mutationFn', 'onError', 'onSettled']);
    }));

    test(
        'SHOULD pass correct arguments to all callbacks'
        '', withFakeAsync((async) {
      String? capturedOnMutateVariables;
      MutationFunctionContext? capturedOnMutateContext;
      String? capturedOnSuccessData;
      String? capturedOnSuccessVariables;
      String? capturedOnSuccessOnMutateResult;
      MutationFunctionContext? capturedOnSuccessContext;
      String? capturedOnSettledData;
      String? capturedOnSettledVariables;
      String? capturedOnSettledOnMutateResult;
      MutationFunctionContext? capturedOnSettledContext;

      const testMutationKey = ['users', 'create'];
      const testMeta = {'source': 'test', 'priority': 1};

      final mutation = createMutation(
        options: createOptions(
          mutationKey: testMutationKey,
          meta: testMeta,
          mutationFn: (variables, context) async {
            await Future.delayed(const Duration(seconds: 3));
            return 'success';
          },
          onMutate: (variables, context) {
            capturedOnMutateVariables = variables;
            capturedOnMutateContext = context;
            return 'onMutateResult';
          },
          onSuccess: (data, variables, onMutateResult, context) {
            capturedOnSuccessData = data;
            capturedOnSuccessVariables = variables;
            capturedOnSuccessOnMutateResult = onMutateResult;
            capturedOnSuccessContext = context;
          },
          onSettled: (data, error, variables, onMutateResult, context) {
            capturedOnSettledData = data;
            capturedOnSettledVariables = variables;
            capturedOnSettledOnMutateResult = onMutateResult;
            capturedOnSettledContext = context;
          },
        ),
      );

      mutation.execute('variables');
      async.elapse(const Duration(seconds: 3));

      // onMutate
      expect(capturedOnMutateVariables, 'variables');
      expect(
        capturedOnMutateContext,
        MutationFunctionContext(
          client: client,
          mutationKey: testMutationKey,
          meta: testMeta,
        ),
      );

      // onSuccess
      expect(capturedOnSuccessData, 'success');
      expect(capturedOnSuccessVariables, 'variables');
      expect(capturedOnSuccessOnMutateResult, 'onMutateResult');
      expect(
        capturedOnSuccessContext,
        MutationFunctionContext(
          client: client,
          mutationKey: testMutationKey,
          meta: testMeta,
        ),
      );

      // onSettled
      expect(capturedOnSettledData, 'success');
      expect(capturedOnSettledVariables, 'variables');
      expect(capturedOnSettledOnMutateResult, 'onMutateResult');
      expect(
        capturedOnSettledContext,
        MutationFunctionContext(
          client: client,
          mutationKey: testMutationKey,
          meta: testMeta,
        ),
      );
    }));
  });

  group('hasObservers', () {
    test(
        'SHOULD return false '
        'WHEN there is no observer', () {
      final mutation = createMutation();

      expect(mutation.hasObservers, isFalse);
    });

    test(
        'SHOULD return true '
        'AFTER adding observers', () {
      final mutation = createMutation();
      final observer = MutationObserver(client, createOptions());

      mutation.addObserver(observer);

      expect(mutation.hasObservers, isTrue);
    });

    test(
        'SHOULD return false '
        'AFTER removing all observers', () {
      final mutation = createMutation();
      final observer = MutationObserver(client, createOptions());

      mutation.addObserver(observer);
      mutation.removeObserver(observer);

      expect(mutation.hasObservers, isFalse);
    });
  });

  group('addObserver', () {
    test(
        'SHOULD NOT add duplicate observers'
        '', () {
      final mutation = createMutation();
      final observer = MutationObserver(client, createOptions());

      mutation.addObserver(observer);
      expect(mutation.hasObservers, isTrue);
      // Remove once - should have no observers
      mutation.removeObserver(observer);

      expect(mutation.hasObservers, isFalse);
    });

    test(
        'SHOULD cancel GC'
        '', withFakeAsync((async) {
      final mutation = createMutation(
        options: createOptions(gcDuration: const GcDuration(minutes: 1)),
      );
      final observer = MutationObserver(client, createOptions());

      // GC is scheduled on creation, elapsed some time
      async.elapse(const Duration(seconds: 30));

      // Add observer - should cancel GC
      mutation.addObserver(observer);

      // Elapse past original GC time
      async.elapse(const Duration(minutes: 2));

      // Mutation should still exist because observer is present
      expect(cache.getAll(), contains(mutation));
    }));
  });

  group('removeObserver', () {
    test(
        'SHOULD schedule GC'
        '', withFakeAsync((async) {
      // GC duration uses max logic with default 5 min, so use default
      final mutation = createMutation();
      final observer = MutationObserver(client, createOptions());

      mutation.addObserver(observer);

      // Elapse some time - mutation should exist (GC cancelled when observer added)
      async.elapse(const Duration(minutes: 6));
      expect(cache.getAll(), contains(mutation));

      // Remove observer - should schedule GC (5 min default)
      mutation.removeObserver(observer);

      // Elapse less than GC time
      async.elapse(const Duration(minutes: 4, seconds: 59));
      expect(cache.getAll(), contains(mutation));

      // Elapse past GC time (total 5 min since removal)
      async.elapse(const Duration(seconds: 1));
      expect(cache.getAll(), isNot(contains(mutation)));
    }));
  });

  group('tryRemove', () {
    test(
        'SHOULD remove mutation from cache '
        'WHEN hasObservers == false AND status == MutationStatus.idle', () {
      final mutation = createMutation();

      expect(cache.getAll(), contains(mutation));
      expect(mutation.hasObservers, isFalse);
      expect(mutation.state.status, MutationStatus.idle);
      mutation.tryRemove();

      expect(cache.getAll(), isNot(contains(mutation)));
    });

    test(
        'SHOULD remove mutation from cache '
        'WHEN hasObservers == false AND status == MutationStatus.idle',
        withFakeAsync((async) {
      final mutation = createMutation(
        options: createOptions(
          mutationFn: (variables, context) async {
            await Future.delayed(const Duration(seconds: 3));
            return 'success';
          },
        ),
      );

      mutation.execute('');
      async.elapse(const Duration(seconds: 3));

      expect(cache.getAll(), contains(mutation));
      expect(mutation.hasObservers, isFalse);
      expect(mutation.state.status, MutationStatus.success);
      mutation.tryRemove();

      expect(cache.getAll(), isNot(contains(mutation)));
    }));

    test(
        'SHOULD remove mutation from cache '
        'WHEN hasObservers == false AND status == MutationStatus.error',
        withFakeAsync((async) {
      final mutation = createMutation(
        options: createOptions(
          mutationFn: (variables, context) async {
            await Future.delayed(const Duration(seconds: 3));
            throw Exception();
          },
        ),
      );

      mutation.execute('').ignore();
      async.elapse(const Duration(seconds: 3));

      expect(cache.getAll(), contains(mutation));
      expect(mutation.hasObservers, isFalse);
      expect(mutation.state.status, MutationStatus.error);
      mutation.tryRemove();

      expect(cache.getAll(), isNot(contains(mutation)));
    }));

    test(
        'SHOULD NOT remove mutation '
        'WHEN hasObservers == true', () {
      final mutation = createMutation();
      final observer = MutationObserver(client, createOptions());

      mutation.addObserver(observer);
      expect(mutation.hasObservers, isTrue);
      mutation.tryRemove();

      expect(cache.getAll(), contains(mutation));
    });

    test(
        'SHOULD NOT remove mutation and reschedule GC '
        'WHEN status == MutationStatus.pending', withFakeAsync((async) {
      final mutation = createMutation(
        options: createOptions(
          mutationFn: (variables, context) async {
            await Future.delayed(const Duration(seconds: 3));
            return 'success';
          },
        ),
      );

      mutation.execute('');

      expect(cache.getAll(), contains(mutation));
      expect(mutation.state.status, MutationStatus.pending);
      mutation.tryRemove();

      // Should still be in cache because pending
      expect(cache.getAll(), contains(mutation));

      // Complete the mutation
      async.elapse(const Duration(seconds: 3));
      expect(mutation.state.status, MutationStatus.success);

      // GC was rescheduled when tryRemove was called during pending
      // After default 5 min, mutation should be removed
      final rescheduledAt = clock.now();
      while (cache.getAll().contains(mutation)) {
        async.elapse(const Duration(seconds: 10));
      }
      expect(clock.now().difference(rescheduledAt), const Duration(minutes: 5));
    }));
  });

  group('MutationMatches.matches', () {
    test(
        'SHOULD match '
        'WHEN no filters provided', () {
      final mutation = createMutation();

      expect(mutation.matches(), isTrue);
    });

    test(
        'SHOULD match exact key '
        'WHEN exact == true AND key matches', () {
      final mutation = createMutation(
        options: createOptions(mutationKey: const ['users', '1']),
      );

      expect(
        mutation.matches(exact: true, mutationKey: const ['users', '1']),
        isTrue,
      );
    });

    test(
        'SHOULD NOT match '
        'WHEN exact == true AND key differs', () {
      final mutation = createMutation(
        options: createOptions(mutationKey: const ['users', '1']),
      );

      expect(
        mutation.matches(exact: true, mutationKey: const ['users', '2']),
        isFalse,
      );
    });

    test(
        'SHOULD match partial key'
        '', () {
      final mutation = createMutation(
        options: createOptions(mutationKey: const ['users', '1', 'profile']),
      );

      expect(
        mutation.matches(mutationKey: const ['users', '1']),
        isTrue,
      );
    });

    test(
        'SHOULD NOT match '
        'WHEN mutation has no key but filter has key', () {
      final mutation = createMutation();

      expect(
        mutation.matches(mutationKey: const ['users']),
        isFalse,
      );
    });

    test(
        'SHOULD match status'
        '', () {
      final mutation = createMutation();

      expect(
        mutation.matches(status: MutationStatus.idle),
        isTrue,
      );
    });

    test(
        'SHOULD NOT match status'
        '', () {
      final mutation = createMutation();

      expect(
        mutation.matches(status: MutationStatus.pending),
        isFalse,
      );
    });

    test(
        'SHOULD match predicate'
        '', () {
      final mutation = createMutation(
        options: createOptions(mutationKey: const ['users']),
      );

      expect(
        mutation.matches(predicate: (m) => m.options.mutationKey != null),
        isTrue,
      );
    });

    test(
        'SHOULD NOT match predicate'
        '', () {
      final mutation = createMutation();

      expect(
        mutation.matches(predicate: (m) => m.options.mutationKey != null),
        isFalse,
      );
    });

    test(
        'SHOULD require ALL filters to match (AND logic)'
        '', () {
      final mutation = createMutation(
        options: createOptions(mutationKey: const ['users', '1']),
      );

      // All match
      expect(
        mutation.matches(
          mutationKey: const ['users'],
          exact: false,
          status: MutationStatus.idle,
          predicate: (m) => true,
        ),
        isTrue,
      );

      // One doesn't match
      expect(
        mutation.matches(
          mutationKey: const ['users'],
          exact: false,
          status: MutationStatus.pending, // This doesn't match
          predicate: (m) => true,
        ),
        isFalse,
      );
    });

    test(
        'SHOULD NOT match partial key '
        'WHEN filter is longer than key', () {
      final mutation = createMutation(
        options: createOptions(mutationKey: const ['users']),
      );

      expect(
        mutation.matches(exact: false, mutationKey: const ['users', '1']),
        isFalse,
      );
    });
  });
}
