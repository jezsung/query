import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_query/src/core/core.dart';
import '../../utils.dart';

void main() {
  late QueryCache cache;
  late QueryClient client;

  setUp(() {
    cache = QueryCache();
    client = QueryClient(cache: cache);
  });

  tearDown(() {
    client.clear();
  });

  group('defaultQueryOptions', () {
    late QueryCache cache;
    late QueryClient client;

    setUp(() {
      cache = QueryCache();
      client = QueryClient(
        cache: cache,
        defaultQueryOptions: DefaultQueryOptions(
          gcDuration: GcDuration(minutes: 10),
          refetchOnMount: RefetchOnMount.never,
          staleDuration: StaleDuration.infinity,
        ),
      );
    });

    tearDown(() {
      client.clear();
    });

    test(
        'SHOULD use QueryClient.defaultQueryOptions '
        'WHEN calling QueryClient.fetchQuery', () async {
      var fetches = 0;

      await client.fetchQuery<String, Object>(
        queryKey: const ['key'],
        queryFn: (context) async {
          fetches++;
          return 'data-1';
        },
      );

      expect(fetches, 1);

      // Second call should use cached data (infinity stale time from defaults)
      await client.fetchQuery<String, Object>(
        queryKey: const ['key'],
        queryFn: (context) async {
          fetches++;
          return 'data-2';
        },
      );

      expect(fetches, 1); // Should not have fetched again
    });

    test(
        'SHOULD NOT use QueryClient.defaultQueryOptions '
        'WHEN query specifies option', () async {
      var fetches = 0;

      await client.fetchQuery(
        queryKey: const ['key'],
        queryFn: (context) async {
          fetches++;
          return 'data-1';
        },
        // Override with zero stale time
        staleDuration: StaleDuration.zero,
      );

      expect(fetches, 1);

      // Second call should refetch (zero stale time overrides default)
      await client.fetchQuery(
        queryKey: const ['key'],
        queryFn: (context) async {
          fetches++;
          return 'data-2';
        },
        staleDuration: StaleDuration.zero,
      );

      // Should have fetched again
      expect(fetches, 2);
    });

    test('SHOULD use QueryClient.defaultQueryOptions for gcDuration',
        withFakeAsync((async) {
      client.fetchQuery(
        queryKey: const ['key'],
        queryFn: (context) async => 'data',
      );

      // Check if query exists every 10s
      while (cache.get(const ['key']) != null) {
        async.elapse(const Duration(seconds: 10));
      }

      // Should have passed 10 mins when query is removed
      expect(async.elapsed, const Duration(minutes: 10));
    }));

    test(
        'SHOULD update defaultQueryOptions'
        '', () {
      // Initially set to StaleDuration.infinity
      expect(
        client.defaultQueryOptions.staleDuration,
        StaleDuration.infinity,
      );

      client.defaultQueryOptions = DefaultQueryOptions(
        staleDuration: StaleDuration.zero,
      );

      // Should have been set to StaleDuration.zero
      expect(
        client.defaultQueryOptions.staleDuration,
        StaleDuration.zero,
      );
    });
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
        staleDuration: StaleDuration.infinity,
      );

      // Second fetch with different queryFn - should return cached
      final data = await client.fetchQuery<String, Object>(
        queryKey: const ['key'],
        queryFn: (context) async => 'second',
        staleDuration: StaleDuration.infinity,
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
        staleDuration: StaleDuration.zero,
      );
      expect(data, equals('data-1'));

      data = await client.fetchQuery<String, Object>(
        queryKey: const ['key'],
        queryFn: (context) async => 'data-${++calls}',
        staleDuration: StaleDuration.zero,
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
        retry: (retryCount, error) {
          if (retryCount >= 3) return null;
          return const Duration(seconds: 1);
        },
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
        staleDuration: StaleDuration.infinity,
      );

      // Multiple subsequent fetches should all return cached data
      for (int i = 0; i < 5; i++) {
        final data = await client.fetchQuery<String, Object>(
          queryKey: const ['key'],
          queryFn: (_) async => 'data-${++callCount}',
          staleDuration: StaleDuration.infinity,
        );
        expect(data, equals('data-1'));
      }

      expect(callCount, equals(1)); // Only called once
    });

    test('SHOULD pass QueryFunctionContext with queryKey and client to queryFn',
        () async {
      QueryFunctionContext? receivedContext;

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

    group('seed', () {
      test(
          'SHOULD NOT fetch and return seed '
          'WHEN data is fresh', () async {
        var attempts = 0;

        final data = await client.fetchQuery<String, Object>(
          queryKey: const ['key'],
          queryFn: (context) async {
            attempts++;
            return 'data';
          },
          seed: 'initial',
          staleDuration: StaleDuration.infinity,
        );

        expect(data, 'initial');
        expect(attempts, 0);
      });

      test(
          'SHOULD fetch and return fetched data '
          'WHEN seed is stale', () async {
        var attempts = 0;

        final data = await client.fetchQuery<String, Object>(
          queryKey: const ['key'],
          queryFn: (context) async {
            attempts++;
            return 'data';
          },
          seed: 'initial',
          staleDuration: StaleDuration.zero,
        );

        expect(data, 'data');
        expect(attempts, 1);
      });

      test(
          'SHOULD NOT fetch and return seed '
          'WHEN seedUpdatedAt is recent and staleDuration > 0', () async {
        var attempts = 0;

        final data = await client.fetchQuery<String, Object>(
          queryKey: const ['key'],
          queryFn: (context) async {
            attempts++;
            return 'data';
          },
          seed: 'initial',
          seedUpdatedAt: DateTime.now(),
          staleDuration: const StaleDuration(minutes: 5),
        );

        expect(data, 'initial');
        expect(attempts, 0);
      });

      test(
          'SHOULD fetch and return fetched data'
          'WHEN seedUpdatedAt indicates stale data', () async {
        var attempts = 0;

        final data = await client.fetchQuery<String, Object>(
          queryKey: const ['key'],
          queryFn: (context) async {
            attempts++;
            return 'data';
          },
          seed: 'initial',
          seedUpdatedAt: DateTime.now().subtract(const Duration(minutes: 10)),
          staleDuration: const StaleDuration(minutes: 5),
        );

        expect(data, 'data');
        expect(attempts, 1);
      });

      test(
          'SHOULD populate cache with seed'
          '', () async {
        await client.fetchQuery<String, Object>(
          queryKey: const ['key'],
          queryFn: (context) async => 'data',
          seed: 'initial',
          staleDuration: StaleDuration.infinity,
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

  group('invalidateQueries', () {
    test(
        'SHOULD mark query as invalidated'
        '', () async {
      await client.fetchQuery(
        queryKey: const ['key'],
        queryFn: (context) async => 'data',
      );

      client.invalidateQueries(queryKey: const ['key']);

      final query = cache.get(const ['key']);
      expect(query!.state.isInvalidated, isTrue);
    });

    test(
        'SHOULD invalidate all matching queries by prefix'
        '', () async {
      await client.fetchQuery(
        queryKey: const ['users', '1'],
        queryFn: (context) async => 'user1',
      );
      await client.fetchQuery(
        queryKey: const ['users', '2'],
        queryFn: (context) async => 'user2',
      );
      await client.fetchQuery(
        queryKey: const ['posts'],
        queryFn: (context) async => 'posts',
      );

      client.invalidateQueries(queryKey: const ['users']);

      final user1 = cache.get(const ['users', '1']);
      final user2 = cache.get(const ['users', '2']);
      final posts = cache.get(const ['posts']);

      expect(user1!.state.isInvalidated, isTrue);
      expect(user2!.state.isInvalidated, isTrue);
      expect(posts!.state.isInvalidated, isFalse);
    });

    test(
        'SHOULD invalidate all queries '
        'WHEN no filters are provided', () async {
      final activeObserver1 = QueryObserver(
        client,
        QueryObserverOptions(
          const ['active', 1],
          (context) async => 'data',
          enabled: true,
        ),
      );
      final activeObserver2 = QueryObserver(
        client,
        QueryObserverOptions(
          const ['active', 2],
          (context) async => 'data',
          enabled: true,
        ),
      );
      await client.fetchQuery(
        queryKey: const ['inactive', 1],
        queryFn: (context) async => 'data',
      );
      await client.fetchQuery(
        queryKey: const ['inactive', 2],
        queryFn: (context) async => 'data',
      );
      final disabledObserver = QueryObserver(
        client,
        QueryObserverOptions(
          const ['disabled', 1],
          (context) async => 'data',
          enabled: false,
        ),
      );

      client.invalidateQueries();

      final query1 = client.cache.get(const ['active', 1]);
      final query2 = client.cache.get(const ['active', 2]);
      final query3 = client.cache.get(const ['inactive', 1]);
      final query4 = client.cache.get(const ['inactive', 2]);
      final query5 = client.cache.get(const ['disabled', 1]);

      expect(query1!.state.isInvalidated, isTrue);
      expect(query2!.state.isInvalidated, isTrue);
      expect(query3!.state.isInvalidated, isTrue);
      expect(query4!.state.isInvalidated, isTrue);
      expect(query5!.state.isInvalidated, isTrue);

      activeObserver1.onUnmount();
      activeObserver2.onUnmount();
      disabledObserver.onUnmount();
    });
  });

  group('refetchQueries', () {
    test(
        'SHOULD refetch queries'
        'WHEN queryKey matches', withFakeAsync((async) {
      var fetches = 0;

      client.fetchQuery(
        queryKey: const ['key'],
        queryFn: (context) async {
          fetches++;
          await Future.delayed(const Duration(seconds: 1));
          return 'data';
        },
      );

      // Wait for initial fetch
      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);

      client.refetchQueries(queryKey: const ['key']);

      // Should have refetched
      async.elapse(const Duration(seconds: 1));
      expect(fetches, 2);
    }));

    test(
        'SHOULD NOT refetch disabled queries'
        '', withFakeAsync((async) {
      var fetches = 0;

      // Create a disabled observer
      final observer = QueryObserver(
        client,
        QueryObserverOptions(
          const ['key'],
          (context) async {
            fetches++;
            await Future.delayed(const Duration(seconds: 1));
            return 'data';
          },
          enabled: false,
        ),
      );
      addTearDown(observer.onUnmount);

      // No initial fetch because disabled
      async.elapse(const Duration(seconds: 1));
      expect(fetches, 0);

      client.refetchQueries(queryKey: const ['key']);

      // Should NOT have refetched because query is disabled
      async.elapse(const Duration(seconds: 1));
      expect(fetches, 0);
    }));

    test(
        'SHOULD NOT refetch static queries'
        '', withFakeAsync((async) {
      var fetches = 0;

      // Create an observer with static stale duration
      final observer = QueryObserver<String, Object>(
        client,
        QueryObserverOptions(
          const ['key'],
          (context) async {
            fetches++;
            await Future.delayed(const Duration(seconds: 1));
            return 'data';
          },
          enabled: true,
          staleDuration: StaleDuration.static,
        ),
      );
      observer.onMount();
      addTearDown(observer.onUnmount);

      // Wait for initial fetch
      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);

      client.refetchQueries(queryKey: const ['key']);

      // Should NOT have refetched because query is static
      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);
    }));
  });

  group('cancelQueries', () {
    /// Creates an abortable query function for testing.
    ///
    /// This simulates a real network request that respects the abort signal.
    /// It checks the signal every 100ms and throws [AbortedException] if aborted.
    ///
    /// The [fn] callback is invoked after the duration elapses. It can return
    /// a value or throw an error to test failure cases.
    Future<T> Function(QueryFunctionContext) abortableQueryFn<T>(
      Duration duration,
      T Function() fn,
    ) {
      return (context) async {
        // Race between delay and abort signal
        await Future.any([
          Future.delayed(duration),
          context.signal.whenAbort,
        ]);
        context.signal.throwIfAborted();
        return fn();
      };
    }

    test(
        'SHOULD cancel in-progress fetch'
        '', withFakeAsync((async) {
      // Use abortable query function that checks signal
      // Use ignore to prevent uncaught async error (expected to throw when cancelled with no prior data)
      client.fetchQuery(
        queryKey: const ['key'],
        queryFn: abortableQueryFn(
          const Duration(seconds: 3),
          () => 'data',
        ),
      ).ignore();

      // Should be fetching
      final query = cache.get(const ['key'])!;
      expect(query.state.fetchStatus, FetchStatus.fetching);

      // Cancel - elapse time so the signal check runs
      client.cancelQueries(queryKey: const ['key']);
      async.flushMicrotasks();

      // Should be idle after cancel
      expect(query.state.fetchStatus, FetchStatus.idle);
    }));

    test(
        'SHOULD complete immediately '
        'WHEN no fetch in progress', withFakeAsync((async) {
      client.fetchQuery(
        queryKey: const ['key'],
        queryFn: abortableQueryFn(
          const Duration(seconds: 3),
          () => 'data',
        ),
      );

      final query = cache.get(const ['key'])!;

      async.elapse(const Duration(seconds: 3));

      expect(query.state.fetchStatus, FetchStatus.idle);
      expect(query.state.data, 'data');

      // Should complete without error
      client.cancelQueries(queryKey: const ['key']);

      // State should be unchanged
      expect(query.state.fetchStatus, FetchStatus.idle);
      expect(query.state.data, 'data');
    }));

    test(
        'SHOULD cancel queries matching queryKey prefix'
        '', withFakeAsync((async) {
      // Use abortable query for the one we want to cancel
      client.fetchQuery(
        queryKey: const ['users', 1],
        queryFn: abortableQueryFn(
          const Duration(seconds: 10),
          () => 'data',
        ),
      ).ignore();
      // Use non-abortable (Completer) for the one that should keep fetching
      client.fetchQuery(
        queryKey: const ['posts', 1],
        queryFn: (context) => Completer<String>().future,
      );

      // Cancel only users queries
      client.cancelQueries(queryKey: const ['users']);
      async.flushMicrotasks();

      final usersQuery = cache.get(const ['users', 1])!;
      final postsQuery = cache.get(const ['posts', 1])!;

      // Users query should be cancelled (idle)
      expect(usersQuery.state.fetchStatus, FetchStatus.idle);
      // Posts query should still be fetching
      expect(postsQuery.state.fetchStatus, FetchStatus.fetching);
    }));

    test(
        'SHOULD ONLY cancel queries matching predicate'
        'WHEN predicate != null', withFakeAsync((async) {
      client.fetchQuery(
        queryKey: const ['query', 1],
        queryFn: abortableQueryFn(
          const Duration(seconds: 3),
          () => 'data',
        ),
      ).ignore();
      client.fetchQuery(
        queryKey: const ['query', 2],
        queryFn: (context) => Completer<String>().future,
      );

      // Cancel only query with key ending in 1
      client.cancelQueries(predicate: (q) => q.key.last == 1);
      async.flushMicrotasks();

      final query1 = cache.get(const ['query', 1])!;
      final query2 = cache.get(const ['query', 2])!;

      expect(query1.state.fetchStatus, FetchStatus.idle);
      expect(query2.state.fetchStatus, FetchStatus.fetching);
    }));

    test(
        'SHOULD ONLY cancel query matching exact query key '
        'WHEN exact == true', withFakeAsync((async) {
      client.fetchQuery(
        queryKey: const ['users', 1],
        queryFn: abortableQueryFn(
          const Duration(seconds: 3),
          () => 'data-1',
        ),
      ).ignore();
      client.fetchQuery(
        queryKey: const ['users', 2],
        queryFn: abortableQueryFn(
          const Duration(seconds: 3),
          () => 'data-2',
        ),
      );

      // Cancel with exact match - should only match ['users', 1]
      client.cancelQueries(queryKey: const ['users', 1], exact: true);
      async.flushMicrotasks();

      final queyr1 = cache.get(const ['users', 1])!;
      final query2 = cache.get(const ['users', 2])!;

      expect(queyr1.state.fetchStatus, FetchStatus.idle);
      expect(query2.state.fetchStatus, FetchStatus.fetching);
    }));

    test(
        'SHOULD cancel AND revert back to previous state '
        'WHEN revert == true', withFakeAsync((async) {
      // Fetch initial data
      client.fetchQuery<String, Object>(
        queryKey: const ['key'],
        queryFn: abortableQueryFn(
          const Duration(seconds: 3),
          () => 'data-initial',
        ),
      );
      async.elapse(const Duration(seconds: 3));

      final query = cache.get(const ['key'])!;
      // Initial failureCount == 0
      expect(query.state.failureCount, 0);

      client.fetchQuery<String, Object>(
        queryKey: const ['key'],
        queryFn: abortableQueryFn(
          const Duration(seconds: 3),
          () => throw Exception(),
        ),
        retry: (retryCount, error) => const Duration(seconds: 1),
      );

      // Wait for initial fetch to fail
      async.elapse(const Duration(seconds: 3));
      // Should have incremented failureCount
      expect(query.state.failureCount, 1);

      // Cancel while retrying
      client.cancelQueries(queryKey: const ['key'], revert: true);
      async.flushMicrotasks();

      // Should have reverted to previous state
      expect(query.state.fetchStatus, FetchStatus.idle);
      expect(query.state.failureCount, 0);
    }));

    test(
        'SHOULD cancel AND preserve current state '
        'WHEN revert == false', withFakeAsync((async) {
      // Fetch initial data
      client.fetchQuery<String, Object>(
        queryKey: const ['key'],
        queryFn: abortableQueryFn(
          const Duration(seconds: 3),
          () => 'data-initial',
        ),
      );
      async.elapse(const Duration(seconds: 3));

      final query = cache.get(const ['key'])!;
      // Initial failureCount == 0
      expect(query.state.failureCount, 0);

      // Start new fetch that will fail
      client.fetchQuery<String, Object>(
        queryKey: const ['key'],
        queryFn: abortableQueryFn(
          const Duration(seconds: 3),
          () => throw Exception(),
        ),
        retry: (retryCount, error) => const Duration(seconds: 1),
      );

      // Wait for initial fetch to fail
      async.elapse(const Duration(seconds: 3));
      // Should have incremented failureCount
      expect(query.state.failureCount, 1);

      // Cancel while retrying
      client.cancelQueries(queryKey: const ['key'], revert: false);
      async.flushMicrotasks();

      // Should have set fetchStatus to FetchStatus.idle even when revert == true
      expect(query.state.fetchStatus, FetchStatus.idle);
      // Should have preserved failureCount
      expect(query.state.failureCount, 1);
    }));

    test(
        'SHOULD NOT throw '
        'WHEN revert == true AND has prior data', withFakeAsync((async) {
      Object? caughtError;

      client.fetchQuery(
        queryKey: const ['key'],
        queryFn: abortableQueryFn(
          const Duration(seconds: 3),
          () => 'data-initial',
        ),
      );
      async.elapse(const Duration(seconds: 3));

      client.fetchQuery(
        queryKey: const ['key'],
        queryFn: abortableQueryFn(
          const Duration(seconds: 3),
          () => 'data-new',
        ),
      ).catchError((e) {
        caughtError = e;
        return 'error';
      });

      // Cancel with revert
      client.cancelQueries(queryKey: const ['key'], revert: true);
      async.flushMicrotasks();

      // Should NOT have thrown (prior data exists)
      expect(caughtError, isNull);
    }));

    test(
        'SHOULD throw AbortedException '
        'WHEN revert == true AND has no prior data', withFakeAsync((async) {
      Object? caughtError;

      client.fetchQuery(
        queryKey: const ['key'],
        queryFn: abortableQueryFn(
          const Duration(seconds: 3),
          () => 'data',
        ),
      ).catchError((e) {
        caughtError = e;
        return 'error';
      });

      // Cancel with revert
      client.cancelQueries(queryKey: const ['key'], revert: true);
      async.flushMicrotasks();

      // Should have thrown AbortedException (no prior data)
      expect(caughtError, isA<AbortedException>());
    }));

    test(
        'SHOULD NOT throw '
        'WHEN silent == true', withFakeAsync((async) {
      Object? caughtError;

      client.fetchQuery<String, Object>(
        queryKey: const ['key'],
        queryFn: abortableQueryFn(
          const Duration(seconds: 3),
          () => 'data',
        ),
      ).catchError((e) {
        caughtError = e;
        return 'error';
      });

      // Cancel with silent: true
      client.cancelQueries(queryKey: const ['key'], silent: true);
      async.flushMicrotasks();

      // Should NOT have thrown even without prior data
      expect(caughtError, isNull);
    }));

    test(
        'SHOULD throw AbortedException '
        'WHEN silent == false', withFakeAsync((async) {
      Object? caughtError;

      // Start fetch with abortable queryFn
      client.fetchQuery<String, Object>(
        queryKey: const ['key'],
        queryFn: abortableQueryFn(const Duration(seconds: 10), () => 'data'),
      ).catchError((e) {
        caughtError = e;
        return 'error';
      });

      async.flushMicrotasks();

      // Cancel with silent: false (default)
      client.cancelQueries(queryKey: const ['key'], silent: false);
      async.elapse(const Duration(milliseconds: 100));

      expect(caughtError, isA<AbortedException>());
    }));
  });

  group('fetchInfiniteQuery', () {
    test(
        'SHOULD fetch and return data'
        '', withFakeAsync((async) {
      final future = client.fetchInfiniteQuery<String, Object, int>(
        queryKey: const ['test'],
        queryFn: (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'page-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
      );

      expectLater(
        future,
        completion(InfiniteData(['page-0'], [0])),
      );

      async.elapse(const Duration(seconds: 1));
    }));

    test(
        'SHOULD NOT fetch and return cached data '
        'WHEN data is not stale', withFakeAsync((async) {
      // First fetch
      final future1 = client.fetchInfiniteQuery<String, Object, int>(
        queryKey: const ['test'],
        queryFn: (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'first-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        staleDuration: StaleDuration.infinity,
      );

      expectLater(
        future1,
        completion(InfiniteData(['first-0'], [0])),
      );

      async.elapse(const Duration(seconds: 1));

      // Second fetch with different queryFn - should return cached
      final future2 = client.fetchInfiniteQuery<String, Object, int>(
        queryKey: const ['test'],
        queryFn: (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'second-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        staleDuration: StaleDuration.infinity,
      );

      // Should return cached data without waiting for fetch
      expectLater(
        future2,
        completion(InfiniteData(['first-0'], [0])),
      );

      async.flushMicrotasks();
    }));

    test(
        'SHOULD refetch and return new data '
        'WHEN data is stale', withFakeAsync((async) {
      final future1 = client.fetchInfiniteQuery<String, Object, int>(
        queryKey: const ['test'],
        queryFn: (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'first-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        staleDuration: StaleDuration.zero,
      );

      expectLater(
        future1,
        completion(InfiniteData(['first-0'], [0])),
      );

      async.elapse(const Duration(seconds: 1));

      final future2 = client.fetchInfiniteQuery<String, Object, int>(
        queryKey: const ['test'],
        queryFn: (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'second-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        staleDuration: StaleDuration.zero,
      );

      expectLater(
        future2,
        completion(InfiniteData(['second-0'], [0])),
      );

      async.elapse(const Duration(seconds: 1));
    }));

    test(
        'SHOULD throw'
        '', withFakeAsync((async) {
      final expectedError = Exception();

      final future = client.fetchInfiniteQuery<String, Exception, int>(
        queryKey: const ['test'],
        queryFn: (context) async {
          await Future.delayed(const Duration(seconds: 1));
          throw expectedError;
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
      );

      expectLater(future, throwsA(same(expectedError)));

      async.elapse(const Duration(seconds: 1));
    }));

    test(
        'SHOULD NOT retry by default'
        '', withFakeAsync((async) {
      var attempts = 0;

      final future = client.fetchInfiniteQuery<String, Exception, int>(
        queryKey: const ['test'],
        queryFn: (context) async {
          await Future.delayed(const Duration(seconds: 1));
          attempts++;
          throw Exception();
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
      );

      expectLater(future, throwsA(isA<Exception>()));

      async.elapse(const Duration(seconds: 1));

      expect(attempts, 1);

      // Wait long enough for retries if they were happening
      async.elapse(const Duration(hours: 24));
      // Should NOT have retried
      expect(attempts, 1);
    }));

    test(
        'SHOULD fetch multiple pages '
        'WHEN pages parameter is set', withFakeAsync((async) {
      final future = client.fetchInfiniteQuery<String, Object, int>(
        queryKey: const ['test'],
        queryFn: (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'page-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        pages: 3,
      );

      expectLater(
        future,
        completion(InfiniteData(
          ['page-0', 'page-1', 'page-2'],
          [0, 1, 2],
        )),
      );

      // 1 second per page
      async.elapse(const Duration(seconds: 3));
    }));

    test(
        'SHOULD stop fetching pages '
        'WHEN nextPageParamBuilder returns null', withFakeAsync((async) {
      final future = client.fetchInfiniteQuery<String, Object, int>(
        queryKey: const ['test'],
        queryFn: (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'page-${context.pageParam}';
        },
        initialPageParam: 0,
        // Only allow 2 pages
        nextPageParamBuilder: (data) =>
            data.pages.length < 2 ? data.pageParams.last + 1 : null,
        // Request 5 pages but only 2 available
        pages: 5,
      );

      // Should stop at 2 pages
      expectLater(
        future,
        completion(InfiniteData(
          ['page-0', 'page-1'],
          [0, 1],
        )),
      );

      async.elapse(const Duration(seconds: 2));
    }));

    test(
        'SHOULD respect maxPages limit'
        '', withFakeAsync((async) {
      final future = client.fetchInfiniteQuery<String, Object, int>(
        queryKey: const ['test'],
        queryFn: (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'page-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        pages: 5,
        maxPages: 3,
      );

      expectLater(
        future,
        completion(InfiniteData(
          ['page-2', 'page-3', 'page-4'],
          [2, 3, 4],
        )),
      );

      async.elapse(const Duration(seconds: 5));
    }));

    test(
        'SHOULD refetch all existing pages'
        '', withFakeAsync((async) {
      // First fetch 3 pages
      final future1 = client.fetchInfiniteQuery<String, Object, int>(
        queryKey: const ['test'],
        queryFn: (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'first-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        pages: 3,
        staleDuration: StaleDuration.zero,
      );

      expectLater(
        future1,
        completion(InfiniteData(
          ['first-0', 'first-1', 'first-2'],
          [0, 1, 2],
        )),
      );

      async.elapse(const Duration(seconds: 3));

      // Refetch - should maintain 3 pages
      final future2 = client.fetchInfiniteQuery<String, Object, int>(
        queryKey: const ['test'],
        queryFn: (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'second-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        // Even though pages=1, should refetch all 3 existing pages
        pages: 1,
        staleDuration: StaleDuration.zero,
      );

      expectLater(
        future2,
        completion(InfiniteData(
          ['second-0', 'second-1', 'second-2'],
          [0, 1, 2],
        )),
      );

      async.elapse(const Duration(seconds: 3));
    }));

    test(
        'SHOULD persist data to cache'
        '', withFakeAsync((async) {
      client.fetchInfiniteQuery<String, Object, int>(
        queryKey: const ['test'],
        queryFn: (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'page-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
      );

      async.elapse(const Duration(seconds: 1));

      expect(
        client.cache.get(const ['test'])!.state.data,
        InfiniteData(['page-0'], [0]),
      );
    }));

    test(
        'SHOULD return same future '
        'WHEN another fetch already in progress', withFakeAsync((async) {
      final future1 = client.fetchInfiniteQuery<String, Object, int>(
        queryKey: const ['test'],
        queryFn: (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'first-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
      );
      final future2 = client.fetchInfiniteQuery<String, Object, int>(
        queryKey: const ['test'],
        queryFn: (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'second-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
      );

      expectLater(
        future1,
        completion(InfiniteData(['first-0'], [0])),
      );
      expectLater(
        future2,
        completion(InfiniteData(['first-0'], [0])),
      );

      async.elapse(const Duration(seconds: 1));
    }));

    group('seed', () {
      test(
          'SHOULD NOT fetch and return seed '
          'WHEN data is fresh', withFakeAsync((async) {
        var attempts = 0;

        final future = client.fetchInfiniteQuery<String, Object, int>(
          queryKey: const ['test'],
          queryFn: (context) async {
            attempts++;
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          seed: InfiniteData(['page-seed'], [0]),
          staleDuration: StaleDuration.infinity,
        );

        expectLater(
          future,
          completion(InfiniteData(['page-seed'], [0])),
        );

        async.flushMicrotasks();

        expect(attempts, 0);
      }));

      test(
          'SHOULD fetch and return fetched data '
          'WHEN seed is stale', withFakeAsync((async) {
        var attempts = 0;

        final future = client.fetchInfiniteQuery<String, Object, int>(
          queryKey: const ['test'],
          queryFn: (context) async {
            attempts++;
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          seed: InfiniteData(['page-seed'], [0]),
          staleDuration: StaleDuration.zero,
        );

        expectLater(
          future,
          completion(InfiniteData(['page-0'], [0])),
        );

        async.elapse(const Duration(seconds: 1));

        expect(attempts, 1);
      }));
    });
  });

  group('prefetchInfiniteQuery', () {
    test(
        'SHOULD NOT throw'
        '', withFakeAsync((async) {
      final future = client.prefetchInfiniteQuery<String, Exception, int>(
        queryKey: const ['test'],
        queryFn: (context) async {
          await Future.delayed(const Duration(seconds: 1));
          throw Exception();
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
      );

      expectLater(future, completes);

      async.elapse(const Duration(seconds: 1));
    }));

    test(
        'SHOULD persist data to cache'
        '', withFakeAsync((async) {
      client.prefetchInfiniteQuery<String, Object, int>(
        queryKey: const ['test'],
        queryFn: (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'page-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        pages: 2,
      );

      async.elapse(const Duration(seconds: 2));

      expect(
        client.cache.get(const ['test'])!.state.data,
        InfiniteData(['page-0', 'page-1'], [0, 1]),
      );
    }));
  });

  group('getInfiniteQueryData', () {
    test(
        'SHOULD return data '
        'WHEN query exists with data', withFakeAsync((async) {
      client.fetchInfiniteQuery<String, Object, int>(
        queryKey: const ['test'],
        queryFn: (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'page-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        pages: 2,
      );

      async.elapse(const Duration(seconds: 2));

      expect(
        client.getInfiniteQueryData(const ['test']),
        InfiniteData(['page-0', 'page-1'], [0, 1]),
      );
    }));

    test(
        'SHOULD return null '
        'WHEN query does not exist', withFakeAsync((async) {
      final data = client.getInfiniteQueryData(const ['test']);

      expect(data, isNull);
    }));

    test(
        'SHOULD return null '
        'WHEN query exists without data', withFakeAsync((async) {
      // Build a query without fetching (query exists but in pending state)
      client.cache.build<InfiniteData<String, int>, Object>(QueryOptions(
        const ['test'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return InfiniteData(['data'], [0]);
        },
      ));

      final data = client.getInfiniteQueryData(const ['test']);

      expect(data, isNull);
    }));

    test(
        'SHOULD use exact key matching'
        '', withFakeAsync((async) {
      client.fetchInfiniteQuery<String, Object, int>(
        queryKey: const ['test', '1'],
        queryFn: (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'page-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
      );

      async.elapse(const Duration(seconds: 1));

      // Prefix key should not match
      var data = client.getInfiniteQueryData(const ['test']);
      expect(data, isNull);

      // Exact key should match
      data = client.getInfiniteQueryData(const ['test', '1']);
      expect(data, InfiniteData(['page-0'], [0]));
    }));
  });
}
