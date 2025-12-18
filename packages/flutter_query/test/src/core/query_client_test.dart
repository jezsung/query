import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart' hide Retry;

import 'package:flutter_query/flutter_query.dart';

/// A test helper that wraps a test body in [fakeAsync] for time manipulation.
///
/// This allows you to control time in tests using [FakeAsync.elapse] and
/// [FakeAsync.flushMicrotasks].
///
/// Usage:
/// ```dart
/// test('my test', withFakeAsync((fakeTime) {
///   // Start an async operation
///   myFuture.then((_) {}, onError: (e) { ... });
///
///   // Advance time
///   fakeTime.elapse(const Duration(seconds: 5));
///
///   // Assert
///   expect(...);
/// }));
/// ```
///
/// Note: The test body must be synchronous. Use `.then()` and `.catchError()`
/// to handle async results within the fakeAsync zone.
void Function() withFakeAsync(void Function(FakeAsync fakeTime) testBody) {
  return () => fakeAsync(testBody);
}

void main() {
  late QueryClient client;

  setUp(() {
    client = QueryClient();
  });

  tearDown(() {
    client.dispose();
  });

  group('fetchQuery', () {
    test('SHOULD fetch and return data WHEN query does not exist', () async {
      final data = await client.fetchQuery<String, Object>(
        queryKey: const ['key'],
        queryFn: (context) async => 'fetched data',
      );

      expect(data, equals('fetched data'));
    });

    test('SHOULD return cached data WHEN data is fresh', () async {
      // First fetch
      await client.fetchQuery<String, Object>(
        queryKey: const ['key'],
        queryFn: (context) async => 'first',
        staleDuration: StaleDuration.infinity(),
      );

      // Second fetch with different queryFn - should return cached
      final data = await client.fetchQuery<String, Object>(
        queryKey: const ['key'],
        queryFn: (context) async => 'second',
        staleDuration: StaleDuration.infinity(),
      );

      expect(data, equals('first'));
    });

    test('SHOULD refetch WHEN data is stale', () async {
      // Setup with staleTime = 0 (immediately stale)
      var calls = 0;
      var data = '';

      data = await client.fetchQuery<String, Object>(
        queryKey: const ['key'],
        queryFn: (context) async => 'data-${++calls}',
        staleDuration: StaleDuration.zero(),
      );
      expect(data, equals('data-1'));

      data = await client.fetchQuery<String, Object>(
        queryKey: const ['key'],
        queryFn: (context) async => 'data-${++calls}',
        staleDuration: StaleDuration.zero(),
      );
      expect(data, equals('data-2'));
    });

    test('SHOULD throw WHEN fetch fails', () async {
      final error = Exception('error');

      try {
        await client.fetchQuery<String, Exception>(
          queryKey: const ['key'],
          queryFn: (context) async => throw error,
        );
      } catch (e) {
        expect(e, same(error));
      }
    });

    test('SHOULD not retry by default', withFakeAsync((async) {
      var attempts = 0;
      Object? caughtError;

      client.fetchQuery<String, Exception>(
        queryKey: const ['key'],
        queryFn: (context) async {
          attempts++;
          await Future.delayed(const Duration(seconds: 3));
          throw Exception('error');
        },
      ).then((_) {}, onError: (e) {
        caughtError = e;
      });

      async.elapse(const Duration(seconds: 3));

      expect(caughtError, isA<Exception>());
      expect(attempts, equals(1));

      // Wait long enough
      async.elapse(const Duration(hours: 24));
      // Should NOT have retried
      expect(attempts, equals(1));
    }));

    test('SHOULD return same future WHEN fetch already in progress', () async {
      final completer = Completer<String>();

      final future1 = client.fetchQuery<String, Object>(
        queryKey: const ['key'],
        queryFn: (context) => completer.future,
      );
      final future2 = client.fetchQuery<String, Object>(
        queryKey: const ['key'],
        queryFn: (context) async => 'data-2',
      );

      // Both should be waiting for the same fetch
      completer.complete('data-1');

      final (result1, result2) = (await future1, await future2);

      expect(result1, equals('data-1'));
      expect(result2, equals('data-1'));
    });

    test('SHOULD retry WHEN retry option is provided', withFakeAsync((async) {
      int attempts = 0;

      client.fetchQuery<String, Exception>(
        queryKey: const ['key'],
        queryFn: (context) async {
          attempts++;
          await Future.delayed(const Duration(seconds: 3));
          throw Exception('error');
        },
        retry: Retry.count(3),
        retryDelay: const RetryDelay(seconds: 1),
      ).ignore();

      // Initial attempt
      async.elapse(const Duration(seconds: 3));
      expect(attempts, 1);

      // Retry for 3 times with 1s delay
      async.elapse(const Duration(seconds: 1 + 3));
      expect(attempts, 2);
      async.elapse(const Duration(seconds: 1 + 3));
      expect(attempts, 3);
      async.elapse(const Duration(seconds: 1 + 3));
      expect(attempts, 4);
    }));

    test('SHOULD store data in cache after fetch', () async {
      await client.fetchQuery<String, Object>(
        queryKey: const ['key'],
        queryFn: (context) async => 'cached data',
      );

      final query = client.cache.get<String, Object>(const ['key']);
      expect(query, isNotNull);
      expect(query!.state.data, equals('cached data'));
    });

    test('SHOULD use fresh data with infinity staleDuration', () async {
      int callCount = 0;

      // First fetch
      await client.fetchQuery<String, Object>(
        queryKey: const ['key'],
        queryFn: (_) async => 'data-${++callCount}',
        staleDuration: StaleDuration.infinity(),
      );

      // Multiple subsequent fetches should all return cached data
      for (int i = 0; i < 5; i++) {
        final data = await client.fetchQuery<String, Object>(
          queryKey: const ['key'],
          queryFn: (_) async => 'data-${++callCount}',
          staleDuration: StaleDuration.infinity(),
        );
        expect(data, equals('data-1'));
      }

      expect(callCount, equals(1)); // Only called once
    });

    test('SHOULD pass QueryContext with queryKey and client to queryFn',
        () async {
      QueryContext? receivedContext;

      await client.fetchQuery<String, Object>(
        queryKey: const ['users', 123],
        queryFn: (context) async {
          receivedContext = context;
          return 'data';
        },
      );

      expect(receivedContext, isNotNull);
      expect(receivedContext!.queryKey, equals(const ['users', 123]));
      expect(receivedContext!.client, same(client));
    });

    group('initialData', () {
      test(
          'SHOULD NOT fetch and return initialData '
          'WHEN data is fresh', () async {
        var attempts = 0;

        final data = await client.fetchQuery<String, Object>(
          queryKey: const ['key'],
          queryFn: (context) async {
            attempts++;
            return 'data';
          },
          initialData: 'initial',
          staleDuration: StaleDuration.infinity(),
        );

        expect(data, 'initial');
        expect(attempts, 0);
      });

      test(
          'SHOULD fetch and return fetched data '
          'WHEN initialData is stale', () async {
        var attempts = 0;

        final data = await client.fetchQuery<String, Object>(
          queryKey: const ['key'],
          queryFn: (context) async {
            attempts++;
            return 'data';
          },
          initialData: 'initial',
          staleDuration: StaleDuration.zero(),
        );

        expect(data, 'data');
        expect(attempts, 1);
      });

      test(
          'SHOULD NOT fetch and return initialData '
          'WHEN initialDataUpdatedAt is recent and staleDuration > 0',
          () async {
        var attempts = 0;

        final data = await client.fetchQuery<String, Object>(
          queryKey: const ['key'],
          queryFn: (context) async {
            attempts++;
            return 'data';
          },
          initialData: 'initial',
          initialDataUpdatedAt: DateTime.now(),
          staleDuration: const StaleDuration(minutes: 5),
        );

        expect(data, 'initial');
        expect(attempts, 0);
      });

      test(
          'SHOULD fetch and return fetched data'
          'WHEN initialDataUpdatedAt indicates stale data', () async {
        var attempts = 0;

        final data = await client.fetchQuery<String, Object>(
          queryKey: const ['key'],
          queryFn: (context) async {
            attempts++;
            return 'data';
          },
          initialData: 'initial',
          initialDataUpdatedAt:
              DateTime.now().subtract(const Duration(minutes: 10)),
          staleDuration: const StaleDuration(minutes: 5),
        );

        expect(data, 'data');
        expect(attempts, 1);
      });

      test(
          'SHOULD populate cache with initialData'
          '', () async {
        await client.fetchQuery<String, Object>(
          queryKey: const ['key'],
          queryFn: (context) async => 'data',
          initialData: 'initial',
          staleDuration: StaleDuration.infinity(),
        );

        final query = client.cache.get<String, Object>(const ['key']);
        expect(query, isNotNull);
        expect(query!.state.data, 'initial');
      });
    });
  });

  group('prefetchQuery', () {
    test(
        'SHOULD NOT throw '
        'WHEN fetch fails', () async {
      // This should complete without throwing
      await client.prefetchQuery<String, Exception>(
        queryKey: const ['key'],
        queryFn: (context) async => throw Exception('error'),
      );

      // Verify the query was created but has an error state
      final query = client.cache.get<String, Exception>(const ['key']);
      expect(query, isNotNull);
      expect(query!.state.error, isA<Exception>());
    });
  });

  group('getQueryData', () {
    test(
        'SHOULD return data '
        'WHEN query exists with data', () async {
      await client.fetchQuery<String, Object>(
        queryKey: const ['key'],
        queryFn: (context) async => 'data',
      );

      final data = client.getQueryData<String, Object>(const ['key']);

      expect(data, 'data');
    });

    test(
        'SHOULD return null '
        'WHEN query does not exist', () {
      final data = client.getQueryData<String, Object>(const ['key']);

      expect(data, isNull);
    });

    test(
        'SHOULD return null '
        'WHEN query exists but has no data yet', () {
      // Build a query without fetching (query exists but in pending state)
      client.cache.build<String, Object>(QueryOptions<String, Object>(
        const ['key'],
        (context) async => 'data',
      ));

      final data = client.getQueryData<String, Object>(const ['key']);

      expect(data, isNull);
    });

    test(
        'SHOULD use exact key matching'
        '', () async {
      await client.fetchQuery<String, Object>(
        queryKey: const ['users', '1'],
        queryFn: (context) async => 'data',
      );

      // Prefix key should not match
      var data = client.getQueryData<String, Object>(const ['users']);
      expect(data, isNull);

      // Exact key should match
      data = client.getQueryData<String, Object>(const ['users', '1']);
      expect(data, 'data');
    });
  });
}
