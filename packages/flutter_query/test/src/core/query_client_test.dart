import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_query/src/core/core.dart';
import '../../utils.dart';

void main() {
  late QueryClient client;
  late QueryCache cache;

  setUp(() {
    client = QueryClient();
    cache = client.cache;
  });

  tearDown(() {
    client.clear();
  });

  group('Constructor: new', () {
    test(
        'SHOULD provide default enabled for queries'
        '', withFakeAsync((async) {
      var fetches = 0;

      // enabled: false - should NOT fetch
      client.defaultQueryOptions = DefaultQueryOptions(
        enabled: false,
      );
      final observer1 = QueryObserver<String, Object>(
        client,
        QueryObserverOptions(
          const ['key', 1],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'data-1';
          },
        ),
      )..onMount();
      addTearDown(observer1.onUnmount);

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 0);

      // =======================================================================

      fetches = 0;

      // enabled: true - should fetch
      client.defaultQueryOptions = DefaultQueryOptions(
        enabled: true,
      );
      final observer2 = QueryObserver<String, Object>(
        client,
        QueryObserverOptions(
          const ['key', 2],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'data-1';
          },
        ),
      )..onMount();
      addTearDown(observer2.onUnmount);

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);
    }));

    test(
        'SHOULD provide default staleDuration for queries'
        '', withFakeAsync((async) {
      var fetches = 0;

      // StaleDuration.zero - data is immediately stale, should refetch on remount
      client.defaultQueryOptions = DefaultQueryOptions(
        staleDuration: StaleDuration.zero,
      );
      final observer1 = QueryObserver<String, Object>(
        client,
        QueryObserverOptions(
          const ['key', 1],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'data-1';
          },
        ),
      )..onMount();
      addTearDown(observer1.onUnmount);

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);

      observer1.onUnmount();
      observer1.onMount();

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 2);

      // =======================================================================

      fetches = 0;

      // StaleDuration.infinity - data is never stale, should NOT refetch
      client.defaultQueryOptions = DefaultQueryOptions(
        staleDuration: StaleDuration.infinity,
      );
      final observer2 = QueryObserver<String, Object>(
        client,
        QueryObserverOptions(
          const ['key', 2],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'data-1';
          },
        ),
      )..onMount();
      addTearDown(observer2.onUnmount);

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);

      observer2.onUnmount();
      observer2.onMount();

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);

      // Manual invalidation marks query as invalidated
      client.invalidateQueries(queryKey: const ['key', 2]);

      // Remount after invalidation should refetch
      observer2.onUnmount();
      observer2.onMount();

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 2);

      // =======================================================================

      fetches = 0;

      // StaleDuration.static - data is never stale, should NOT refetch
      client.defaultQueryOptions = DefaultQueryOptions(
        staleDuration: StaleDuration.static,
      );
      final observer3 = QueryObserver<String, Object>(
        client,
        QueryObserverOptions(
          const ['key', 3],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'data-1';
          },
        ),
      )..onMount();
      addTearDown(observer3.onUnmount);

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);

      observer3.onUnmount();
      observer3.onMount();

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);

      // Manual invalidation marks query as invalidated
      client.invalidateQueries(queryKey: const ['key', 3]);

      // Remount after invalidation should still NOT refetch for static
      observer3.onUnmount();
      observer3.onMount();

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);

      // =======================================================================

      fetches = 0;

      // StaleDuration(minutes: 10) - data becomes stale after 10 minutes
      client.defaultQueryOptions = DefaultQueryOptions(
        staleDuration: const StaleDuration(minutes: 10),
      );
      final observer4 = QueryObserver<String, Object>(
        client,
        QueryObserverOptions(
          const ['key', 4],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'data-1';
          },
        ),
      )..onMount();
      addTearDown(observer4.onUnmount);

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);

      // Remount before stale - should NOT refetch
      observer4.onUnmount();
      observer4.onMount();

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);

      // Wait until data becomes stale (10 minutes from fetch)
      async.elapse(const Duration(minutes: 10));

      // Remount after stale - should refetch
      observer4.onUnmount();
      observer4.onMount();

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 2);
    }));

    test(
        'SHOULD provide default gcDuration for queries'
        '', withFakeAsync((async) {
      // GcDuration.zero - query is garbage collected immediately
      client.defaultQueryOptions = DefaultQueryOptions(
        gcDuration: GcDuration.zero,
      );
      final observer1 = QueryObserver<String, Object>(
        client,
        QueryObserverOptions(
          const ['key', 1],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'data-1';
          },
        ),
      )..onMount();
      addTearDown(observer1.onUnmount);

      async.elapse(const Duration(seconds: 1));
      expect(cache.get(const ['key', 1]), isNotNull);

      observer1.onUnmount();

      async.elapse(Duration.zero);
      expect(cache.get(const ['key', 1]), isNull);

      // =======================================================================

      // GcDuration(minutes: 20) - query is garbage collected after 20 minutes
      client.defaultQueryOptions = DefaultQueryOptions(
        gcDuration: const GcDuration(minutes: 20),
      );
      final observer2 = QueryObserver<String, Object>(
        client,
        QueryObserverOptions(
          const ['key', 2],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'data-1';
          },
        ),
      )..onMount();
      addTearDown(observer2.onUnmount);

      async.elapse(const Duration(seconds: 1));
      expect(cache.get(const ['key', 2]), isNotNull);

      observer2.onUnmount();

      async.elapse(const Duration(minutes: 19, seconds: 59));
      expect(cache.get(const ['key', 2]), isNotNull);

      async.elapse(const Duration(seconds: 1));
      expect(cache.get(const ['key', 2]), isNull);

      // =======================================================================

      // GcDuration.infinity - query is never garbage collected
      client.defaultQueryOptions = DefaultQueryOptions(
        gcDuration: GcDuration.infinity,
      );
      final observer3 = QueryObserver<String, Object>(
        client,
        QueryObserverOptions(
          const ['key', 3],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'data-1';
          },
        ),
      )..onMount();
      addTearDown(observer3.onUnmount);

      async.elapse(const Duration(seconds: 1));
      expect(cache.get(const ['key', 3]), isNotNull);

      observer3.onUnmount();

      async.elapse(const Duration(days: 365));
      expect(cache.get(const ['key', 3]), isNotNull);
    }));

    test(
        'SHOULD provide default refetchInterval for queries'
        '', withFakeAsync((async) {
      client.defaultQueryOptions = DefaultQueryOptions(
        refetchInterval: const Duration(minutes: 1),
      );
      final observer = QueryObserver<String, Object>(
        client,
        QueryObserverOptions(
          const ['key'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'data-1';
          },
        ),
      )..onMount();
      addTearDown(observer.onUnmount);

      final query = cache.get(const ['key'])!;

      async.elapse(const Duration(minutes: 1));
      expect(query.state.fetchStatus, FetchStatus.fetching);
      async.elapse(const Duration(minutes: 1));
      expect(query.state.fetchStatus, FetchStatus.fetching);
      async.elapse(const Duration(minutes: 1));
      expect(query.state.fetchStatus, FetchStatus.fetching);
    }));

    test(
        'SHOULD provide default refetchOnMount for queries'
        '', withFakeAsync((async) {
      var fetches = 0;

      // RefetchOnMount.stale - should refetch only if data is stale
      client.defaultQueryOptions = DefaultQueryOptions(
        refetchOnMount: RefetchOnMount.stale,
      );

      // With stale data (staleDuration: zero) - should refetch
      final observer1 = QueryObserver<String, Object>(
        client,
        QueryObserverOptions(
          const ['key', 1],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'data-1';
          },
          staleDuration: StaleDuration.zero,
        ),
      )..onMount();
      addTearDown(observer1.onUnmount);

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);

      observer1.onUnmount();
      observer1.onMount();

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 2);

      // With fresh data (staleDuration: infinity) - should NOT refetch
      fetches = 0;
      final observer2 = QueryObserver<String, Object>(
        client,
        QueryObserverOptions(
          const ['key', 2],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'data-1';
          },
          staleDuration: StaleDuration.infinity,
        ),
      )..onMount();
      addTearDown(observer2.onUnmount);

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);

      observer2.onUnmount();
      observer2.onMount();

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);

      // =======================================================================

      fetches = 0;

      // RefetchOnMount.never - should never refetch on mount
      client.defaultQueryOptions = DefaultQueryOptions(
        refetchOnMount: RefetchOnMount.never,
      );
      final observer3 = QueryObserver<String, Object>(
        client,
        QueryObserverOptions(
          const ['key', 3],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'data-1';
          },
        ),
      )..onMount();
      addTearDown(observer3.onUnmount);

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);

      observer3.onUnmount();
      observer3.onMount();

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);

      // =======================================================================

      fetches = 0;

      // RefetchOnMount.always - should always refetch on mount
      client.defaultQueryOptions = DefaultQueryOptions(
        refetchOnMount: RefetchOnMount.always,
      );
      final observer4 = QueryObserver<String, Object>(
        client,
        QueryObserverOptions(
          const ['key', 4],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'data-1';
          },
          staleDuration: StaleDuration.infinity,
        ),
      )..onMount();
      addTearDown(observer4.onUnmount);

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);

      observer4.onUnmount();
      observer4.onMount();

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 2);
    }));

    test(
        'SHOULD provide default refetchOnResume for queries'
        '', withFakeAsync((async) {
      var fetches = 0;

      // RefetchOnResume.stale - should refetch only if data is stale
      client.defaultQueryOptions = DefaultQueryOptions(
        refetchOnResume: RefetchOnResume.stale,
      );

      // With stale data (staleDuration: zero) - should refetch
      final observer1 = QueryObserver<String, Object>(
        client,
        QueryObserverOptions(
          const ['key', 1],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'data-1';
          },
          staleDuration: StaleDuration.zero,
        ),
      )..onMount();
      addTearDown(observer1.onUnmount);

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);

      observer1.onResume();

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 2);

      // With fresh data (staleDuration: infinity) - should NOT refetch
      fetches = 0;
      final observer2 = QueryObserver<String, Object>(
        client,
        QueryObserverOptions(
          const ['key', 2],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'data-1';
          },
          staleDuration: StaleDuration.infinity,
        ),
      )..onMount();
      addTearDown(observer2.onUnmount);

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);

      observer2.onResume();

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);

      // =======================================================================

      fetches = 0;

      // RefetchOnResume.never - should never refetch on resume
      client.defaultQueryOptions = DefaultQueryOptions(
        refetchOnResume: RefetchOnResume.never,
      );
      final observer3 = QueryObserver<String, Object>(
        client,
        QueryObserverOptions(
          const ['key', 3],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'data-1';
          },
        ),
      )..onMount();
      addTearDown(observer3.onUnmount);

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);

      observer3.onResume();

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);

      // =======================================================================

      fetches = 0;

      // RefetchOnResume.always - should always refetch on resume
      client.defaultQueryOptions = DefaultQueryOptions(
        refetchOnResume: RefetchOnResume.always,
      );
      final observer4 = QueryObserver<String, Object>(
        client,
        QueryObserverOptions(
          const ['key', 4],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'data-1';
          },
          staleDuration: StaleDuration.infinity,
        ),
      )..onMount();
      addTearDown(observer4.onUnmount);

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);

      observer4.onResume();

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 2);
    }));

    test(
        'SHOULD provide default retry for queries'
        '', withFakeAsync((async) {
      var fetches = 0;

      // Should retry 2 times with 1s delay
      client.defaultQueryOptions = DefaultQueryOptions(
        retry: (retryCount, error) {
          if (retryCount >= 2) return null;
          return const Duration(seconds: 1);
        },
      );
      final observer = QueryObserver<String, Object>(
        client,
        QueryObserverOptions(
          const ['key'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            throw Exception();
          },
        ),
      )..onMount();
      addTearDown(observer.onUnmount);

      // Initial attempt
      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);

      // Retry 1
      async.elapse(const Duration(seconds: 2));
      expect(fetches, 2);

      // Retry 2
      async.elapse(const Duration(seconds: 2));
      expect(fetches, 3);

      // Should not retry again
      async.elapse(const Duration(seconds: 2));
      expect(fetches, 3);
    }));

    test(
        'SHOULD provide default retryOnMount for queries'
        '', withFakeAsync((async) {
      var fetches = 0;

      // Should NOT retry on mount
      client.defaultQueryOptions = DefaultQueryOptions(
        retry: (retryCount, error) => null,
        retryOnMount: false,
      );
      final observer1 = QueryObserver<String, Object>(
        client,
        QueryObserverOptions(
          const ['key', 1],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            throw Exception();
          },
        ),
      )..onMount();
      addTearDown(observer1.onUnmount);

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);
      expect(cache.get(const ['key', 1])!.state.status, QueryStatus.error);

      observer1.onUnmount();
      observer1.onMount();

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);

      // =======================================================================

      fetches = 0;

      // Should retry on mount
      client.defaultQueryOptions = DefaultQueryOptions(
        retryOnMount: true,
        retry: (retryCount, error) => null,
      );
      final observer2 = QueryObserver<String, Object>(
        client,
        QueryObserverOptions(
          const ['key', 2],
          (context) async {
            fetches++;
            await Future.delayed(const Duration(seconds: 1));
            throw Exception();
          },
        ),
      )..onMount();
      addTearDown(observer1.onUnmount);

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);
      expect(cache.get(const ['key', 2])!.state.status, QueryStatus.error);

      observer2.onUnmount();
      observer2.onMount();

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 2);
    }));
  });

  group('Method: fetchQuery', () {
    test(
        'SHOULD fetch and return data '
        'WHEN fetch succeeds', withFakeAsync((async) {
      String? capturedData;

      client.fetchQuery<String, Object>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data';
        },
      ).then((result) => capturedData = result);
      async.elapse(const Duration(seconds: 1));

      expect(capturedData, 'data');
    }));

    test(
        'SHOULD throw '
        'WHEN fetch fails', withFakeAsync((async) {
      final expectedError = Exception();
      Object? capturedError;

      client.fetchQuery<String, Exception>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          throw expectedError;
        },
      ).catchError((e) {
        capturedError = e;
        return 'error';
      });
      async.elapse(const Duration(seconds: 1));

      expect(capturedError, same(expectedError));
    }));

    test(
        'SHOULD pass QueryFunctionContext to queryFn'
        '', withFakeAsync((async) {
      QueryFunctionContext? capturedContext;

      client.fetchQuery<String, Object>(
        const ['key', 123],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          capturedContext = context;
          return 'data';
        },
      );
      async.elapse(const Duration(seconds: 1));

      expect(capturedContext, isNotNull);
      expect(capturedContext!.queryKey, const ['key', 123]);
      expect(capturedContext!.client, same(client));
    }));

    test(
        'SHOULD return cached data immediately '
        'WHEN query exists and data is not stale', withFakeAsync((async) {
      String? capturedData;

      client.fetchQuery<String, Object>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data-1';
        },
        staleDuration: StaleDuration.infinity,
      );
      async.elapse(const Duration(seconds: 1));

      client.fetchQuery<String, Object>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data-2';
        },
        staleDuration: StaleDuration.infinity,
      ).then((result) => capturedData = result);
      async.flushMicrotasks();

      expect(capturedData, 'data-1');
    }));

    test(
        'SHOULD refetch and return new data '
        'WHEN query exists and data is stale', withFakeAsync((async) {
      var fetches = 0;
      String? capturedData;

      client.fetchQuery<String, Object>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          fetches++;
          return 'data-$fetches';
        },
        staleDuration: StaleDuration.zero,
      ).then((result) => capturedData = result);
      async.elapse(const Duration(seconds: 1));

      expect(capturedData, 'data-1');

      client.fetchQuery<String, Object>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          fetches++;
          return 'data-$fetches';
        },
        staleDuration: StaleDuration.zero,
      ).then((result) => capturedData = result);
      async.elapse(const Duration(seconds: 1));

      expect(capturedData, 'data-2');
    }));

    test(
        'SHOULD garbage collect query after gcDuration'
        '', withFakeAsync((async) {
      client.fetchQuery<String, Object>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data';
        },
        gcDuration: const GcDuration(minutes: 2),
      );
      async.elapse(const Duration(seconds: 1));

      // Should exist just before gc duration
      async.elapse(const Duration(minutes: 1, seconds: 59));
      expect(cache.get(const ['key']), isNotNull);

      // Should have been removed after gc duration
      async.elapse(const Duration(seconds: 1));
      expect(cache.get(const ['key']), isNull);
    }));

    test(
        'SHOULD NOT retry by default'
        '', withFakeAsync((async) {
      var fetches = 0;
      Object? capturedError;

      client.fetchQuery<String, Exception>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          fetches++;
          throw Exception('error');
        },
      ).then((_) {}, onError: (e) {
        capturedError = e;
      });
      async.elapse(const Duration(seconds: 1));

      expect(capturedError, isA<Exception>());
      expect(fetches, 1);

      // Wait long enough
      async.elapse(const Duration(hours: 24));
      // Should NOT have retried
      expect(fetches, 1);
    }));

    test(
        'SHOULD retry '
        'WHEN retry != null', withFakeAsync((async) {
      var fetches = 0;

      client.fetchQuery<String, Exception>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          fetches++;
          throw Exception();
        },
        retry: (retryCount, error) {
          if (retryCount >= 3) return null;
          return const Duration(seconds: 1);
        },
      ).ignore();

      // Initial attempt
      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);

      // Retry for 3 times with 1s delay
      async.elapse(const Duration(seconds: 1 + 1));
      expect(fetches, 2);
      async.elapse(const Duration(seconds: 1 + 1));
      expect(fetches, 3);
      async.elapse(const Duration(seconds: 1 + 1));
      expect(fetches, 4);
    }));

    test(
        'SHOULD NOT fetch and return seed immediately '
        'WHEN seed is not stale', withFakeAsync((async) {
      var fetches = 0;
      String? capturedData;

      client.fetchQuery<String, Object>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          fetches++;
          return 'data';
        },
        staleDuration: StaleDuration.infinity,
        seed: 'seed',
      ).then((result) => capturedData = result);
      async.flushMicrotasks();

      expect(fetches, 0);
      expect(capturedData, 'seed');
    }));

    test(
        'SHOULD fetch and return fetched data '
        'WHEN seed is stale', withFakeAsync((async) {
      var fetches = 0;
      String? capturedData;

      client.fetchQuery<String, Object>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          fetches++;
          return 'data';
        },
        staleDuration: StaleDuration.zero,
        seed: 'seed',
      ).then((result) => capturedData = result);
      async.elapse(const Duration(seconds: 1));

      expect(fetches, 1);
      expect(capturedData, 'data');
    }));

    test(
        'SHOULD NOT fetch and return seed immediately '
        'WHEN seed is not stale by seedUpdatedAt', withFakeAsync((async) {
      var fetches = 0;
      String? capturedData;

      client.fetchQuery<String, Object>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          fetches++;
          return 'data';
        },
        staleDuration: const StaleDuration(minutes: 5),
        seed: 'seed',
        seedUpdatedAt: clock.now(),
      ).then((result) => capturedData = result);
      async.flushMicrotasks();

      expect(fetches, 0);
      expect(capturedData, 'seed');
    }));

    test(
        'SHOULD fetch and return fetched data '
        'WHEN seed is stale by seedUpdatedAt', withFakeAsync((async) {
      var fetches = 0;
      String? capturedData;

      client.fetchQuery<String, Object>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          fetches++;
          return 'data';
        },
        staleDuration: const StaleDuration(minutes: 5),
        seed: 'seed',
        seedUpdatedAt: clock.minutesAgo(10),
      ).then((result) => capturedData = result);
      async.elapse(const Duration(seconds: 1));

      expect(fetches, 1);
      expect(capturedData, 'data');
    }));

    test(
        'SHOULD persist seed to cache'
        '', withFakeAsync((async) {
      client.fetchQuery<String, Object>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data';
        },
        staleDuration: StaleDuration.infinity,
        seed: 'seed',
      );
      async.elapse(const Duration(seconds: 1));

      final query = cache.get<String, Object>(const ['key']);
      expect(query, isNotNull);
      expect(query!.state.data, 'seed');
    }));

    test(
        'SHOULD return same future '
        'WHEN another fetch is in progress', withFakeAsync((async) {
      String? capturedResult1;
      String? capturedResult2;

      client.fetchQuery<String, Object>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data-1';
        },
      ).then((result) => capturedResult1 = result);
      client.fetchQuery<String, Object>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data-2';
        },
      ).then((result) => capturedResult2 = result);
      async.elapse(const Duration(seconds: 1));

      expect(capturedResult1, 'data-1');
      expect(capturedResult2, 'data-1');
    }));
  });

  group('Method: prefetchQuery', () {
    test(
        'SHOULD persist data to cache'
        '', withFakeAsync((async) {
      client.prefetchQuery<String, Object>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data';
        },
      );
      async.elapse(const Duration(seconds: 1));

      expect(
        cache.get<String, Object>(const ['key'])!.state.data,
        'data',
      );
    }));

    test(
        'SHOULD NOT throw '
        'WHEN fetch fails', withFakeAsync((async) {
      Object? capturedError;

      client.prefetchQuery<String, Exception>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          throw Exception();
        },
      ).catchError((e) {
        capturedError = e;
      });
      async.elapse(const Duration(seconds: 1));

      expect(capturedError, isNull);
      expect(cache.get(const ['key'])!.state.error, isA<Exception>());
    }));
  });

  group('Method: getQueryData', () {
    test(
        'SHOULD return data '
        'WHEN query exists', withFakeAsync((async) {
      client.fetchQuery<String, Object>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data';
        },
      );
      async.elapse(const Duration(seconds: 1));

      expect(client.getQueryData<String>(const ['key']), 'data');
    }));

    test(
        'SHOULD return null '
        'WHEN query does not exist', withFakeAsync((async) {
      expect(client.getQueryData<String>(const ['key']), isNull);
    }));

    test(
        'SHOULD return null '
        'WHEN query exists but has no data yet', withFakeAsync((async) {
      cache.build<String, Object>(QueryOptions<String, Object>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data';
        },
      ));

      expect(client.getQueryData<String>(const ['key']), isNull);
    }));

    test(
        'SHOULD return data from query matching by exact key'
        '', withFakeAsync((async) {
      client.fetchQuery<String, Object>(
        const ['key', 1],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data';
        },
      );
      async.elapse(const Duration(seconds: 1));

      // Should NOT match by prefix
      expect(client.getQueryData<String>(const ['key']), isNull);
      // Should match exact key
      expect(client.getQueryData<String>(const ['key', 1]), 'data');
    }));

    test(
        'SHOULD NOT have type casting problems with error type'
        '', withFakeAsync((async) {
      client.prefetchQuery<String, dynamic>(
        const ['dynamic'],
        (context) async => 'data-dynamic',
      );
      client.prefetchQuery<String, Object>(
        const ['Object'],
        (context) async => 'data-object',
      );
      client.prefetchQuery<String, Object?>(
        const ['Object?'],
        (context) async => 'data-object?',
      );
      client.prefetchQuery<String, Exception>(
        const ['Exception'],
        (context) async => 'data-exception',
      );
      client.prefetchQuery<String, Error>(
        const ['Error'],
        (context) async => 'data-error',
      );
      client.prefetchQuery<String, Null>(
        const ['Null'],
        (context) async => 'data-null',
      );
      client.prefetchQuery<String, Never>(
        const ['Never'],
        (context) async => 'data-never',
      );
      async.flushMicrotasks();

      final dataDynamic = client.getQueryData<String>(const ['dynamic']);
      final dataObject = client.getQueryData<String>(const ['Object']);
      final dataObjectNullable = client.getQueryData<String>(const ['Object?']);
      final dataException = client.getQueryData<String>(const ['Exception']);
      final dataError = client.getQueryData<String>(const ['Error']);
      final dataNull = client.getQueryData<String>(const ['Null']);
      final dataNever = client.getQueryData<String>(const ['Never']);

      expect(dataDynamic, 'data-dynamic');
      expect(dataObject, 'data-object');
      expect(dataObjectNullable, 'data-object?');
      expect(dataException, 'data-exception');
      expect(dataError, 'data-error');
      expect(dataNull, 'data-null');
      expect(dataNever, 'data-never');
    }));
  });

  group('Method: getQueryState', () {
    test(
        'SHOULD return success state '
        'WHEN fetch succeeds', withFakeAsync((async) {
      client.fetchQuery<String, Object>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data';
        },
      );

      var state = client.getQueryState<String, Object>(const ['key'])!;
      expect(state.status, QueryStatus.pending);
      expect(state.fetchStatus, FetchStatus.fetching);
      expect(state.data, isNull);
      expect(state.dataUpdatedAt, isNull);
      expect(state.dataUpdateCount, 0);

      async.elapse(const Duration(seconds: 1));

      state = client.getQueryState<String, Object>(const ['key'])!;
      expect(state.status, QueryStatus.success);
      expect(state.fetchStatus, FetchStatus.idle);
      expect(state.data, 'data');
      expect(state.dataUpdatedAt, clock.now());
      expect(state.dataUpdateCount, 1);
    }));

    test(
        'SHOULD return error state '
        'WHEN fetch fails', withFakeAsync((async) {
      final expectedError = Exception();

      client.fetchQuery<String, Object>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          throw expectedError;
        },
      ).ignore();

      var state = client.getQueryState<String, Object>(const ['key'])!;
      expect(state.status, QueryStatus.pending);
      expect(state.fetchStatus, FetchStatus.fetching);
      expect(state.error, isNull);
      expect(state.errorUpdatedAt, isNull);
      expect(state.errorUpdateCount, 0);

      async.elapse(const Duration(seconds: 1));

      state = client.getQueryState<String, Object>(const ['key'])!;
      expect(state.status, QueryStatus.error);
      expect(state.fetchStatus, FetchStatus.idle);
      expect(state.error, same(expectedError));
      expect(state.errorUpdatedAt, clock.now());
      expect(state.errorUpdateCount, 1);
    }));

    test(
        'SHOULD return null '
        'WHEN query does not exist', () {
      expect(client.getQueryState<String, Object>(const ['key']), isNull);
    });

    test(
        'SHOULD return state from matching query by exact key'
        '', withFakeAsync((async) {
      client.fetchQuery<String, Object>(
        const ['key', 1],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data';
        },
      );
      async.elapse(const Duration(seconds: 1));

      // Should NOT match by prefix
      expect(client.getQueryState<String, Object>(const ['key']), isNull);
      // Should match exact key
      expect(client.getQueryState<String, Object>(const ['key', 1]), isNotNull);
    }));
  });

  group('Method: setQueryData', () {
    test(
        'SHOULD set and return data '
        'WHEN query does not exist', withFakeAsync((async) {
      final data = client.setQueryData<String, Object>(
        const ['key'],
        (prev) => 'data',
      );

      expect(data, 'data');
      expect(client.getQueryData<String>(const ['key']), 'data');
    }));

    test(
        'SHOULD update and return data '
        'WHEN query exists', withFakeAsync((async) {
      client.fetchQuery(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data-1';
        },
      );
      async.elapse(const Duration(seconds: 1));

      final data = client.setQueryData(
        const ['key'],
        (prev) => 'data-2',
      );

      expect(data, 'data-2');
      expect(client.getQueryData(const ['key']), 'data-2');
    }));

    test(
        'SHOULD return null '
        'WHEN updater returns null', withFakeAsync((async) {
      final data = client.setQueryData<String, Object>(
        const ['key'],
        (prev) => null,
      );

      expect(data, isNull);
      expect(client.getQueryData(const ['key']), isNull);
    }));

    test(
        'SHOULD NOT update data '
        'WHEN updater returns null', withFakeAsync((async) {
      client.fetchQuery<String, Object>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data';
        },
      );
      async.elapse(const Duration(seconds: 1));

      final data = client.setQueryData<String, Object>(
        const ['key'],
        (prev) => null,
      );

      expect(data, isNull);
      expect(client.getQueryData<String>(const ['key']), 'data');
    }));

    test(
        'SHOULD pass previous data to updater function '
        'WHEN query exists', withFakeAsync((async) {
      String? capturedPrevData;

      client.fetchQuery<String, Object>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data-1';
        },
      );
      async.elapse(const Duration(seconds: 1));

      client.setQueryData<String, Object>(
        const ['key'],
        (previousData) {
          capturedPrevData = previousData;
          return 'data-2';
        },
      );

      expect(capturedPrevData, 'data-1');
    }));

    test(
        'SHOULD pass null to updater function '
        'WHEN query does not exist', withFakeAsync((async) {
      String? capturedPrevData = 'sentinel';

      client.setQueryData<String, Object>(
        const ['key'],
        (previousData) {
          capturedPrevData = previousData;
          return 'data';
        },
      );

      expect(capturedPrevData, isNull);
    }));

    test(
        'SHOULD set state to success'
        '', withFakeAsync((async) {
      client.setQueryData<String, Object>(
        const ['key'],
        (prev) => 'data',
      );

      final query = cache.get<String, Object>(const ['key'])!;
      expect(query.state.status, QueryStatus.success);
      expect(query.state.fetchStatus, FetchStatus.idle);
      expect(query.state.data, 'data');
      expect(query.state.dataUpdatedAt, isNotNull);
      expect(query.state.dataUpdateCount, 1);
    }));

    test(
        'SHOULD reset error to null'
        '', withFakeAsync((async) {
      client.prefetchQuery<String, Object>(
        const ['key'],
        (context) => throw Exception(),
      );
      async.flushMicrotasks();

      expect(
        cache.get<String, Object>(const ['key'])!.state.error,
        isA<Exception>(),
      );

      client.setQueryData<String, Object>(
        const ['key'],
        (prev) => 'data',
      );

      expect(
        cache.get<String, Object>(const ['key'])!.state.error,
        isNull,
      );
    }));

    test(
        'SHOULD reset invalidation status'
        '', withFakeAsync((async) {
      client.prefetchQuery<String, Object>(
        const ['key'],
        (context) async => 'data',
      );
      async.flushMicrotasks();
      client.invalidateQueries(queryKey: const ['key'], exact: true);

      expect(
        cache.get<String, Object>(const ['key'])!.state.isInvalidated,
        isTrue,
      );

      client.setQueryData<String, Object>(
        const ['key'],
        (prev) => 'data',
      );

      expect(
        cache.get<String, Object>(const ['key'])!.state.isInvalidated,
        isFalse,
      );
    }));

    test(
        'SHOULD set dataUpdatedAt to provided updatedAt'
        '', withFakeAsync((async) {
      client.setQueryData<String, Object>(
        const ['key'],
        (prev) => 'data',
        updatedAt: DateTime(2026, 1, 1),
      );

      final query = cache.get<String, Object>(const ['key'])!;
      expect(query.state.dataUpdatedAt, DateTime(2026, 1, 1));
    }));

    test(
        'SHOULD notify observers'
        '', withFakeAsync((async) {
      final capturedResults = <QueryResult<String, Object>>[];

      final observer = QueryObserver<String, Object>(
        client,
        QueryObserverOptions(
          const ['key'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            throw UnimplementedError();
          },
          enabled: false,
        ),
      );
      observer.onMount();
      addTearDown(observer.onUnmount);

      observer.subscribe((result) => capturedResults.add(result));

      client.setQueryData<String, Object>(
        const ['key'],
        (prev) => 'data',
      );

      expect(capturedResults.length, 1);
      expect(capturedResults.last.data, 'data');
    }));

    test(
        'SHOULD set throwing queryFn '
        'WHEN caching new query', withFakeAsync((async) {
      client.defaultQueryOptions = DefaultQueryOptions(retry: (_, __) => null);
      client.setQueryData<String, Object>(
        const ['key'],
        (prev) => 'data',
      );

      final query = cache.get<String, Object>(const ['key'])!;

      expectLater(
        query.fetch(),
        throwsA(isA<Error>()),
      );
      async.flushMicrotasks();
    }));
  });

  group('Method: invalidateQueries', () {
    test(
        'SHOULD invalidate queries matching by key prefix '
        'WHEN exact == false', withFakeAsync((async) {
      client.prefetchQuery(
        const ['key', 1],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data-1';
        },
      );
      client.prefetchQuery(
        const ['key', 2],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data-2';
        },
      );
      client.prefetchQuery(
        const ['other'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data-3';
        },
      );
      async.elapse(const Duration(seconds: 1));

      client.invalidateQueries(queryKey: const ['key'], exact: false);

      final query1 = cache.get(const ['key', 1]);
      final query2 = cache.get(const ['key', 2]);
      final query3 = cache.get(const ['other']);

      expect(query1!.state.isInvalidated, isTrue);
      expect(query2!.state.isInvalidated, isTrue);
      expect(query3!.state.isInvalidated, isFalse);
    }));

    test(
        'SHOULD invalidate query matching exact key '
        'WHEN exact == true', withFakeAsync((async) {
      client.prefetchQuery(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data-1';
        },
      );
      client.prefetchQuery(
        const ['key', 1],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data-2';
        },
      );
      async.elapse(const Duration(seconds: 1));

      client.invalidateQueries(queryKey: const ['key'], exact: true);

      final query1 = cache.get(const ['key']);
      final query2 = cache.get(const ['key', 1]);

      expect(query1!.state.isInvalidated, isTrue);
      expect(query2!.state.isInvalidated, isFalse);
    }));

    test(
        'SHOULD invalidate queries matching by predicate '
        'WHEN predicate != null', withFakeAsync((async) {
      client.fetchQuery(
        const ['key', 1],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data-1';
        },
      );
      client.fetchQuery(
        const ['key', 2],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data-2';
        },
      );
      async.elapse(const Duration(seconds: 1));

      client.invalidateQueries(predicate: (s) => s.key.last == 2);

      final query1 = cache.get(const ['key', 1]);
      final query2 = cache.get(const ['key', 2]);

      expect(query1!.state.isInvalidated, isFalse);
      expect(query2!.state.isInvalidated, isTrue);
    }));

    test(
        'SHOULD invalidate all queries '
        'WHEN no filters are provided', withFakeAsync((async) {
      final activeObserver1 = QueryObserver(
        client,
        QueryObserverOptions(
          const ['key', 1],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'data';
          },
          enabled: true,
        ),
      )..onMount();
      final activeObserver2 = QueryObserver(
        client,
        QueryObserverOptions(
          const ['key', 2],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'data';
          },
          enabled: true,
        ),
      )..onMount();
      client.fetchQuery(
        const ['key', 3],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data';
        },
      );
      client.fetchQuery(
        const ['key', 4],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data';
        },
      );
      final disabledObserver = QueryObserver(
        client,
        QueryObserverOptions(
          const ['key', 5],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'data';
          },
          enabled: false,
        ),
      )..onMount();
      async.elapse(const Duration(seconds: 1));

      client.invalidateQueries();

      expect(cache.get(const ['key', 1])!.state.isInvalidated, isTrue);
      expect(cache.get(const ['key', 2])!.state.isInvalidated, isTrue);
      expect(cache.get(const ['key', 3])!.state.isInvalidated, isTrue);
      expect(cache.get(const ['key', 4])!.state.isInvalidated, isTrue);
      expect(cache.get(const ['key', 5])!.state.isInvalidated, isTrue);

      activeObserver1.onUnmount();
      activeObserver2.onUnmount();
      disabledObserver.onUnmount();
    }));
  });

  group('Method: refetchQueries', () {
    test(
        'SHOULD refetch queries matching by key prefix'
        'WHEN exact == false', withFakeAsync((async) {
      var fetches1 = 0;
      var fetches2 = 0;
      var fetches3 = 0;

      final observer1 = QueryObserver(
        client,
        QueryObserverOptions(
          const ['key', 1],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches1++;
            return 'data-1';
          },
          enabled: true,
        ),
      )..onMount();
      addTearDown(observer1.onUnmount);
      final observer2 = QueryObserver(
        client,
        QueryObserverOptions(
          const ['key', 2],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches2++;
            return 'data-2';
          },
          enabled: true,
        ),
      )..onMount();
      addTearDown(observer2.onUnmount);
      final observer3 = QueryObserver(
        client,
        QueryObserverOptions(
          const ['other'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches3++;
            return 'data-3';
          },
          enabled: true,
        ),
      )..onMount();
      addTearDown(observer3.onUnmount);

      async.elapse(const Duration(seconds: 1));
      expect(fetches1, 1);
      expect(fetches2, 1);
      expect(fetches3, 1);

      client.refetchQueries(queryKey: const ['key'], exact: false);

      async.elapse(const Duration(seconds: 1));
      expect(fetches1, 2);
      expect(fetches2, 2);
      expect(fetches3, 1);
    }));

    test(
        'SHOULD refetch query matching exact key'
        'WHEN exact == true', withFakeAsync((async) {
      var fetches1 = 0;
      var fetches2 = 0;

      final observer1 = QueryObserver(
        client,
        QueryObserverOptions(
          const ['key'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches1++;
            return 'data-1';
          },
          enabled: true,
        ),
      )..onMount();
      addTearDown(observer1.onUnmount);
      final observer2 = QueryObserver(
        client,
        QueryObserverOptions(
          const ['key', 2],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches2++;
            return 'data-2';
          },
          enabled: true,
        ),
      )..onMount();
      addTearDown(observer2.onUnmount);

      async.elapse(const Duration(seconds: 1));
      expect(fetches1, 1);
      expect(fetches2, 1);

      client.refetchQueries(queryKey: const ['key'], exact: true);

      async.elapse(const Duration(seconds: 1));
      expect(fetches1, 2);
      expect(fetches2, 1);
    }));

    test(
        'SHOULD refetch queries matching by predicate '
        'WHEN predicate != null', withFakeAsync((async) {
      var fetches1 = 0;
      var fetches2 = 0;

      final observer1 = QueryObserver<String, Object>(
        client,
        QueryObserverOptions(
          const ['key', 1],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches1++;
            return 'data-1';
          },
          enabled: true,
        ),
      )..onMount();
      addTearDown(observer1.onUnmount);
      final observer2 = QueryObserver<String, Object>(
        client,
        QueryObserverOptions(
          const ['key', 2],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches2++;
            return 'data-2';
          },
          enabled: true,
        ),
      )..onMount();
      addTearDown(observer2.onUnmount);

      async.elapse(const Duration(seconds: 1));
      expect(fetches1, 1);
      expect(fetches2, 1);

      // Refetch only queries with key ending in 2
      client.refetchQueries(predicate: (s) => s.key.last == 2);

      async.elapse(const Duration(seconds: 1));
      expect(fetches1, 1);
      expect(fetches2, 2);
    }));

    test(
        'SHOULD NOT refetch inactive queries'
        '', withFakeAsync((async) {
      var fetches = 0;

      final observer = QueryObserver(
        client,
        QueryObserverOptions(
          const ['key'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'data';
          },
          enabled: false,
        ),
      )..onMount();
      addTearDown(observer.onUnmount);

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 0);

      client.refetchQueries(queryKey: const ['key']);

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 0);
    }));

    test(
        'SHOULD NOT refetch static queries'
        '', withFakeAsync((async) {
      var fetches = 0;

      final observer = QueryObserver<String, Object>(
        client,
        QueryObserverOptions(
          const ['key'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'data';
          },
          enabled: true,
          staleDuration: StaleDuration.static,
        ),
      )..onMount();
      addTearDown(observer.onUnmount);

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);

      client.refetchQueries(queryKey: const ['key']);

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);
    }));
  });

  group('Method: resetQueries', () {
    test(
        'SHOULD reset query to initial state'
        '', withFakeAsync((async) {
      client.prefetchQuery<String, Object>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data';
        },
      );

      async.elapse(const Duration(seconds: 1));
      var state = cache.get<String, Object>(const ['key'])!.state;
      expect(state.status, QueryStatus.success);
      expect(state.data, 'data');

      client.resetQueries(queryKey: const ['key']);

      state = cache.get<String, Object>(const ['key'])!.state;
      expect(state.status, QueryStatus.pending);
      expect(state.data, isNull);
    }));

    test(
        'SHOULD reset query data to seed'
        '', withFakeAsync((async) {
      client.prefetchQuery<String, Object>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data';
        },
        seed: 'seed',
      );

      async.elapse(const Duration(seconds: 1));
      expect(cache.get<String, Object>(const ['key'])!.state.data, 'data');

      client.resetQueries(queryKey: const ['key']);

      expect(cache.get<String, Object>(const ['key'])!.state.data, 'seed');
    }));

    test(
        'SHOULD reset queries matching by key prefix '
        'WHEN exact == false', withFakeAsync((async) {
      client.prefetchQuery<String, Object>(
        const ['key', 1],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data-1';
        },
      );
      client.prefetchQuery<String, Object>(
        const ['key', 2],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data-2';
        },
      );
      client.prefetchQuery<String, Object>(
        const ['other'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data-3';
        },
      );

      async.elapse(const Duration(seconds: 1));

      client.resetQueries(queryKey: const ['key'], exact: false);

      final state1 = cache.get<String, Object>(const ['key', 1])!.state;
      final state2 = cache.get<String, Object>(const ['key', 2])!.state;
      final state3 = cache.get<String, Object>(const ['other'])!.state;

      // Should have reset queries matching by key prefix
      expect(state1.status, QueryStatus.pending);
      expect(state1.data, isNull);
      expect(state2.status, QueryStatus.pending);
      expect(state2.data, isNull);
      // Should NOT have reset query with 'other' key
      expect(state3.status, QueryStatus.success);
      expect(state3.data, 'data-3');
    }));

    test(
        'SHOULD reset query matching exact key '
        'WHEN exact == true', withFakeAsync((async) {
      client.prefetchQuery<String, Object>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data';
        },
      );
      client.prefetchQuery<String, Object>(
        const ['key', 1],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data-1';
        },
      );

      async.elapse(const Duration(seconds: 1));

      client.resetQueries(queryKey: const ['key'], exact: true);

      final state1 = cache.get<String, Object>(const ['key'])!.state;
      final state2 = cache.get<String, Object>(const ['key', 1])!.state;

      // Should have reset query matching exact key
      expect(state1.status, QueryStatus.pending);
      expect(state1.data, isNull);
      // Should NOT have reset query mathcing by key prefix
      expect(state2.status, QueryStatus.success);
      expect(state2.data, 'data-1');
    }));

    test(
        'SHOULD reset queries matching by predicate '
        'WHEN predicate != null', withFakeAsync((async) {
      client.prefetchQuery<String, Object>(
        const ['key', 1],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data-1';
        },
      );
      client.prefetchQuery<String, Object>(
        const ['key', 2],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          throw Exception();
        },
      );

      async.elapse(const Duration(seconds: 1));

      // Reset only error queries
      client.resetQueries(predicate: (s) => s.status == QueryStatus.error);

      final state1 = cache.get<String, Object>(const ['key', 1])!.state;
      final state2 = cache.get<String, Object>(const ['key', 2])!.state;

      // Should NOT have reset success query
      expect(state1.status, QueryStatus.success);
      expect(state1.data, 'data-1');
      // Should have reset error query
      expect(state2.status, QueryStatus.pending);
      expect(state2.data, isNull);
    }));

    test(
        'SHOULD refetch active queries after reset'
        '', withFakeAsync((async) {
      var fetches1 = 0;
      var fetches2 = 0;

      final observer1 = QueryObserver<String, Object>(
        client,
        QueryObserverOptions(
          const ['key', 1],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches1++;
            return 'data-1';
          },
          enabled: true,
        ),
      )..onMount();
      addTearDown(observer1.onUnmount);
      final observer2 = QueryObserver<String, Object>(
        client,
        QueryObserverOptions(
          const ['key', 2],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches2++;
            return 'data-2';
          },
          enabled: true,
        ),
      )..onMount();
      addTearDown(observer2.onUnmount);

      async.elapse(const Duration(seconds: 1));
      expect(fetches1, 1);
      expect(fetches2, 1);

      client.resetQueries();

      async.elapse(const Duration(seconds: 1));
      expect(fetches1, 2);
      expect(fetches2, 2);
    }));

    test(
        'SHOULD NOT refetch inactive queries after reset'
        '', withFakeAsync((async) {
      var fetches1 = 0;
      var fetches2 = 0;

      // Inactive query 1 (no observers)
      client.prefetchQuery(
        const ['key', 1],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          fetches1++;
          return 'data';
        },
      );

      async.elapse(const Duration(seconds: 1));
      expect(fetches1, 1);

      client.resetQueries();

      async.elapse(const Duration(seconds: 1));
      expect(fetches1, 1);

      // Inactive query 2 (observer not enabled)
      final observer = QueryObserver<String, Object>(
        client,
        QueryObserverOptions(
          const ['key', 2],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches2++;
            return 'data';
          },
          enabled: false,
        ),
      )..onMount();
      addTearDown(observer.onUnmount);

      async.elapse(const Duration(seconds: 1));
      expect(fetches2, 0);

      client.resetQueries();

      async.elapse(const Duration(seconds: 1));
      expect(fetches2, 0);
    }));

    test(
        'SHOULD NOT refetch static queries after reset'
        '', withFakeAsync((async) {
      var fetches = 0;

      final observer = QueryObserver<String, Object>(
        client,
        QueryObserverOptions(
          const ['key'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'data';
          },
          enabled: true,
          staleDuration: StaleDuration.static,
        ),
      )..onMount();
      addTearDown(observer.onUnmount);

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);

      client.resetQueries();

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);
    }));

    test(
        'SHOULD notify observers'
        '', withFakeAsync((async) {
      final capturedResults = <QueryResult<String, Object>>[];

      final observer = QueryObserver<String, Object>(
        client,
        QueryObserverOptions(
          const ['key'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'data';
          },
        ),
      )
        ..onMount()
        ..subscribe((result) => capturedResults.add(result));
      addTearDown(observer.onUnmount);

      async.elapse(const Duration(seconds: 1));
      expect(capturedResults.length, 1);

      client.resetQueries(queryKey: const ['key']);
      // 2 additional notifications: reset to pending + refetch start
      expect(capturedResults.length, 3);

      async.elapse(const Duration(seconds: 1));
      expect(capturedResults.length, 4);
    }));

    test(
        'SHOULD cancel in-progress fetch'
        '', withFakeAsync((async) {
      var aborted = false;

      client.prefetchQuery<String, Object>(
        const ['key'],
        (context) async {
          await Future.any([
            Future.delayed(const Duration(seconds: 1)),
            context.signal.whenAbort,
          ]);
          aborted = context.signal.isAborted;
          return 'data';
        },
      );

      async.elapse(const Duration(milliseconds: 500));
      expect(
        cache.get<String, Object>(const ['key'])!.state.fetchStatus,
        FetchStatus.fetching,
      );

      // Reset while fetch is in progress
      client.resetQueries(queryKey: const ['key']);
      expect(
        cache.get<String, Object>(const ['key'])!.state.fetchStatus,
        FetchStatus.idle,
      );

      async.flushMicrotasks();
      // Should have been aborted
      expect(aborted, isTrue);

      async.elapse(const Duration(milliseconds: 500));
      // Should still be reset state
      expect(
        cache.get<String, Object>(const ['key'])!.state.fetchStatus,
        FetchStatus.idle,
      );
    }));
  });

  group('Method: removeQueries', () {
    test(
        'SHOULD remove queries matching by key prefix'
        '', withFakeAsync((async) {
      client.prefetchQuery(
        const ['key', 1],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data-1';
        },
      );
      client.prefetchQuery(
        const ['key', 2],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data-2';
        },
      );
      client.prefetchQuery(
        const ['other'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data-3';
        },
      );

      async.elapse(const Duration(seconds: 1));

      client.removeQueries(queryKey: const ['key'], exact: false);

      expect(cache.get(const ['key', 1]), isNull);
      expect(cache.get(const ['key', 2]), isNull);
      expect(cache.get(const ['other']), isNotNull);
    }));

    test(
        'SHOULD remove query matching exact key '
        'WHEN exact == true', withFakeAsync((async) {
      client.prefetchQuery(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data';
        },
      );
      client.prefetchQuery(
        const ['key', 1],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data-1';
        },
      );

      async.elapse(const Duration(seconds: 1));

      client.removeQueries(queryKey: const ['key'], exact: true);

      expect(cache.get(const ['key']), isNull);
      expect(cache.get(const ['key', 1]), isNotNull);
    }));

    test(
        'SHOULD remove queries matching by predicate '
        'WHEN predicate != null', withFakeAsync((async) {
      client.prefetchQuery(
        const ['key', 1],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data';
        },
      );
      client.prefetchQuery(
        const ['key', 2],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          throw Exception();
        },
      );

      async.elapse(const Duration(seconds: 1));

      client.removeQueries(predicate: (s) => s.status == QueryStatus.error);

      expect(cache.get(const ['key', 1]), isNotNull);
      expect(cache.get(const ['key', 2]), isNull);
    }));

    test(
        'SHOULD remove all queries '
        'WHEN no filters are provided', withFakeAsync((async) {
      client.prefetchQuery(
        const ['key', 1],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data-1';
        },
      );
      client.prefetchQuery(
        const ['key', 2],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data-2';
        },
      );
      client.prefetchQuery(
        const ['other'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data-3';
        },
      );

      async.elapse(const Duration(seconds: 1));

      client.removeQueries();

      expect(cache.get(const ['key', 1]), isNull);
      expect(cache.get(const ['key', 2]), isNull);
      expect(cache.get(const ['other']), isNull);
      expect(cache.getAll(), isEmpty);
    }));
  });

  group('Method: cancelQueries', () {
    test(
        'SHOULD cancel in-progress fetch'
        '', withFakeAsync((async) {
      client.prefetchQuery(
        const ['key'],
        (context) async {
          await Future.any([
            Future.delayed(const Duration(seconds: 1)),
            context.signal.whenAbort,
          ]);
          context.signal.throwIfAborted();
          return 'data';
        },
      );
      async.elapse(const Duration(milliseconds: 500));

      final query = cache.get(const ['key'])!;
      expect(query.state.fetchStatus, FetchStatus.fetching);

      client.cancelQueries(queryKey: const ['key']);
      async.flushMicrotasks();

      expect(query.state.fetchStatus, FetchStatus.idle);
    }));

    test(
        'SHOULD cancel queries matching by key prefix'
        'WHEN exact == false', withFakeAsync((async) {
      client.prefetchQuery(
        const ['key', 1],
        (context) async {
          await Future.any([
            Future.delayed(const Duration(seconds: 1)),
            context.signal.whenAbort,
          ]);
          context.signal.throwIfAborted();
          return 'data-1';
        },
      );
      client.prefetchQuery(
        const ['key', 2],
        (context) async {
          await Future.any([
            Future.delayed(const Duration(seconds: 1)),
            context.signal.whenAbort,
          ]);
          context.signal.throwIfAborted();
          return 'data-2';
        },
      );
      client.prefetchQuery(
        const ['other'],
        (context) async {
          await Future.any([
            Future.delayed(const Duration(seconds: 1)),
            context.signal.whenAbort,
          ]);
          context.signal.throwIfAborted();
          return 'data-other';
        },
      );

      client.cancelQueries(queryKey: const ['key'], exact: false);
      async.flushMicrotasks();

      final query1 = cache.get(const ['key', 1])!;
      final query2 = cache.get(const ['key', 2])!;
      final query3 = cache.get(const ['other'])!;

      expect(query1.state.fetchStatus, FetchStatus.idle);
      expect(query2.state.fetchStatus, FetchStatus.idle);
      expect(query3.state.fetchStatus, FetchStatus.fetching);
    }));

    test(
        'SHOULD cancel query matching exact key '
        'WHEN exact == true', withFakeAsync((async) {
      client.prefetchQuery(
        const ['key', 1],
        (context) async {
          await Future.any([
            Future.delayed(const Duration(seconds: 1)),
            context.signal.whenAbort,
          ]);
          context.signal.throwIfAborted();
          return 'data-1';
        },
      );
      client.prefetchQuery(
        const ['key', 2],
        (context) async {
          await Future.any([
            Future.delayed(const Duration(seconds: 1)),
            context.signal.whenAbort,
          ]);
          context.signal.throwIfAborted();
          return 'data-2';
        },
      );

      client.cancelQueries(queryKey: const ['key', 1], exact: true);
      async.flushMicrotasks();

      final query1 = cache.get(const ['key', 1])!;
      final query2 = cache.get(const ['key', 2])!;

      expect(query1.state.fetchStatus, FetchStatus.idle);
      expect(query2.state.fetchStatus, FetchStatus.fetching);
    }));

    test(
        'SHOULD cancel queries matching by predicate '
        'WHEN predicate != null', withFakeAsync((async) {
      client.prefetchQuery(
        const ['key', 1],
        (context) async {
          await Future.any([
            Future.delayed(const Duration(seconds: 1)),
            context.signal.whenAbort,
          ]);
          context.signal.throwIfAborted();
          return 'data-1';
        },
      );
      client.prefetchQuery(
        const ['key', 2],
        (context) => Completer<String>().future,
      );

      // Cancel only query with key ending in 1
      client.cancelQueries(predicate: (q) => q.key.last == 1);
      async.flushMicrotasks();

      final query1 = cache.get(const ['key', 1])!;
      final query2 = cache.get(const ['key', 2])!;

      expect(query1.state.fetchStatus, FetchStatus.idle);
      expect(query2.state.fetchStatus, FetchStatus.fetching);
    }));

    test(
        'SHOULD revert back to previous state '
        'WHEN revert == true', withFakeAsync((async) {
      client.prefetchQuery<String, Object>(
        const ['key'],
        (context) async {
          await Future.any([
            Future.delayed(const Duration(seconds: 1)),
            context.signal.whenAbort,
          ]);
          context.signal.throwIfAborted();
          return 'data';
        },
      );

      async.elapse(const Duration(seconds: 1));
      final query = cache.get(const ['key'])!;
      expect(query.state.failureCount, 0);

      client.prefetchQuery<String, Object>(
        const ['key'],
        (context) async {
          await Future.any([
            Future.delayed(const Duration(seconds: 1)),
            context.signal.whenAbort,
          ]);
          context.signal.throwIfAborted();
          throw Exception();
        },
        retry: (retryCount, error) => const Duration(seconds: 1),
      );

      async.elapse(const Duration(seconds: 1));
      expect(query.state.failureCount, 1);

      // Cancel while retrying
      client.cancelQueries(queryKey: const ['key'], revert: true);
      async.flushMicrotasks();

      expect(query.state.fetchStatus, FetchStatus.idle);
      expect(query.state.failureCount, 0);
    }));

    test(
        'SHOULD preserve current state '
        'WHEN revert == false', withFakeAsync((async) {
      client.prefetchQuery<String, Object>(
        const ['key'],
        (context) async {
          await Future.any([
            Future.delayed(const Duration(seconds: 1)),
            context.signal.whenAbort,
          ]);
          context.signal.throwIfAborted();
          return 'data';
        },
      );

      async.elapse(const Duration(seconds: 1));
      final query = cache.get(const ['key'])!;
      expect(query.state.failureCount, 0);

      client.prefetchQuery<String, Object>(
        const ['key'],
        (context) async {
          await Future.any([
            Future.delayed(const Duration(seconds: 1)),
            context.signal.whenAbort,
          ]);
          context.signal.throwIfAborted();
          throw Exception();
        },
        retry: (retryCount, error) => const Duration(seconds: 1),
      );

      async.elapse(const Duration(seconds: 1));
      expect(query.state.failureCount, 1);

      // Cancel while retrying
      client.cancelQueries(queryKey: const ['key'], revert: false);
      async.flushMicrotasks();

      expect(query.state.fetchStatus, FetchStatus.idle);
      expect(query.state.failureCount, 1);
    }));

    test(
        'SHOULD make fetcher throw AbortedException '
        'WHEN revert == true AND has no prior data', withFakeAsync((async) {
      Object? capturedError;

      client.fetchQuery(
        const ['key'],
        (context) async {
          await Future.any([
            Future.delayed(const Duration(seconds: 1)),
            context.signal.whenAbort,
          ]);
          context.signal.throwIfAborted();
          return 'data';
        },
      ).catchError((e) {
        capturedError = e;
        return 'error';
      });
      async.elapse(const Duration(milliseconds: 500));

      // Cancel with revert
      client.cancelQueries(queryKey: const ['key'], revert: true);
      async.flushMicrotasks();

      // Should have thrown AbortedException (no prior data)
      expect(capturedError, isA<AbortedException>());
    }));

    test(
        'SHOULD NOT make fetcher throw '
        'WHEN revert == true AND has prior data', withFakeAsync((async) {
      Object? capturedError;

      client.prefetchQuery(
        const ['key'],
        (context) async {
          await Future.any([
            Future.delayed(const Duration(seconds: 1)),
            context.signal.whenAbort,
          ]);
          context.signal.throwIfAborted();
          return 'data-1';
        },
      );
      async.elapse(const Duration(seconds: 1));

      client.fetchQuery(
        const ['key'],
        (context) async {
          await Future.any([
            Future.delayed(const Duration(seconds: 1)),
            context.signal.whenAbort,
          ]);
          context.signal.throwIfAborted();
          return 'data-2';
        },
      ).catchError((e) {
        capturedError = e;
        return 'error';
      });
      async.elapse(const Duration(milliseconds: 500));

      // Cancel with revert
      client.cancelQueries(queryKey: const ['key'], revert: true);
      async.flushMicrotasks();

      // Should NOT have thrown (prior data exists)
      expect(capturedError, isNull);
    }));

    test(
        'SHOULD NOT make fetcher throw '
        'WHEN silent == true', withFakeAsync((async) {
      Object? capturedError;

      client.fetchQuery<String, Object>(
        const ['key'],
        (context) async {
          await Future.any([
            Future.delayed(const Duration(seconds: 1)),
            context.signal.whenAbort,
          ]);
          context.signal.throwIfAborted();
          return 'data';
        },
      ).catchError((e) {
        capturedError = e;
        return 'error';
      });
      async.elapse(const Duration(milliseconds: 500));

      // Cancel with silent: true
      client.cancelQueries(queryKey: const ['key'], silent: true);
      async.flushMicrotasks();

      expect(capturedError, isNull);
    }));

    test(
        'SHOULD throw AbortedException '
        'WHEN silent == false', withFakeAsync((async) {
      Object? capturedError;

      client.fetchQuery<String, Object>(
        const ['key'],
        (context) async {
          await Future.any([
            Future.delayed(const Duration(seconds: 1)),
            context.signal.whenAbort,
          ]);
          context.signal.throwIfAborted();
          return 'data';
        },
      ).catchError((e) {
        capturedError = e;
        return 'error';
      });
      async.elapse(const Duration(milliseconds: 500));

      // Cancel with silent: false (default)
      client.cancelQueries(queryKey: const ['key'], silent: false);
      async.flushMicrotasks();

      expect(capturedError, isA<AbortedException>());
    }));

    test(
        'SHOULD complete immediately '
        'WHEN no fetch is in progress', withFakeAsync((async) {
      client.prefetchQuery(
        const ['key'],
        (context) async {
          await Future.any([
            Future.delayed(const Duration(seconds: 1)),
            context.signal.whenAbort,
          ]);
          context.signal.throwIfAborted();
          return 'data';
        },
      );
      async.elapse(const Duration(seconds: 1));

      final query = cache.get(const ['key'])!;
      expect(query.state.fetchStatus, FetchStatus.idle);

      expectLater(
        client.cancelQueries(queryKey: const ['key']),
        completes,
      );
      async.flushMicrotasks();
    }));
  });

  group('Method: fetchInfiniteQuery', () {
    test(
        'SHOULD fetch and return data'
        'WHEN fetch succeeds', withFakeAsync((async) {
      InfiniteData? capturedData;

      client.fetchInfiniteQuery<String, Object, int>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
      ).then((data) => capturedData = data);

      async.elapse(const Duration(seconds: 1));

      expect(capturedData, InfiniteData(['data-0'], [0]));
    }));

    test(
        'SHOULD throw '
        'WHEN fetch fails', withFakeAsync((async) {
      final expectedError = Exception();
      Object? capturedError;

      client.fetchInfiniteQuery<String, Exception, int>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          throw expectedError;
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
      ).catchError((e) {
        capturedError = e;
        return InfiniteData<String, int>.empty();
      });
      async.elapse(const Duration(seconds: 1));

      expect(capturedError, same(expectedError));
    }));

    test(
        'SHOULD pass InfiniteQueryFunctionContext to queryFn'
        '', withFakeAsync((async) {
      InfiniteQueryFunctionContext<int>? capturedContext;

      client.fetchInfiniteQuery<String, Object, int>(
        const ['key', 123],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          capturedContext = context;
          return 'data-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
      );
      async.elapse(const Duration(seconds: 1));

      expect(capturedContext, isNotNull);
      expect(capturedContext!.queryKey, const ['key', 123]);
      expect(capturedContext!.client, same(client));
      expect(capturedContext!.pageParam, 0);
    }));

    test(
        'SHOULD stop fetching pages '
        'WHEN nextPageParamBuilder returns null', withFakeAsync((async) {
      InfiniteData? capturedData;

      client.fetchInfiniteQuery<String, Object, int>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data-${context.pageParam}';
        },
        initialPageParam: 0,
        // Only allow 2 pages
        nextPageParamBuilder: (data) =>
            data.pages.length < 2 ? data.pageParams.last + 1 : null,
        // Request 5 pages but only 2 available
        pages: 5,
      ).then((data) => capturedData = data);
      async.elapse(const Duration(seconds: 2));

      // Should stop at 2 pages
      expect(
        capturedData,
        InfiniteData(['data-0', 'data-1'], [0, 1]),
      );
    }));

    test(
        'SHOULD limit number of pages '
        'WHEN maxPages != null', withFakeAsync((async) {
      InfiniteData? capturedData;

      client.fetchInfiniteQuery<String, Object, int>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        maxPages: 3,
        pages: 5,
      ).then((data) => capturedData = data);
      async.elapse(const Duration(seconds: 5));

      expect(
        capturedData,
        InfiniteData(['data-2', 'data-3', 'data-4'], [2, 3, 4]),
      );
    }));

    test(
        'SHOULD fetch multiple pages '
        'WHEN pages != null', withFakeAsync((async) {
      InfiniteData? capturedData;

      client.fetchInfiniteQuery<String, Object, int>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        pages: 3,
      ).then((data) => capturedData = data);
      // 1 second per page
      async.elapse(const Duration(seconds: 3));

      expect(
        capturedData,
        InfiniteData(
          ['data-0', 'data-1', 'data-2'],
          [0, 1, 2],
        ),
      );
    }));

    test(
        'SHOULD NOT fetch and return cached data immediately '
        'WHEN query exists and data is not stale', withFakeAsync((async) {
      var fetches1 = 0;
      var fetches2 = 0;
      InfiniteData? capturedData1;
      InfiniteData? capturedData2;

      client.fetchInfiniteQuery<String, Object, int>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          fetches1++;
          return 'data-1-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        staleDuration: StaleDuration.infinity,
      ).then((data) => capturedData1 = data);
      async.elapse(const Duration(seconds: 1));

      expect(fetches1, 1);
      expect(fetches2, 0);
      expect(capturedData1, InfiniteData(['data-1-0'], [0]));

      client.fetchInfiniteQuery<String, Object, int>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          fetches2++;
          return 'data-2-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        staleDuration: StaleDuration.infinity,
      ).then((data) => capturedData2 = data);
      async.flushMicrotasks();

      expect(fetches1, 1);
      expect(fetches2, 0);
      expect(capturedData2, InfiniteData(['data-1-0'], [0]));
    }));

    test(
        'SHOULD refetch and return new data '
        'WHEN query exists and data is stale', withFakeAsync((async) {
      var fetches1 = 0;
      var fetches2 = 0;
      InfiniteData? capturedData1;
      InfiniteData? capturedData2;

      client.fetchInfiniteQuery<String, Object, int>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          fetches1++;
          return 'data-1-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        staleDuration: StaleDuration.zero,
      ).then((data) => capturedData1 = data);
      async.elapse(const Duration(seconds: 1));

      expect(fetches1, 1);
      expect(fetches2, 0);
      expect(capturedData1, InfiniteData(['data-1-0'], [0]));

      client.fetchInfiniteQuery<String, Object, int>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          fetches2++;
          return 'data-2-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        staleDuration: StaleDuration.zero,
      ).then((data) => capturedData2 = data);
      async.elapse(const Duration(seconds: 1));

      expect(fetches1, 1);
      expect(fetches2, 1);
      expect(capturedData2, InfiniteData(['data-2-0'], [0]));
    }));

    test(
        'SHOULD garbage collect query after gcDuration'
        '', withFakeAsync((async) {
      client.fetchInfiniteQuery<String, Object, int>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        gcDuration: const GcDuration(minutes: 2),
      );
      async.elapse(const Duration(seconds: 1));

      // Should exist just before gc duration
      async.elapse(const Duration(minutes: 1, seconds: 59));
      expect(cache.get(const ['key']), isNotNull);

      // Should have been removed after gc duration
      async.elapse(const Duration(seconds: 1));
      expect(cache.get(const ['key']), isNull);
    }));

    test(
        'SHOULD NOT retry by default'
        '', withFakeAsync((async) {
      var fetches = 0;
      Object? capturedError;

      client.fetchInfiniteQuery<String, Exception, int>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          fetches++;
          throw Exception();
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
      ).catchError((e) {
        capturedError = e;
        return InfiniteData<String, int>.empty();
      });
      async.elapse(const Duration(seconds: 1));

      expect(fetches, 1);
      expect(capturedError, isA<Exception>());

      // Wait long enough for retries if they were happening
      async.elapse(const Duration(hours: 24));
      // Should NOT have retried
      expect(fetches, 1);
    }));

    test(
        'SHOULD retry '
        'WHEN retry != null', withFakeAsync((async) {
      var fetches = 0;

      client.fetchInfiniteQuery<String, Exception, int>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          fetches++;
          throw Exception();
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        retry: (retryCount, error) {
          if (retryCount >= 3) return null;
          return const Duration(seconds: 1);
        },
      ).ignore();

      // Initial attempt
      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);

      // Retry for 3 times with 1s delay
      async.elapse(const Duration(seconds: 1 + 1));
      expect(fetches, 2);
      async.elapse(const Duration(seconds: 1 + 1));
      expect(fetches, 3);
      async.elapse(const Duration(seconds: 1 + 1));
      expect(fetches, 4);
    }));

    test(
        'SHOULD NOT fetch and return seed immediately '
        'WHEN seed is not stale', withFakeAsync((async) {
      var fetches = 0;
      InfiniteData? capturedData;

      client.fetchInfiniteQuery<String, Object, int>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          fetches++;
          return 'data-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        staleDuration: StaleDuration.infinity,
        seed: InfiniteData(['seed-0'], [0]),
      ).then((data) => capturedData = data);
      async.flushMicrotasks();

      expect(fetches, 0);
      expect(capturedData, InfiniteData(['seed-0'], [0]));
    }));

    test(
        'SHOULD fetch and return fetched data '
        'WHEN seed is stale', withFakeAsync((async) {
      var fetches = 0;
      InfiniteData? capturedData;

      client.fetchInfiniteQuery<String, Object, int>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          fetches++;
          return 'data-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        staleDuration: StaleDuration.zero,
        seed: InfiniteData(['seed-0'], [0]),
      ).then((data) => capturedData = data);
      async.elapse(const Duration(seconds: 1));

      expect(fetches, 1);
      expect(capturedData, InfiniteData(['data-0'], [0]));
    }));

    test(
        'SHOULD NOT fetch and return seed immediately '
        'WHEN seed is not stale by seedUpdatedAt', withFakeAsync((async) {
      var fetches = 0;
      InfiniteData? capturedData;

      client.fetchInfiniteQuery<String, Object, int>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          fetches++;
          return 'data-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        staleDuration: const StaleDuration(minutes: 5),
        seed: InfiniteData(['seed-0'], [0]),
        seedUpdatedAt: clock.now(),
      ).then((data) => capturedData = data);
      async.flushMicrotasks();

      expect(fetches, 0);
      expect(capturedData, InfiniteData(['seed-0'], [0]));
    }));

    test(
        'SHOULD fetch and return fetched data '
        'WHEN seed is stale by seedUpdatedAt', withFakeAsync((async) {
      var fetches = 0;
      InfiniteData? capturedData;

      client.fetchInfiniteQuery<String, Object, int>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          fetches++;
          return 'data-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        staleDuration: const StaleDuration(minutes: 5),
        seed: InfiniteData(['seed-0'], [0]),
        seedUpdatedAt: clock.minutesAgo(10),
      ).then((data) => capturedData = data);
      async.elapse(const Duration(seconds: 1));

      expect(fetches, 1);
      expect(capturedData, InfiniteData(['data-0'], [0]));
    }));

    test(
        'SHOULD refetch all existing pages'
        '', withFakeAsync((async) {
      InfiniteData? capturedData1;
      InfiniteData? capturedData2;

      client.fetchInfiniteQuery<String, Object, int>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data-1-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        pages: 3,
        staleDuration: StaleDuration.zero,
      ).then((data) => capturedData1 = data);
      async.elapse(const Duration(seconds: 3));

      expect(
        capturedData1,
        InfiniteData(['data-1-0', 'data-1-1', 'data-1-2'], [0, 1, 2]),
      );

      // Refetch - should maintain 3 pages
      client.fetchInfiniteQuery<String, Object, int>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data-2-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        // Even though pages=1, should refetch all 3 existing pages
        pages: 1,
        staleDuration: StaleDuration.zero,
      ).then((data) => capturedData2 = data);
      async.elapse(const Duration(seconds: 3));

      expect(
        capturedData2,
        InfiniteData(['data-2-0', 'data-2-1', 'data-2-2'], [0, 1, 2]),
      );
    }));

    test(
        'SHOULD return same future '
        'WHEN another fetch is in progress', withFakeAsync((async) {
      InfiniteData? capturedData1;
      InfiniteData? capturedData2;

      client.fetchInfiniteQuery<String, Object, int>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data-1-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
      ).then((data) => capturedData1 = data);
      client.fetchInfiniteQuery<String, Object, int>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data-2-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
      ).then((data) => capturedData2 = data);
      async.elapse(const Duration(seconds: 1));

      expect(capturedData1, InfiniteData(['data-1-0'], [0]));
      expect(capturedData2, InfiniteData(['data-1-0'], [0]));
    }));
  });

  group('Method: prefetchInfiniteQuery', () {
    test(
        'SHOULD persist data to cache'
        '', withFakeAsync((async) {
      client.prefetchInfiniteQuery<String, Object, int>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        pages: 2,
      );
      async.elapse(const Duration(seconds: 2));

      expect(
        cache.get(const ['key'])!.state.data,
        InfiniteData(['data-0', 'data-1'], [0, 1]),
      );
    }));

    test(
        'SHOULD NOT throw '
        'WHEN fetch fails', withFakeAsync((async) {
      Object? capturedError;

      client.prefetchInfiniteQuery<String, Exception, int>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          throw Exception();
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
      ).catchError((e) {
        capturedError = e;
      });
      async.elapse(const Duration(seconds: 1));

      expect(capturedError, isNull);
      expect(cache.get(const ['key'])!.state.error, isA<Exception>());
    }));
  });

  group('Method: getInfiniteQueryData', () {
    test(
        'SHOULD return data '
        'WHEN query exists', withFakeAsync((async) {
      client.fetchInfiniteQuery<String, Object, int>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
      );
      async.elapse(const Duration(seconds: 1));

      final data = client.getInfiniteQueryData(const ['key']);

      expect(data, InfiniteData(['data-0'], [0]));
    }));

    test(
        'SHOULD return null '
        'WHEN query does not exist', withFakeAsync((async) {
      final data = client.getInfiniteQueryData(const ['key']);

      expect(data, isNull);
    }));

    test(
        'SHOULD return null '
        'WHEN query exists but has no data yet', withFakeAsync((async) {
      cache.build<InfiniteData<String, int>, Object>(QueryOptions(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return InfiniteData(['data'], [0]);
        },
      ));

      final data = client.getInfiniteQueryData(const ['key']);

      expect(data, isNull);
    }));

    test(
        'SHOULD return data from query matching by exact key'
        '', withFakeAsync((async) {
      client.fetchInfiniteQuery<String, Object, int>(
        const ['key', 1],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
      );
      async.elapse(const Duration(seconds: 1));

      // Should NOT match by key prefix
      expect(client.getInfiniteQueryData(const ['key']), isNull);
      // Should match exact key
      expect(
        client.getInfiniteQueryData(const ['key', 1]),
        InfiniteData(['data-0'], [0]),
      );
    }));

    test(
        'SHOULD NOT have type casting problems with error type'
        '', withFakeAsync((async) {
      client.prefetchInfiniteQuery<String, dynamic, int>(
        const ['dynamic'],
        (context) async => 'data-dynamic',
        initialPageParam: 0,
        nextPageParamBuilder: (data) => null,
      );
      client.prefetchInfiniteQuery<String, Object, int>(
        const ['Object'],
        (context) async => 'data-object',
        initialPageParam: 0,
        nextPageParamBuilder: (data) => null,
      );
      client.prefetchInfiniteQuery<String, Object?, int>(
        const ['Object?'],
        (context) async => 'data-object?',
        initialPageParam: 0,
        nextPageParamBuilder: (data) => null,
      );
      client.prefetchInfiniteQuery<String, Exception, int>(
        const ['Exception'],
        (context) async => 'data-exception',
        initialPageParam: 0,
        nextPageParamBuilder: (data) => null,
      );
      client.prefetchInfiniteQuery<String, Error, int>(
        const ['Error'],
        (context) async => 'data-error',
        initialPageParam: 0,
        nextPageParamBuilder: (data) => null,
      );
      client.prefetchInfiniteQuery<String, Null, int>(
        const ['Null'],
        (context) async => 'data-null',
        initialPageParam: 0,
        nextPageParamBuilder: (data) => null,
      );
      client.prefetchInfiniteQuery<String, Never, int>(
        const ['Never'],
        (context) async => 'data-never',
        initialPageParam: 0,
        nextPageParamBuilder: (data) => null,
      );
      async.flushMicrotasks();

      final dataDynamic =
          client.getInfiniteQueryData<String, int>(const ['dynamic']);
      final dataObject =
          client.getInfiniteQueryData<String, int>(const ['Object']);
      final dataObjectNullable =
          client.getInfiniteQueryData<String, int>(const ['Object?']);
      final dataException =
          client.getInfiniteQueryData<String, int>(const ['Exception']);
      final dataError =
          client.getInfiniteQueryData<String, int>(const ['Error']);
      final dataNull = client.getInfiniteQueryData<String, int>(const ['Null']);
      final dataNever =
          client.getInfiniteQueryData<String, int>(const ['Never']);

      expect(dataDynamic, InfiniteData(['data-dynamic'], [0]));
      expect(dataObject, InfiniteData(['data-object'], [0]));
      expect(dataObjectNullable, InfiniteData(['data-object?'], [0]));
      expect(dataException, InfiniteData(['data-exception'], [0]));
      expect(dataError, InfiniteData(['data-error'], [0]));
      expect(dataNull, InfiniteData(['data-null'], [0]));
      expect(dataNever, InfiniteData(['data-never'], [0]));
    }));
  });
}
