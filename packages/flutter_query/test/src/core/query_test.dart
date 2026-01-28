import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_query/src/core/core.dart';
import '../../utils.dart';

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
    client.clear();
  });

  group('Constructor: new', () {
    test(
        'SHOULD NOT be cached'
        '', withFakeAsync((async) {
      Query<String, Object>(client, const ['key']);

      expect(client.cache.get(const ['key']), isNull);
    }));
  });

  group('Constructor: cached', () {
    test(
        'SHOULD be cached'
        '', withFakeAsync((async) {
      Query<String, Object>.cached(client, const ['key']);

      expect(client.cache.get(const ['key']), isNotNull);
    }));

    test(
        'SHOULD return same query for same key'
        '', withFakeAsync((async) {
      final query1 = Query<String, Object>.cached(client, const ['key']);
      final query2 = Query<String, Object>.cached(client, const ['key']);
      final query3 = Query<String, Object>.cached(client, const ['other']);

      expect(query1, same(query2));
      expect(query2, isNot(same(query3)));
      expect(query3, isNot(same(query1)));
    }));

    test(
        'SHOULD use client default for retry '
        'WHEN gcDuration == null', withFakeAsync((async) {
      client.defaultQueryOptions = DefaultQueryOptions(
        retry: (count, error) {
          if (count < 2) {
            return const Duration(seconds: 1);
          }
          return null;
        },
      );

      final query = Query<String, Object>.cached(client, const ['key']);

      query.fetch((context) async {
        throw Exception();
      }).ignore();

      async.flushMicrotasks();
      expect(query.state.failureCount, 1);
      async.elapse(const Duration(seconds: 1));
      expect(query.state.failureCount, 2);
      async.elapse(const Duration(seconds: 1));
      expect(query.state.failureCount, 3);

      // Should NOT have retried further
      async.elapse(const Duration(seconds: 1));
      expect(query.state.failureCount, 3);
    }));

    test(
        'SHOULD use client default for gc duration '
        'WHEN gcDuration == null', withFakeAsync((async) {
      client.defaultQueryOptions = const DefaultQueryOptions(
        gcDuration: GcDuration(minutes: 10),
      );

      Query<String, Object>.cached(client, const ['key']);

      async.elapse(const Duration(minutes: 9, seconds: 59));
      expect(client.cache.get(const ['key']), isNotNull);

      async.elapse(const Duration(seconds: 1));
      expect(client.cache.get(const ['key']), isNull);
    }));

    test(
        'SHOULD take precedence over client default for gc duration '
        'WHEN gcDuration != null', withFakeAsync((async) {
      client.defaultQueryOptions = const DefaultQueryOptions(
        gcDuration: GcDuration(minutes: 10),
      );

      Query<String, Object>.cached(
        client,
        const ['key'],
        gcDuration: const GcDuration(minutes: 3),
      );

      async.elapse(const Duration(minutes: 2, seconds: 59));
      expect(client.cache.get(const ['key']), isNotNull);

      async.elapse(const Duration(seconds: 1));
      expect(client.cache.get(const ['key']), isNull);
    }));

    test(
        'SHOULD persist seed to cache '
        'WHEN seed != null', withFakeAsync((async) {
      Query<String, Object>.cached(
        client,
        const ['key'],
        seed: 'data-seed',
      );

      final query = client.cache.get(const ['key'])!;
      expect(query.state.data, 'data-seed');
      expect(query.state.dataUpdatedAt, clock.now());
      expect(query.state.dataUpdateCount, 0);
    }));

    test(
        'SHOULD persist seed to cache with seedUpdatedAt '
        'WHEN seedUpdatedAt != null', withFakeAsync((async) {
      Query<String, Object>.cached(
        client,
        const ['key'],
        seed: 'data-seed',
        seedUpdatedAt: clock.minutesAgo(15),
      );

      final query = client.cache.get(const ['key'])!;
      expect(query.state.data, 'data-seed');
      expect(query.state.dataUpdatedAt, clock.minutesAgo(15));
      expect(query.state.dataUpdateCount, 0);
    }));

    test(
        'SHOULD NOT persist anything to cache '
        'WHEN seed != null && seedUpdatedAt != null', withFakeAsync((async) {
      Query<String, Object>.cached(
        client,
        const ['key'],
        seedUpdatedAt: clock.minutesAgo(15),
      );

      final query = client.cache.get(const ['key'])!;
      expect(query.state.data, isNull);
      expect(query.state.dataUpdatedAt, isNull);
      expect(query.state.dataUpdateCount, 0);
    }));
  });

  group('Method: setSeed', () {
    test(
        'SHOULD start with seed data'
        '', withFakeAsync((async) {
      Object expectedSeed = Object();

      final query1 = Query<Object, Object>(client, const ['key-1'])
        ..setSeed(expectedSeed);

      expect(query1.state.status, QueryStatus.success);
      expect(query1.state.data, same(expectedSeed));
      expect(query1.state.dataUpdatedAt, clock.now());

      final query2 = Query<Object, Object>(client, const ['key-2'])
        ..setSeed(expectedSeed, clock.minutesAgo(15));

      expect(query2.state.status, QueryStatus.success);
      expect(query2.state.data, same(expectedSeed));
      expect(query2.state.dataUpdatedAt, clock.minutesAgo(15));
    }));
  });

  group('Method: setData', () {
    test(
        'SHOULD set data and update state to success'
        '', withFakeAsync((async) {
      final expectedData = Object();

      final query = Query<Object, Object>(client, const ['key']);

      final returnedData = query.setData(expectedData);

      expect(returnedData, same(expectedData));
      expect(query.state.status, QueryStatus.success);
      expect(query.state.fetchStatus, FetchStatus.idle);
      expect(query.state.data, same(expectedData));
      expect(query.state.dataUpdatedAt, clock.now());
      expect(query.state.dataUpdateCount, 1);
      expect(query.state.error, isNull);
      expect(query.state.errorUpdatedAt, isNull);
      expect(query.state.errorUpdateCount, 0);
      expect(query.state.failureCount, 0);
      expect(query.state.failureReason, isNull);
      expect(query.state.isInvalidated, isFalse);
      expect(query.state.isActive, isFalse);
      expect(query.state.meta, const {});
    }));

    test(
        'SHOULD use provided updatedAt'
        '', withFakeAsync((async) {
      final query = Query<String, Object>(client, const ['key']);

      query.setData('data', updatedAt: clock.minutesAgo(30));

      expect(query.state.dataUpdatedAt, clock.minutesAgo(30));
    }));

    test(
        'SHOULD increment dataUpdateCount on each call'
        '', withFakeAsync((async) {
      final query = Query<String, Object>(client, const ['key']);

      expect(query.state.dataUpdateCount, 0);

      query.setData('data-1');
      expect(query.state.dataUpdateCount, 1);

      query.setData('data-2');
      expect(query.state.dataUpdateCount, 2);

      // Should increment even for same data
      query.setData('data-2');
      expect(query.state.dataUpdateCount, 3);
    }));

    test(
        'SHOULD reset error state'
        '', withFakeAsync((async) {
      final query = Query<String, Exception>(client, const ['key']);

      query.fetch((context) async {
        throw Exception('error');
      }).ignore();

      async.flushMicrotasks();
      expect(query.state.status, QueryStatus.error);
      expect(query.state.error, isA<Exception>());
      expect(query.state.errorUpdatedAt, isNotNull);
      expect(query.state.errorUpdateCount, 1);

      // Now set data
      query.setData('data');
      expect(query.state.status, QueryStatus.success);
      expect(query.state.error, isNull);
      // errorUpdatedAt and errorUpdateCount are preserved
      expect(query.state.errorUpdatedAt, isNotNull);
      expect(query.state.errorUpdateCount, 1);
    }));

    test(
        'SHOULD reset failureCount and failureReason'
        '', withFakeAsync((async) {
      final query = Query<String, Object>(client, const ['key']);

      query.fetch(
        (context) async {
          throw Exception();
        },
        retry: (count, error) {
          if (count < 2) return const Duration(seconds: 1);
          return null;
        },
      ).ignore();

      async.elapse(const Duration(seconds: 2));
      // Should have fetched once and retried 2 times
      expect(query.state.failureCount, 3);
      expect(query.state.failureReason, isNotNull);

      query.setData('data');
      expect(query.state.failureCount, 0);
      expect(query.state.failureReason, isNull);
    }));

    test(
        'SHOULD reset isInvalidated to false'
        '', withFakeAsync((async) {
      final query = Query<String, Object>(client, const ['key']);

      query.invalidate();
      expect(query.state.isInvalidated, isTrue);

      query.setData('data');
      expect(query.state.isInvalidated, isFalse);
    }));
  });

  group('Method: fetch', () {
    test(
        'SHOULD succeed and return data'
        '', withFakeAsync((async) {
      Object expectedData = Object();
      Object? capturedData;

      final query = Query<Object, Object>(client, const ['key']);

      query.fetch((context) async {
        await Future.delayed(const Duration(seconds: 1));
        return expectedData;
      }).then((data) => capturedData = data);

      expect(query.state.status, QueryStatus.pending);
      expect(query.state.fetchStatus, FetchStatus.fetching);
      expect(query.state.data, isNull);
      expect(query.state.dataUpdatedAt, isNull);
      expect(query.state.dataUpdateCount, 0);
      expect(capturedData, isNull);

      async.elapse(const Duration(seconds: 1));

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
      Exception expectedError = Exception();
      Object? capturedError;

      final query = Query<String, Exception>(client, const ['key']);

      query.fetch((context) async {
        await Future.delayed(const Duration(seconds: 1));
        throw expectedError;
      }).catchError((error) {
        capturedError = error;
        return 'error';
      });

      expect(query.state.status, QueryStatus.pending);
      expect(query.state.fetchStatus, FetchStatus.fetching);
      expect(query.state.error, isNull);
      expect(query.state.errorUpdatedAt, isNull);
      expect(query.state.errorUpdateCount, 0);
      expect(capturedError, isNull);

      async.elapse(const Duration(seconds: 1));

      expect(query.state.status, QueryStatus.error);
      expect(query.state.fetchStatus, FetchStatus.idle);
      expect(query.state.error, same(expectedError));
      expect(query.state.errorUpdatedAt, clock.now());
      expect(query.state.errorUpdateCount, 1);
      expect(capturedError, same(expectedError));
    }));

    test(
        'SHOULD reset invalidation status on success'
        '', withFakeAsync((async) {
      final query = Query<String, Object>(client, const ['key']);
      expect(query.state.isInvalidated, isFalse);

      query.invalidate();
      expect(query.state.isInvalidated, isTrue);

      query.fetch((context) async {
        await Future.delayed(const Duration(seconds: 1));
        return 'data';
      });
      async.elapse(const Duration(seconds: 1));
      expect(query.state.status, QueryStatus.success);
      expect(query.state.isInvalidated, isFalse);
    }));

    test(
        'SHOULD pass context to queryFn'
        '', withFakeAsync((async) {
      QueryFunctionContext? capturedContext;

      final query = Query<String, Object>(client, const ['key', 123]);

      query.fetch(
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          capturedContext = context;
          return 'data';
        },
        meta: {'key': 'value'},
      );
      async.elapse(const Duration(seconds: 1));

      expect(capturedContext, isNotNull);
      expect(capturedContext!.queryKey, const ['key', 123]);
      expect(capturedContext!.client, same(client));
      expect(capturedContext!.signal, isA<AbortSignal>());
      expect(capturedContext!.meta, {'key': 'value'});
    }));

    test(
        'SHOULD pass deep-merged meta through context to queryFn'
        '', withFakeAsync((async) {
      Map<String, dynamic>? capturedMeta;

      final query = Query<String, Object>.cached(client, const ['key']);

      Map<String, dynamic>? captureMeta([Map<String, dynamic>? meta]) {
        query.fetch(
          (context) async {
            capturedMeta = context.meta;
            return 'data';
          },
          meta: meta,
        );
        async.flushMicrotasks();
        return capturedMeta;
      }

      expect(captureMeta(), <String, dynamic>{});

      expect(captureMeta({'key': 'value'}), {'key': 'value'});

      final observer1 = QueryObserver<String, Object>(
        client,
        QueryOptions(
          const ['key'],
          (context) async {
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
      async.flushMicrotasks();

      expect(capturedMeta, {
        'observer': 1,
        'extra-1': 'value-1',
        'nested': {
          'extra-1': 'value-1',
        },
      });

      final observer2 = QueryObserver<String, Object>(
        client,
        QueryOptions(
          const ['key'],
          (context) async {
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
      async.flushMicrotasks();

      expect(capturedMeta, {
        'observer': 2,
        'extra-1': 'value-1',
        'extra-2': 'value-2',
        'nested': {
          'extra-1': 'value-1',
          'extra-2': 'value-2',
        },
      });

      observer2.onUnmount();

      expect(captureMeta(), {
        'observer': 1,
        'extra-1': 'value-1',
        'nested': {
          'extra-1': 'value-1',
        },
      });

      observer1.onUnmount();

      expect(captureMeta(), <String, dynamic>{});
    }));

    test(
        'SHOULD schedule garbage collection after completion'
        'WHEN gcDuration != null', withFakeAsync((async) {
      final query = Query<String, Object>.cached(client, const ['key']);

      query.fetch(
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data';
        },
        gcDuration: const GcDuration(minutes: 3),
      );
      async.elapse(const Duration(seconds: 1));
      // Garbage collcetion timer starts

      async.elapse(const Duration(minutes: 2, seconds: 59));
      expect(client.cache.get(const ['key']), isNotNull);

      async.elapse(const Duration(seconds: 1));
      expect(client.cache.get(const ['key']), isNull);
    }));

    test(
        'SHOULD increment failureCount on each failed attempt'
        '', withFakeAsync((async) {
      final query = Query<String, Object>(client, const ['key']);

      query.fetch(
        (context) async {
          throw Exception();
        },
        retry: (count, error) {
          if (count < 2) {
            return const Duration(seconds: 1);
          }
          return null;
        },
      ).ignore();

      async.flushMicrotasks();
      expect(query.state.failureCount, 1);
      async.elapse(const Duration(seconds: 1));
      expect(query.state.failureCount, 2);
      async.elapse(const Duration(seconds: 1));
      expect(query.state.failureCount, 3);
    }));

    test(
        'SHOULD update failureReason on each failed attempt'
        '', withFakeAsync((async) {
      var attempts = 0;
      final query = Query<Never, String>(client, const ['key']);

      query.fetch(
        (context) async {
          throw 'error-${++attempts}';
        },
        retry: (count, error) {
          if (count < 2) {
            return const Duration(seconds: 1);
          }
          return null;
        },
      ).ignore();

      async.flushMicrotasks();
      expect(query.state.failureReason, 'error-1');
      async.elapse(const Duration(seconds: 1));
      expect(query.state.failureReason, 'error-2');
      async.elapse(const Duration(seconds: 1));
      expect(query.state.failureReason, 'error-3');
    }));

    test(
        'SHOULD reset failureCount to 0 on each fetch attempt'
        '', withFakeAsync((async) {
      final query = Query<String, Object>(client, const ['key']);

      query.fetch(
        (context) async {
          throw Exception();
        },
        retry: (count, error) {
          if (count < 1) {
            return const Duration(seconds: 1);
          }
          return null;
        },
      ).ignore();

      async.flushMicrotasks();
      expect(query.state.failureCount, 1);
      async.elapse(const Duration(seconds: 1));
      expect(query.state.failureCount, 2);

      query.fetch((context) async {
        throw Exception();
      }).ignore();

      expect(query.state.failureCount, 0);
    }));

    test(
        'SHOULD return same Future (deduplication) '
        'WHEN cancelRefetch == false', withFakeAsync((async) {
      var fetches = 0;
      String? capturedResult1;
      String? capturedResult2;

      final query = Query<String, Object>(client, const ['key']);

      Future<String> queryFn(QueryFunctionContext context) async {
        Future.delayed(const Duration(seconds: 1));
        fetches++;
        return 'data-$fetches';
      }

      query.fetch(queryFn).then((data) => capturedResult1 = data);
      query
          .fetch(queryFn, cancelRefetch: false)
          .then((data) => capturedResult2 = data);
      async.elapse(const Duration(seconds: 1));

      expect(fetches, 1);
      expect(capturedResult1, 'data-1');
      expect(capturedResult2, 'data-1');
    }));

    test(
        'SHOULD piggyback cancelled fetch onto new fetch result '
        'WHEN cancelRefetch == true', withFakeAsync((async) {
      var fetches = 0;
      String? capturedResult1;
      String? capturedResult2;

      final query = Query<String, Object>(client, const ['key']);

      Future<String> queryFn(QueryFunctionContext context) async {
        await Future.any([
          Future.delayed(const Duration(seconds: 1)),
          context.signal.whenAbort,
        ]);
        fetches++;
        context.signal.throwIfAborted();
        return 'data-$fetches';
      }

      // Establish initial data so cancelRefetch can work
      query.fetch(queryFn);
      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);
      expect(query.state.data, 'data-1');

      query.fetch(queryFn).then((data) => capturedResult1 = data);
      query
          .fetch(queryFn, cancelRefetch: true)
          .then((data) => capturedResult2 = data);
      async.elapse(const Duration(seconds: 1));

      expect(fetches, 3);
      expect(capturedResult1, 'data-3');
      expect(capturedResult2, 'data-3');
    }));
  });

  group('Method: cancel', () {
    test(
        'SHOULD cancel in-progress fetch'
        '', withFakeAsync((async) {
      var isAborted = false;

      final query = Query<String, Object>(client, const ['key']);

      query.fetch((context) async {
        await Future.any([
          Future.delayed(const Duration(seconds: 1)),
          context.signal.whenAbort,
        ]);
        isAborted = context.signal.isAborted;
        context.signal.throwIfAborted();
        return 'data';
      }).ignore();

      expect(query.state.fetchStatus, FetchStatus.fetching);
      expect(isAborted, isFalse);

      async.elapse(const Duration(milliseconds: 500));
      query.cancel();
      async.flushMicrotasks();

      expect(query.state.fetchStatus, FetchStatus.idle);
      expect(isAborted, isTrue);
    }));

    test(
        'SHOULD make fetch return prior data'
        '', withFakeAsync((async) {
      String? capturedData;

      final query = Query<String, Object>(client, const ['key']);
      query.setData('data');
      query.fetch((context) async {
        await Future.any([
          Future.delayed(const Duration(seconds: 1)),
          context.signal.whenAbort,
        ]);
        context.signal.throwIfAborted();
        return 'data-updated';
      }).then((data) => capturedData = data);
      query.cancel();
      async.flushMicrotasks();

      expect(capturedData, 'data');
    }));

    test(
        'SHOULD revert to previous state '
        'WHEN revert == true', withFakeAsync((async) {
      final query = Query<String, Object>(client, const ['key']);

      query.fetch(
        (context) async {
          await Future.any([
            Future.delayed(const Duration(seconds: 1)),
            context.signal.whenAbort,
          ]);
          context.signal.throwIfAborted();
          throw Exception();
        },
        retry: (count, error) => const Duration(seconds: 1),
      ).ignore();
      async.elapse(const Duration(seconds: 1));

      expect(query.state.fetchStatus, FetchStatus.fetching);
      expect(query.state.failureCount, 1);
      expect(query.state.failureReason, isA<Exception>());

      query.cancel(revert: true);
      async.flushMicrotasks();

      expect(query.state.fetchStatus, FetchStatus.idle);
      expect(query.state.failureCount, 0);
      expect(query.state.failureReason, isNull);
    }));

    test(
        'SHOULD preserve current state '
        'WHEN revert == false', withFakeAsync((async) {
      final query = Query<String, Object>(client, const ['key']);

      query.fetch(
        (context) async {
          await Future.any([
            Future.delayed(const Duration(seconds: 1)),
            context.signal.whenAbort,
          ]);
          context.signal.throwIfAborted();
          throw Exception();
        },
        retry: (count, error) => const Duration(milliseconds: 100),
      ).ignore();
      async.elapse(const Duration(seconds: 1));

      expect(query.state.failureCount, 1);
      expect(query.state.failureReason, isA<Exception>());

      query.cancel(revert: false);
      async.flushMicrotasks();

      expect(query.state.failureCount, 1);
      expect(query.state.failureReason, isA<Exception>());
    }));

    test(
        'SHOULD NOT make fetch throw '
        'WHEN silent == true', withFakeAsync((async) {
      Object? capturedFetchError;
      Object? capturedCancelError;

      final query = Query<String, Object>(client, const ['key']);

      query.fetch((context) async {
        await Future.any([
          Future.delayed(const Duration(seconds: 1)),
          context.signal.whenAbort,
        ]);
        context.signal.throwIfAborted();
        return 'data';
      }).catchError((e) {
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
        'SHOULD make fetch throw AbortedException '
        'WHEN silent == false', withFakeAsync((async) {
      Object? capturedFetchError;
      Object? capturedCancelError;

      final query = Query<String, Object>(client, const ['key']);

      query.fetch((context) async {
        await Future.any([
          Future.delayed(const Duration(seconds: 1)),
          context.signal.whenAbort,
        ]);
        context.signal.throwIfAborted();
        return 'data';
      }).catchError((e) {
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
        'SHOULD complete immediately '
        'WHEN there is no fetch in progress', withFakeAsync((async) {
      final query = Query<String, Object>(client, const ['key']);

      expectLater(query.cancel(), completes);

      async.flushMicrotasks();
    }));

    test(
        'SHOULD complete immediately '
        'WHEN queryFn does not check abort signal', withFakeAsync((async) {
      final query = Query<String, Object>(client, const ['key']);

      query.fetch((context) async {
        await Future.delayed(const Duration(seconds: 3));
        return 'data';
      }).ignore();

      // cancel() completes immediately by settling the promise,
      // even though the underlying queryFn might still be running
      expectLater(query.cancel(), completes);

      async.flushMicrotasks();
    }));

    test(
        'SHOULD complete immediately '
        'WHEN waiting for retry delay', withFakeAsync((async) {
      final query = Query<String, Object>(client, const ['key']);

      query.fetch(
        (context) async {
          context.signal.throwIfAborted();
          throw Exception();
        },
        retry: (count, error) => const Duration(seconds: 10),
      ).ignore();
      async.flushMicrotasks();

      // Should have failed once and been waiting for retry delay
      expect(query.state.failureCount, 1);
      expect(query.state.fetchStatus, FetchStatus.fetching);

      // Should complete immediately
      expectLater(query.cancel(), completes);
      async.flushMicrotasks();
      expect(query.state.fetchStatus, FetchStatus.idle);
    }));
  });

  group('Extension: QueryExt.matches', () {
    test(
        'SHOULD match exact key '
        'WHEN exact == true', () {
      final query = Query<String, Object>(client, const ['users', 1]);

      expect(query.matches(const ['users', 1], exact: true), isTrue);
      expect(query.matches(const ['users'], exact: true), isFalse);
    });

    test(
        'SHOULD match key by prefix'
        'WHEN exact == false', () {
      final query = Query<String, Object>(client, const ['users', 1]);

      expect(query.matches(const ['users', 1], exact: false), isTrue);
      expect(query.matches(const ['users'], exact: false), isTrue);
      expect(query.matches(const ['users', 1, 'posts'], exact: false), isFalse);
    });
  });

  group('Extension: QueryExt.matchesWhere', () {
    test(
        'SHOULD match by predicate'
        '', () {
      final query = Query<String, Object>(client, const ['users']);

      expect(query.matchesWhere((key, state) => key[0] == 'users'), isTrue);
      expect(query.matchesWhere((key, state) => key[0] == 'posts'), isFalse);
    });
  });
}
