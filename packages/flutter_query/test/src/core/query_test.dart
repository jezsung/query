import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_query/src/core/core.dart';

void main() {
  late QueryClient client;

  setUp(() {
    client = QueryClient(
      defaultQueryOptions: DefaultQueryOptions(
        gcDuration: GcDuration.infinity,
        retry: (_, __) => null,
      ),
    );
  });

  tearDown(() {
    client.dispose();
  });

  void Function() withFakeAsync(void Function(FakeAsync fakeTime) testBody) {
    return () => fakeAsync(testBody);
  }

  Query<String, Object> createQuery({
    List<Object?> queryKey = const ['test'],
  }) {
    return Query<String, Object>(
      client,
      QueryOptions(
        queryKey,
        (context) async => 'data',
      ),
    );
  }

  group('defaultQueryOptions', () {
    test(
        'SHOULD use gcDuration from defaultQueryOptions '
        'WHEN query does not specify', () {
      final testClient = QueryClient(
        defaultQueryOptions: const DefaultQueryOptions(
          gcDuration: GcDuration(minutes: 10),
        ),
      );
      addTearDown(testClient.dispose);

      final query = Query<String, Object>(
        testClient,
        QueryOptions(
          const ['key'],
          (context) async => 'data',
        ),
      );

      expect(query.gcDuration, const GcDuration(minutes: 10));
    });

    test(
        'SHOULD prefer query gcDuration over defaultQueryOptions'
        '', () {
      final testClient = QueryClient(
        defaultQueryOptions: const DefaultQueryOptions(
          gcDuration: GcDuration(minutes: 10),
        ),
      );
      addTearDown(testClient.dispose);

      final query = Query<String, Object>(
        testClient,
        QueryOptions(
          const ['key'],
          (context) async => 'data',
          gcDuration: const GcDuration(minutes: 2),
        ),
      );

      expect(query.gcDuration, const GcDuration(minutes: 2));
    });

    test(
        'SHOULD use retry from defaultQueryOptions '
        'WHEN query does not specify', withFakeAsync((async) {
      final testClient = QueryClient(
        defaultQueryOptions: DefaultQueryOptions(
          retry: (count, error) =>
              count < 2 ? const Duration(milliseconds: 100) : null,
        ),
      );
      addTearDown(testClient.dispose);

      var attempts = 0;

      final query = Query<String, Object>(
        testClient,
        QueryOptions(
          const ['key'],
          (context) async {
            attempts++;
            throw Exception();
          },
        ),
      );

      query.fetch().ignore();

      async.flushMicrotasks();
      expect(attempts, 1);
      async.elapse(const Duration(milliseconds: 100));
      expect(attempts, 2);
      async.elapse(const Duration(milliseconds: 100));
      expect(attempts, 3);
    }));

    test(
        'SHOULD prefer query retry over defaultQueryOptions'
        '', withFakeAsync((async) {
      final testClient = QueryClient(
        defaultQueryOptions: DefaultQueryOptions(
          retry: (count, error) =>
              count < 5 ? const Duration(milliseconds: 100) : null,
        ),
      );
      addTearDown(testClient.dispose);

      var attempts = 0;

      final query = Query<String, Object>(
        testClient,
        QueryOptions(
          const ['key'],
          (context) async {
            attempts++;
            throw Exception();
          },
          retry: (_, __) => null, // No retries
        ),
      );

      query.fetch().ignore();

      async.flushMicrotasks();
      expect(attempts, 1);

      // Should NOT retry
      async.elapse(const Duration(hours: 24));
      expect(attempts, 1);
    }));
  });

  group('fetch', () {
    test(
        'SHOULD succeed and return data'
        '', withFakeAsync((async) {
      Object expectedData = Object();
      Object? capturedData;
      final query = Query<Object, Object>(
        client,
        QueryOptions(
          const ['key'],
          (context) async {
            await Future.delayed(const Duration(seconds: 3));
            return expectedData;
          },
        ),
      );

      query.fetch().then((data) => capturedData = data);

      expect(query.state.status, QueryStatus.pending);
      expect(query.state.fetchStatus, FetchStatus.fetching);
      expect(query.state.data, isNull);
      expect(query.state.dataUpdatedAt, isNull);
      expect(query.state.dataUpdateCount, 0);
      expect(capturedData, isNull);

      async.elapse(const Duration(seconds: 3));

      expect(query.state.status, QueryStatus.success);
      expect(query.state.fetchStatus, FetchStatus.idle);
      expect(query.state.data, same(expectedData));
      expect(query.state.dataUpdatedAt, clock.now());
      expect(query.state.dataUpdateCount, 1);
      expect(capturedData, same(expectedData));
    }));

    test(
        'SHOULD fail and throw error'
        '', withFakeAsync((async) {
      Object expectedError = Exception();
      Object? capturedError;

      final query = Query<String, Object>(
        client,
        QueryOptions(
          const ['key'],
          (context) async {
            await Future.delayed(const Duration(seconds: 3));
            throw expectedError;
          },
        ),
      );

      query.fetch().catchError((error) {
        capturedError = error;
        return 'error';
      });

      expect(query.state.status, QueryStatus.pending);
      expect(query.state.fetchStatus, FetchStatus.fetching);
      expect(query.state.error, isNull);
      expect(query.state.errorUpdatedAt, isNull);
      expect(query.state.errorUpdateCount, 0);
      expect(capturedError, isNull);

      async.elapse(const Duration(seconds: 3));

      expect(query.state.status, QueryStatus.error);
      expect(query.state.fetchStatus, FetchStatus.idle);
      expect(query.state.error, same(expectedError));
      expect(query.state.errorUpdatedAt, clock.now());
      expect(query.state.errorUpdateCount, 1);
      expect(capturedError, same(expectedError));
    }));

    test(
        'SHOULD reset isInvalidated to false on success'
        '', withFakeAsync((async) {
      final query = Query<String, Object>(
        client,
        QueryOptions(
          const ['key'],
          (context) async {
            await Future.delayed(const Duration(seconds: 3));
            return 'data';
          },
        ),
      );

      query.invalidate();
      expect(query.state.isInvalidated, isTrue);

      query.fetch();
      async.elapse(const Duration(seconds: 3));

      expect(query.state.isInvalidated, isFalse);
    }));

    test(
        'SHOULD increment failureCount on each failed attempt'
        '', withFakeAsync((async) {
      final query = Query<String, Object>(
        client,
        QueryOptions(
          const ['key'],
          (context) async {
            throw Exception();
          },
          retry: (count, error) =>
              count < 2 ? const Duration(milliseconds: 100) : null,
        ),
      );

      query.fetch().ignore();

      async.flushMicrotasks();
      expect(query.state.failureCount, 1);

      async.elapse(const Duration(milliseconds: 100));
      expect(query.state.failureCount, 2);
      async.elapse(const Duration(milliseconds: 100));
      expect(query.state.failureCount, 3);
    }));

    test(
        'SHOULD update failureReason on each failed attempt'
        '', withFakeAsync((async) {
      var attempts = 0;
      final query = Query<Never, String>(
        client,
        QueryOptions(
          const ['key'],
          (context) async {
            attempts++;
            throw 'error-$attempts';
          },
          retry: (count, error) =>
              count < 2 ? const Duration(milliseconds: 100) : null,
        ),
      );

      query.fetch().ignore();

      async.flushMicrotasks();
      expect(query.state.failureReason, 'error-1');

      async.elapse(const Duration(milliseconds: 100));
      expect(query.state.failureReason, 'error-2');
      async.elapse(const Duration(milliseconds: 100));
      expect(query.state.failureReason, 'error-3');
    }));

    test(
        'SHOULD reset failureCount to 0 on each fetch attempt'
        '', withFakeAsync((async) {
      var shouldFail = true;
      final query = Query<String, Object>(
        client,
        QueryOptions(
          const ['key'],
          (context) async {
            if (shouldFail) throw Exception();
            return 'data';
          },
          retry: (count, error) =>
              count < 1 ? const Duration(milliseconds: 100) : null,
        ),
      );

      query.fetch().ignore();

      async.flushMicrotasks();
      async.elapse(const Duration(milliseconds: 100));
      expect(query.state.failureCount, 2);

      shouldFail = false;
      query.fetch();

      expect(query.state.failureCount, 0);
    }));

    test(
        'SHOULD pass in correct QueryFunctionContext to queryFn'
        '', withFakeAsync((async) {
      QueryFunctionContext? capturedContext;

      final query = Query<String, Object>(
        client,
        QueryOptions(
          const ['users', 123],
          (context) async {
            capturedContext = context;
            return 'data';
          },
        ),
      );

      query.fetch();

      expect(capturedContext, isNotNull);
      expect(capturedContext!.queryKey, const ['users', 123]);
      expect(capturedContext!.client, same(client));
      expect(capturedContext!.signal, isA<AbortSignal>());
    }));

    test(
        'SHOULD retry with custom delay'
        '', withFakeAsync((async) {
      int attempts = 0;
      List<DateTime> attemptedAt = [];
      final query = Query<String, Object>(
        client,
        QueryOptions(
          const ['key'],
          (context) async {
            attempts++;
            attemptedAt.add(clock.now());
            throw Exception();
          },
          retry: (count, error) =>
              count < 3 ? Duration(seconds: (2 * count) + 1) : null,
        ),
      );

      query.fetch().ignore();

      async.flushMicrotasks();
      expect(attempts, 1);
      async.elapse(const Duration(seconds: 1));
      expect(attempts, 2);
      async.elapse(const Duration(seconds: 3));
      expect(attempts, 3);
      async.elapse(const Duration(seconds: 5));
      expect(attempts, 4);

      expect(
        attemptedAt[1].difference(attemptedAt[0]),
        const Duration(seconds: 1),
      );
      expect(
        attemptedAt[2].difference(attemptedAt[1]),
        const Duration(seconds: 3),
      );
      expect(
        attemptedAt[3].difference(attemptedAt[2]),
        const Duration(seconds: 5),
      );
    }));

    test(
        'SHOULD retry based on error type '
        '', withFakeAsync((async) {
      int attempts = 0;
      final query = Query<String, Object>(
        client,
        QueryOptions(
          const ['key'],
          (context) async {
            attempts++;
            if (attempts < 3) {
              throw Exception();
            }
            throw Error();
          },
          retry: (count, error) {
            if (error is Exception) {
              return const Duration(milliseconds: 100);
            }
            return null;
          },
        ),
      );

      query.fetch().ignore();

      async.flushMicrotasks();
      expect(attempts, 1);

      async.elapse(const Duration(milliseconds: 100));
      expect(attempts, 2);
      async.elapse(const Duration(milliseconds: 100));
      expect(attempts, 3);

      // Third attempt throws StateError - should NOT retry
      async.elapse(const Duration(milliseconds: 100));
      expect(attempts, 3);
    }));

    test(
        'SHOULD start with seed data'
        '', withFakeAsync((async) {
      Object expectedSeed = Object();
      final query1 = Query<Object, Object>(
        client,
        QueryOptions(
          const ['key'],
          (context) async => Object(),
          seed: expectedSeed,
        ),
      );

      expect(query1.state.status, QueryStatus.success);
      expect(query1.state.data, same(expectedSeed));
      // Should default to current time when seedUpdatedAt is not provided
      expect(query1.state.dataUpdatedAt, clock.now());

      final query2 = Query<Object, Object>(
        client,
        QueryOptions(
          const ['key'],
          (context) async => Object(),
          seed: expectedSeed,
          seedUpdatedAt: clock.minutesAgo(15),
        ),
      );

      expect(query2.state.status, QueryStatus.success);
      expect(query2.state.data, same(expectedSeed));
      // Should respect provided seedUpdatedAt
      expect(query2.state.dataUpdatedAt, clock.minutesAgo(15));
    }));

    test(
        'SHOULD return same Future (deduplication) '
        'WHEN cancelRefetch == false', withFakeAsync((async) {
      var calls = 0;

      final query = Query<String, Object>(
        client,
        QueryOptions(
          const ['key'],
          (context) async {
            calls++;
            await Future.any([
              Future.delayed(const Duration(seconds: 1)),
              context.signal.whenAbort,
            ]);
            context.signal.throwIfAborted();
            return 'data-$calls';
          },
        ),
      );

      // Establish initial data so cancelRefetch can work
      query.fetch();
      async.elapse(const Duration(seconds: 1));
      expect(calls, 1);
      expect(query.state.data, 'data-1');

      String? result1;
      String? result2;

      query.fetch().then((d) => result1 = d);
      query.fetch(cancelRefetch: false).then((d) => result2 = d);
      async.elapse(const Duration(seconds: 1));

      // Only ONE additional call (deduplication - same fetch shared)
      expect(calls, 2);
      expect(result1, 'data-2');
      expect(result2, 'data-2');
    }));

    test(
        'SHOULD piggyback cancelled fetch Future onto new fetch result '
        'WHEN cancelRefetch == true', withFakeAsync((async) {
      var calls = 0;

      final query = Query<String, Object>(
        client,
        QueryOptions(
          const ['key'],
          (context) async {
            calls++;
            await Future.any([
              Future.delayed(const Duration(seconds: 1)),
              context.signal.whenAbort,
            ]);
            context.signal.throwIfAborted();
            return 'data-$calls';
          },
        ),
      );

      // Establish initial data so cancelRefetch can work
      query.fetch();
      async.elapse(const Duration(seconds: 1));
      expect(calls, 1);
      expect(query.state.data, 'data-1');

      String? result1;
      String? result2;

      query.fetch().then((d) => result1 = d);
      query.fetch(cancelRefetch: true).then((d) => result2 = d);
      async.elapse(const Duration(seconds: 1));

      // TWO additional invocations (A was started then cancelled, B completed)
      expect(calls, 3);
      // Both get result from fetch B (A was cancelled, result1 piggybacked onto B)
      expect(result1, 'data-3');
      expect(result2, 'data-3');
    }));
  });

  group('cancel', () {
    test(
        'SHOULD set fetchStatus to idle '
        'WHEN cancelled', withFakeAsync((async) {
      final query = Query<String, Object>(
        client,
        QueryOptions(
          const ['key'],
          (context) async {
            await Future.any([
              Future.delayed(const Duration(seconds: 1)),
              context.signal.whenAbort,
            ]);
            context.signal.throwIfAborted();
            return 'data';
          },
        ),
      );

      query.fetch().ignore();

      expect(query.state.fetchStatus, FetchStatus.fetching);

      query.cancel();
      async.flushMicrotasks();

      expect(query.state.fetchStatus, FetchStatus.idle);
    }));

    test(
        'SHOULD revert to previous state '
        'WHEN revert == true', withFakeAsync((async) {
      final query = Query<String, Object>(
        client,
        QueryOptions(
          const ['key'],
          (context) async {
            await Future.any([
              Future.delayed(const Duration(seconds: 1)),
              context.signal.whenAbort,
            ]);
            context.signal.throwIfAborted();
            throw Exception();
          },
          retry: (count, error) => const Duration(milliseconds: 100),
        ),
      );

      // Start fetch that will fail and retry
      query.fetch().ignore();

      // Let it fail once and start retrying
      async.elapse(const Duration(seconds: 1));
      expect(query.state.failureCount, 1);
      expect(query.state.failureReason, isA<Exception>());

      // Cancel with revert: true
      query.cancel(revert: true);
      async.flushMicrotasks();

      // Should revert to initial state (before fetch started)
      expect(query.state.fetchStatus, FetchStatus.idle);
      expect(query.state.failureCount, 0);
      expect(query.state.failureReason, isNull);
    }));

    test(
        'SHOULD preserve current state '
        'WHEN revert == false', withFakeAsync((async) {
      final query = Query<String, Object>(
        client,
        QueryOptions(
          const ['key'],
          (context) async {
            await Future.any([
              Future.delayed(const Duration(seconds: 1)),
              context.signal.whenAbort,
            ]);
            context.signal.throwIfAborted();
            throw Exception();
          },
          retry: (count, error) => const Duration(milliseconds: 100),
        ),
      );

      // Start fetch that will fail and retry
      query.fetch().ignore();

      // Let it fail once and start retrying
      async.elapse(const Duration(seconds: 1));
      expect(query.state.failureCount, 1);
      expect(query.state.failureReason, isA<Exception>());

      // Cancel with revert: false
      query.cancel(revert: false);
      async.flushMicrotasks();

      // Should preserve current state (keep failureCount and failureReason)
      expect(query.state.fetchStatus, FetchStatus.idle);
      expect(query.state.failureCount, 1);
      expect(query.state.failureReason, isA<Exception>());
    }));

    test(
        'SHOULD throw AbortedException from fetch '
        'WHEN revert == true AND no prior data', withFakeAsync((async) {
      Object? capturedFetchError;
      Object? capturedCancelError;

      final query = Query<String, Object>(
        client,
        QueryOptions(
          const ['key'],
          (context) async {
            await Future.any([
              Future.delayed(const Duration(seconds: 1)),
              context.signal.whenAbort,
            ]);
            context.signal.throwIfAborted();
            return 'data';
          },
        ),
      );

      query.fetch().catchError((e) {
        capturedFetchError = e;
        return 'error';
      });
      query.cancel(revert: true).catchError((e) {
        capturedCancelError = e;
      });
      async.flushMicrotasks();

      expect(capturedFetchError, isA<AbortedException>());
      expect(capturedCancelError, isNull);
    }));

    test(
        'SHOULD return prior data from fetch '
        'WHEN revert == true AND has prior data', withFakeAsync((async) {
      String? capturedData;

      final query = Query<String, Object>(
        client,
        QueryOptions(
          const ['key'],
          (context) async {
            await Future.any([
              Future.delayed(const Duration(seconds: 1)),
              context.signal.whenAbort,
            ]);
            context.signal.throwIfAborted();
            return 'data';
          },
        ),
      );

      // Establish initial data
      query.fetch();
      async.elapse(const Duration(seconds: 1));
      expect(query.state.data, 'data');

      // Start another fetch and cancel with revert
      query.fetch().then((data) => capturedData = data);
      query.cancel(revert: true);
      async.flushMicrotasks();

      expect(capturedData, 'data');
    }));

    test(
        'SHOULD NOT throw from fetch '
        'WHEN silent == true', withFakeAsync((async) {
      Object? capturedFetchError;
      Object? capturedCancelError;

      final query = Query<String, Object>(
        client,
        QueryOptions(
          const ['key'],
          (context) async {
            await Future.any([
              Future.delayed(const Duration(seconds: 1)),
              context.signal.whenAbort,
            ]);
            context.signal.throwIfAborted();
            return 'data';
          },
        ),
      );

      query.fetch().catchError((e) {
        capturedFetchError = e;
        return 'error';
      });
      query.cancel(silent: true).catchError((e) {
        capturedCancelError = e;
      });
      async.flushMicrotasks();

      expect(capturedFetchError, isNull);
      expect(capturedCancelError, isNull);
    }));

    test(
        'SHOULD throw AbortedException from fetch '
        'WHEN silent == false AND no prior data', withFakeAsync((async) {
      Object? capturedFetchError;
      Object? capturedCancelError;

      final query = Query<String, Object>(
        client,
        QueryOptions(
          const ['key'],
          (context) async {
            await Future.any([
              Future.delayed(const Duration(seconds: 1)),
              context.signal.whenAbort,
            ]);
            context.signal.throwIfAborted();
            return 'data';
          },
        ),
      );

      query.fetch().catchError((e) {
        capturedFetchError = e;
        return 'error';
      });
      query.cancel(silent: false).catchError((e) {
        capturedCancelError = e;
      });
      async.flushMicrotasks();

      expect(capturedFetchError, isA<AbortedException>());
      expect(capturedCancelError, isNull);
    }));

    test(
        'SHOULD return prior data from fetch '
        'WHEN silent == false AND has prior data', withFakeAsync((async) {
      String? capturedData;

      final query = Query<String, Object>(
        client,
        QueryOptions(
          const ['key'],
          (context) async {
            await Future.any([
              Future.delayed(const Duration(seconds: 1)),
              context.signal.whenAbort,
            ]);
            context.signal.throwIfAborted();
            return 'data';
          },
        ),
      );

      // Establish initial data
      query.fetch();
      async.elapse(const Duration(seconds: 1));
      expect(query.state.data, 'data');

      // Start another fetch and cancel
      query.fetch().then((data) => capturedData = data);
      query.cancel(silent: false);
      async.flushMicrotasks();

      // Should return the prior data instead of throwing
      expect(capturedData, 'data');
    }));

    test(
        'SHOULD complete immediately '
        'WHEN there is no fetch in progress', withFakeAsync((async) {
      var complete = false;

      final query = Query<String, Object>(
        client,
        QueryOptions(
          const ['key'],
          (context) async {
            await Future.any([
              Future.delayed(const Duration(seconds: 1)),
              context.signal.whenAbort,
            ]);
            context.signal.throwIfAborted();
            return 'data';
          },
        ),
      );

      query.cancel().then((_) => complete = true);
      async.flushMicrotasks();

      expect(complete, isTrue);
    }));

    test(
        'SHOULD complete immediately '
        'WHEN queryFn does not check abort signal', withFakeAsync((async) {
      var cancelCompleted = false;

      final query = Query<String, Object>(
        client,
        QueryOptions(
          const ['key'],
          // This queryFn does NOT check the abort signal
          (context) async {
            await Future.delayed(const Duration(seconds: 3));
            return 'data';
          },
        ),
      );

      query.fetch().ignore();
      query.cancel().then((_) => cancelCompleted = true);
      async.flushMicrotasks();

      // cancel() completes immediately by settling the promise,
      // even though the underlying queryFn might still be running
      expect(cancelCompleted, isTrue);
    }));

    test(
        'SHOULD cancel immediately '
        'WHEN retryer is waiting for retry delay', withFakeAsync((async) {
      var cancelCompleted = false;

      final query = Query<String, Object>(
        client,
        QueryOptions(
          const ['key'],
          (context) async {
            context.signal.throwIfAborted();
            throw Exception();
          },
          // Long retry delay to ensure cancel interrupts it
          retry: (count, error) => const Duration(seconds: 10),
        ),
      );

      query.fetch().ignore();
      async.flushMicrotasks();

      // Query should have failed once and be waiting for retry delay
      expect(query.state.failureCount, 1);
      expect(query.state.fetchStatus, FetchStatus.fetching);

      // Cancel while waiting for retry delay
      query.cancel().then((_) => cancelCompleted = true);
      async.flushMicrotasks();

      // Cancel should complete immediately without waiting for the 10s delay
      expect(cancelCompleted, isTrue);
      expect(query.state.fetchStatus, FetchStatus.idle);
    }));
  });

  group('QueryMatches.matches', () {
    test(
        'SHOULD match exact key '
        'WHEN exact == true AND key matches', () {
      final query = createQuery(queryKey: const ['users', '1']);

      expect(
        query.matches(const ['users', '1'], exact: true),
        isTrue,
      );
    });

    test(
        'SHOULD NOT match '
        'WHEN exact == true AND key differs', () {
      final query = createQuery(queryKey: const ['users', '1']);

      expect(
        query.matches(const ['users', '2'], exact: true),
        isFalse,
      );
    });

    test('SHOULD match partial key', () {
      final query = createQuery(queryKey: const ['users', '1', 'profile']);

      expect(
        query.matches(const ['users', '1']),
        isTrue,
      );
    });

    test(
        'SHOULD NOT match partial key '
        'WHEN filter is longer than key', () {
      final query = createQuery(queryKey: const ['users']);

      expect(
        query.matches(const ['users', '1']),
        isFalse,
      );
    });
  });

  group('QueryMatches.matchesWhere', () {
    test('SHOULD match predicate', () {
      final query = createQuery(queryKey: const ['users']);

      expect(
        query.matchesWhere((q) => q.key[0] == 'users'),
        isTrue,
      );
    });

    test('SHOULD NOT match predicate', () {
      final query = createQuery(queryKey: const ['posts']);

      expect(
        query.matchesWhere((q) => q.key[0] == 'users'),
        isFalse,
      );
    });
  });

  group('QueryMatches combined', () {
    test('SHOULD require ALL filters to match (AND logic)', () {
      final query = createQuery(queryKey: const ['users', '1']);

      // All match
      expect(
        query.matches(const ['users']) && query.matchesWhere((q) => true),
        isTrue,
      );

      // One doesn't match (predicate fails)
      expect(
        query.matches(const ['users']) && query.matchesWhere((q) => false),
        isFalse,
      );
    });
  });

  group('meta', () {
    test(
        'SHOULD return meta from options'
        '', () {
      final expectedMeta = {'source': 'test', 'priority': 1};
      final query = Query<String, Object>(
        client,
        QueryOptions(
          const ['key'],
          (context) async => 'data',
          meta: expectedMeta,
        ),
      );

      expect(query.meta, expectedMeta);
      expect(query.meta['source'], 'test');
      expect(query.meta['priority'], 1);
    });

    test(
        'SHOULD return empty map '
        'WHEN meta is not provided', () {
      final query = Query<String, Object>(
        client,
        QueryOptions(
          const ['key'],
          (context) async => 'data',
        ),
      );

      expect(query.meta, isEmpty);
    });

    test(
        'SHOULD pass meta to queryFn via QueryFunctionContext'
        '', withFakeAsync((async) {
      final expectedMeta = {'source': 'api', 'version': 2};
      QueryFunctionContext? capturedContext;

      final query = Query<String, Object>(
        client,
        QueryOptions(
          const ['users', 123],
          (context) async {
            capturedContext = context;
            return 'data';
          },
          meta: expectedMeta,
        ),
      );

      query.fetch();
      async.flushMicrotasks();

      expect(capturedContext, isNotNull);
      expect(capturedContext!.meta, expectedMeta);
    }));

    test(
        'SHOULD pass empty meta to queryFn '
        'WHEN meta is not provided', withFakeAsync((async) {
      QueryFunctionContext? capturedContext;

      final query = Query<String, Object>(
        client,
        QueryOptions(
          const ['key'],
          (context) async {
            capturedContext = context;
            return 'data';
          },
        ),
      );

      query.fetch();
      async.flushMicrotasks();

      expect(capturedContext, isNotNull);
      expect(capturedContext!.meta, isEmpty);
    }));

    test(
        'SHOULD dynamically merge meta from multiple observers'
        '', () {
      final query = Query<String, Object>(
        client,
        QueryOptions(
          const ['key'],
          (context) async => 'data',
          meta: {'base': 'value'},
        ),
      );
      addTearDown(query.dispose);
      expect(query.meta, {'base': 'value'});

      final observer1 = QueryObserver<String, Object>(
        client,
        QueryObserverOptions(
          const ['key'],
          (context) async => 'data',
          meta: {'observer': '1', 'extra-1': 'value-1'},
        ),
      );
      addTearDown(observer1.dispose);
      query.addObserver(observer1);
      expect(query.meta, {
        'base': 'value',
        'observer': '1',
        'extra-1': 'value-1',
      });

      final observer2 = QueryObserver<String, Object>(
        client,
        QueryObserverOptions(
          const ['key'],
          (context) async => 'data',
          meta: {'observer': '2', 'extra-2': 'value-2'},
        ),
      );
      addTearDown(observer2.dispose);
      query.addObserver(observer2);
      expect(query.meta, {
        'base': 'value',
        'observer': '2',
        'extra-1': 'value-1',
        'extra-2': 'value-2',
      });

      query.removeObserver(observer2);
      expect(query.meta, {
        'base': 'value',
        'observer': '1',
        'extra-1': 'value-1',
      });

      query.removeObserver(observer1);
      expect(query.meta, {'base': 'value'});
    });

    test(
        'SHOULD deeply merge meta '
        'WHEN withOptions is called', () {
      final query = Query<String, Object>(
        client,
        QueryOptions(
          const ['key'],
          (context) async => 'data',
          meta: {
            'source': 'A',
            'nested': {'a': 1, 'b': 2}
          },
        ),
      );

      query.withOptions(
        QueryOptions(
          const ['key'],
          (context) async => 'data',
          meta: {
            'feature': 'B',
            'nested': {'b': 3, 'c': 4}
          },
        ),
      );

      expect(query.meta, {
        'source': 'A',
        'feature': 'B',
        'nested': {'a': 1, 'b': 3, 'c': 4},
      });
    });

    test(
        'SHOULD preserve existing meta '
        'WHEN new options have null meta', () {
      final query = Query<String, Object>(
        client,
        QueryOptions(
          const ['key'],
          (context) async => 'data',
          meta: {'preserved': 'value'},
        ),
      );

      query.withOptions(
        QueryOptions(
          const ['key'],
          (context) async => 'data',
        ),
      );

      expect(query.meta, {'preserved': 'value'});
    });

    test(
        'SHOULD use new meta '
        'WHEN existing meta is null', () {
      final query = Query<String, Object>(
        client,
        QueryOptions(
          const ['key'],
          (context) async => 'data',
        ),
      );

      query.withOptions(
        QueryOptions(
          const ['key'],
          (context) async => 'data',
          meta: {'new': 'value'},
        ),
      );

      expect(query.meta, {'new': 'value'});
    });
  });
}
