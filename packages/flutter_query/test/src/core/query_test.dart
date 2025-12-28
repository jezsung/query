import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_query/flutter_query.dart';

void main() {
  late QueryClient client;

  setUp(() {
    client = QueryClient();
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

  group('fetch', () {
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
}
