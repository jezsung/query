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
    client.clear();
  });

  void Function() withFakeAsync(void Function(FakeAsync fakeTime) testBody) {
    return () => fakeAsync(testBody);
  }

  test(
      'SHOULD succeed fetching initial page'
      '', withFakeAsync((async) {
    final observer = InfiniteQueryObserver<String, Object, int>(
      client,
      InfiniteQueryObserverOptions(
        const ['test'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'page-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
      ),
    );
    addTearDown(observer.dispose);

    expect(observer.result.status, QueryStatus.pending);
    expect(observer.result.fetchStatus, FetchStatus.fetching);
    expect(observer.result.data, isNull);
    expect(observer.result.dataUpdatedAt, isNull);
    expect(observer.result.dataUpdateCount, 0);

    async.elapse(const Duration(seconds: 1));

    expect(observer.result.status, QueryStatus.success);
    expect(observer.result.fetchStatus, FetchStatus.idle);
    expect(
      observer.result.data,
      InfiniteData(['page-0'], [0]),
    );
    expect(observer.result.dataUpdatedAt, clock.now());
    expect(observer.result.dataUpdateCount, 1);
  }));

  test(
      'SHOULD fail fetching initial page'
      '', withFakeAsync((async) {
    final expectedError = Exception();

    final observer = InfiniteQueryObserver<String, Object, int>(
      client,
      InfiniteQueryObserverOptions(
        const ['test'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          throw expectedError;
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
      ),
    );
    addTearDown(observer.dispose);

    expect(observer.result.status, QueryStatus.pending);
    expect(observer.result.fetchStatus, FetchStatus.fetching);
    expect(observer.result.error, isNull);
    expect(observer.result.errorUpdatedAt, isNull);
    expect(observer.result.errorUpdateCount, 0);

    async.elapse(const Duration(seconds: 1));

    expect(observer.result.status, QueryStatus.error);
    expect(observer.result.fetchStatus, FetchStatus.idle);
    expect(observer.result.error, same(expectedError));
    expect(observer.result.errorUpdatedAt, clock.now());
    expect(observer.result.errorUpdateCount, 1);
  }));

  group('fetchNextPage', () {
    test(
        'SHOULD succeed fetching next page'
        '', withFakeAsync((async) {
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));

      observer.fetchNextPage();

      expect(observer.result.status, QueryStatus.success);
      expect(observer.result.fetchStatus, FetchStatus.fetching);
      expect(
        observer.result.data,
        InfiniteData(['page-0'], [0]),
      );
      expect(observer.result.dataUpdatedAt, clock.now());
      expect(observer.result.dataUpdateCount, 1);

      async.elapse(const Duration(seconds: 1));

      expect(observer.result.status, QueryStatus.success);
      expect(observer.result.fetchStatus, FetchStatus.idle);
      expect(
        observer.result.data,
        InfiniteData(['page-0', 'page-1'], [0, 1]),
      );
      expect(observer.result.dataUpdatedAt, clock.now());
      expect(observer.result.dataUpdateCount, 2);
    }));

    test(
        'SHOULD fail fetching next page'
        '', withFakeAsync((async) {
      final expectedError = Exception();

      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            if (context.pageParam == 0) {
              return 'page-${context.pageParam}';
            } else {
              throw expectedError;
            }
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));

      observer.fetchNextPage();

      expect(observer.result.status, QueryStatus.success);
      expect(observer.result.fetchStatus, FetchStatus.fetching);
      expect(
        observer.result.data,
        InfiniteData(['page-0'], [0]),
      );
      expect(observer.result.dataUpdatedAt, clock.now());
      expect(observer.result.dataUpdateCount, 1);
      expect(observer.result.error, isNull);
      expect(observer.result.errorUpdatedAt, isNull);
      expect(observer.result.errorUpdateCount, 0);

      async.elapse(const Duration(seconds: 1));

      expect(observer.result.status, QueryStatus.error);
      expect(observer.result.fetchStatus, FetchStatus.idle);
      expect(
        observer.result.data,
        InfiniteData(['page-0'], [0]),
      );
      expect(observer.result.dataUpdatedAt, clock.secondsAgo(1));
      expect(observer.result.dataUpdateCount, 1);
      expect(observer.result.error, same(expectedError));
      expect(observer.result.errorUpdatedAt, clock.now());
      expect(observer.result.errorUpdateCount, 1);
    }));

    test(
        'SHOULD NOT fetch more pages '
        'WHEN hasNextPage is false', withFakeAsync((async) {
      var fetches = 0;

      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => null, // No more pages
        ),
      );
      addTearDown(observer.dispose);
      async.elapse(const Duration(seconds: 1));

      expect(fetches, 1);
      expect(observer.result.hasNextPage, isFalse);

      // Try to fetch next page
      observer.fetchNextPage();
      async.elapse(const Duration(seconds: 1));

      // Should NOT have fetched again
      expect(fetches, 1);
    }));

    test(
        'SHOULD respect maxPages limit'
        '', withFakeAsync((async) {
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          maxPages: 2,
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));
      expect(
        observer.result.data,
        InfiniteData(['page-0'], [0]),
      );

      observer.fetchNextPage();
      async.elapse(const Duration(seconds: 1));
      expect(
        observer.result.data,
        InfiniteData(['page-0', 'page-1'], [0, 1]),
      );

      observer.fetchNextPage();
      async.elapse(const Duration(seconds: 1));
      // Should still have 2 pages, first page dropped
      expect(
        observer.result.data,
        InfiniteData(['page-1', 'page-2'], [1, 2]),
      );
    }));

    test(
        'SHOULD throw '
        'WHEN throwOnError is true', withFakeAsync((async) {
      final expectedError = Exception();

      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            if (context.pageParam == 0) {
              return 'page-${context.pageParam}';
            } else {
              throw expectedError;
            }
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));

      expectLater(
        observer.fetchNextPage(throwOnError: true),
        throwsA(same(expectedError)),
      );

      async.elapse(const Duration(seconds: 1));
    }));

    test(
        'SHOULD NOT throw '
        'WHEN throwOnError is false', withFakeAsync((async) {
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            if (context.pageParam == 0) {
              return 'page-${context.pageParam}';
            } else {
              throw Exception();
            }
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));

      expectLater(
        observer.fetchNextPage(throwOnError: false),
        completes,
      );

      async.elapse(const Duration(seconds: 1));
    }));
  });

  group('fetchPreviousPage', () {
    test(
        'SHOULD succeed fetching previous page'
        '', withFakeAsync((async) {
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 5,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          prevPageParamBuilder: (data) => data.pageParams.first - 1,
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));

      observer.fetchPreviousPage();

      expect(observer.result.status, QueryStatus.success);
      expect(observer.result.fetchStatus, FetchStatus.fetching);
      expect(
        observer.result.data,
        InfiniteData(['page-5'], [5]),
      );
      expect(observer.result.dataUpdatedAt, clock.now());
      expect(observer.result.dataUpdateCount, 1);

      async.elapse(const Duration(seconds: 1));

      expect(observer.result.status, QueryStatus.success);
      expect(observer.result.fetchStatus, FetchStatus.idle);
      expect(
        observer.result.data,
        InfiniteData(['page-4', 'page-5'], [4, 5]),
      );
      expect(observer.result.dataUpdatedAt, clock.now());
      expect(observer.result.dataUpdateCount, 2);
    }));

    test(
        'SHOULD fail fetching previous page'
        '', withFakeAsync((async) {
      final expectedError = Exception();

      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            if (context.pageParam == 5) {
              return 'page-${context.pageParam}';
            } else {
              throw expectedError;
            }
          },
          initialPageParam: 5,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          prevPageParamBuilder: (data) => data.pageParams.first - 1,
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));

      observer.fetchPreviousPage();

      expect(observer.result.status, QueryStatus.success);
      expect(observer.result.fetchStatus, FetchStatus.fetching);
      expect(
        observer.result.data,
        InfiniteData(['page-5'], [5]),
      );
      expect(observer.result.dataUpdatedAt, clock.now());
      expect(observer.result.dataUpdateCount, 1);
      expect(observer.result.error, isNull);
      expect(observer.result.errorUpdatedAt, isNull);
      expect(observer.result.errorUpdateCount, 0);

      async.elapse(const Duration(seconds: 1));

      expect(observer.result.status, QueryStatus.error);
      expect(observer.result.fetchStatus, FetchStatus.idle);
      expect(
        observer.result.data,
        InfiniteData(['page-5'], [5]),
      );
      expect(observer.result.dataUpdatedAt, clock.secondsAgo(1));
      expect(observer.result.dataUpdateCount, 1);
      expect(observer.result.error, same(expectedError));
      expect(observer.result.errorUpdatedAt, clock.now());
      expect(observer.result.errorUpdateCount, 1);
    }));

    test(
        'SHOULD NOT fetch more pages '
        'WHEN hasPreviousPage is false', withFakeAsync((async) {
      var fetches = 0;

      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          prevPageParamBuilder: (data) => null, // No previous pages
        ),
      );
      addTearDown(observer.dispose);
      async.elapse(const Duration(seconds: 1));

      expect(fetches, 1);
      expect(observer.result.hasPreviousPage, isFalse);

      // Try to fetch previous page
      observer.fetchPreviousPage();
      async.elapse(const Duration(seconds: 1));

      // Should NOT have fetched again
      expect(fetches, 1);
    }));

    test(
        'SHOULD respect maxPages limit'
        '', withFakeAsync((async) {
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 5,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          prevPageParamBuilder: (data) => data.pageParams.first - 1,
          maxPages: 2,
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));
      expect(
        observer.result.data,
        InfiniteData(['page-5'], [5]),
      );

      observer.fetchPreviousPage();
      async.elapse(const Duration(seconds: 1));
      expect(
        observer.result.data,
        InfiniteData(['page-4', 'page-5'], [4, 5]),
      );

      observer.fetchPreviousPage();
      async.elapse(const Duration(seconds: 1));
      // Should still have 2 pages, last page dropped
      expect(
        observer.result.data,
        InfiniteData(['page-3', 'page-4'], [3, 4]),
      );
    }));

    test(
        'SHOULD throw '
        'WHEN throwOnError is true', withFakeAsync((async) {
      final expectedError = Exception();

      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            if (context.pageParam == 5) {
              return 'page-${context.pageParam}';
            } else {
              throw expectedError;
            }
          },
          initialPageParam: 5,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          prevPageParamBuilder: (data) => data.pageParams.first - 1,
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));

      expectLater(
        observer.fetchPreviousPage(throwOnError: true),
        throwsA(same(expectedError)),
      );

      async.elapse(const Duration(seconds: 1));
    }));

    test(
        'SHOULD NOT throw '
        'WHEN throwOnError is false', withFakeAsync((async) {
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            if (context.pageParam == 5) {
              return 'page-${context.pageParam}';
            } else {
              throw Exception();
            }
          },
          initialPageParam: 5,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          prevPageParamBuilder: (data) => data.pageParams.first - 1,
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));

      expectLater(
        observer.fetchPreviousPage(throwOnError: false),
        completes,
      );

      async.elapse(const Duration(seconds: 1));
    }));
  });

  group('refetch', () {
    test(
        'SHOULD refetch all existing pages sequentially'
        '', withFakeAsync((async) {
      var fetches = 0;

      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'page-${context.pageParam}:fetches-$fetches';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);

      observer.fetchNextPage();
      async.elapse(const Duration(seconds: 1));
      expect(fetches, 2);
      expect(
        observer.result.data,
        InfiniteData(
          ['page-0:fetches-1', 'page-1:fetches-2'],
          [0, 1],
        ),
      );

      // Refetch all pages
      observer.refetch();
      async.elapse(const Duration(seconds: 1));

      // First page refetched, still fetching second page
      expect(fetches, 3);
      expect(observer.result.isFetching, isTrue);
      expect(
        observer.result.data,
        InfiniteData(
          ['page-0:fetches-1', 'page-1:fetches-2'],
          [0, 1],
        ),
      );

      async.elapse(const Duration(seconds: 1));

      // All pages refetched
      expect(fetches, 4);
      expect(observer.result.isFetching, isFalse);
      expect(
        observer.result.data,
        InfiniteData(
          ['page-0:fetches-3', 'page-1:fetches-4'],
          [0, 1],
        ),
      );
    }));

    test(
        'SHOULD NOT throw error '
        'WHEN throwOnError == false', withFakeAsync((async) {
      var fetches = 0;
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            if (fetches > 1) {
              throw Exception();
            }
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          retry: (_, __) => null,
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));

      expectLater(
        observer.refetch(throwOnError: false),
        completes,
      );

      async.elapse(const Duration(seconds: 1));
    }));

    test(
        'SHOULD throw error '
        'WHEN throwOnError == true', withFakeAsync((async) {
      var fetches = 0;
      final expectedError = Exception();
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            if (fetches > 1) {
              throw expectedError;
            }
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          retry: (_, __) => null,
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));

      expectLater(
        observer.refetch(throwOnError: true),
        throwsA(same(expectedError)),
      );

      async.elapse(const Duration(seconds: 1));
    }));
  });

  group('updateOptions', () {
    test(
        'SHOULD switch to new query '
        'WHEN queryKey changes', withFakeAsync((async) {
      var fetches = 0;
      final fetchedKeys = <List<Object?>>[];

      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['key1'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            fetchedKeys.add(context.queryKey);
            return 'page';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (_) => null,
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);
      expect(fetchedKeys.last, ['key1']);

      // Update to new key
      observer.updateOptions(InfiniteQueryObserverOptions(
        const ['key2'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          fetches++;
          fetchedKeys.add(context.queryKey);
          return 'page';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (_) => null,
      ));

      async.elapse(const Duration(seconds: 1));

      expect(fetches, 2);
      expect(fetchedKeys.last, ['key2']);
    }));

    test(
        'SHOULD start fetching '
        'WHEN enabled changes from false to true', withFakeAsync((async) {
      var fetches = 0;

      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['key'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'page';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (_) => null,
          enabled: false,
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 0);

      // Enable the query
      observer.updateOptions(InfiniteQueryObserverOptions(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          fetches++;
          return 'page';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (_) => null,
        enabled: true,
      ));

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);
    }));

    test(
        'SHOULD NOT refetch '
        'WHEN options are unchanged', withFakeAsync((async) {
      var fetches = 0;

      Future<String> queryFn(InfiniteQueryFunctionContext<int> context) async {
        await Future.delayed(const Duration(seconds: 1));
        fetches++;
        return 'page';
      }

      Null nextPageParamBuilder(InfiniteData<String, int> _) => null;

      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['key'],
          queryFn,
          initialPageParam: 0,
          nextPageParamBuilder: nextPageParamBuilder,
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);

      // Update with same options
      observer.updateOptions(InfiniteQueryObserverOptions(
        const ['key'],
        queryFn,
        initialPageParam: 0,
        nextPageParamBuilder: nextPageParamBuilder,
      ));

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1); // Should not have refetched
    }));
  });

  group('subscribe', () {
    test(
        'SHOULD NOT notify listeners immediately'
        '', withFakeAsync((async) {
      var calls = 0;

      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
        ),
      );
      addTearDown(observer.dispose);

      // Wait for initial fetch to complete
      async.elapse(const Duration(seconds: 1));

      // Subscribe after data is available
      observer.subscribe((_) => calls++);

      // Listener should NOT be called immediately with current result
      expect(calls, 0);
    }));

    test(
        'SHOULD notify listeners '
        'WHEN result changes', withFakeAsync((async) {
      final capturedResults = <InfiniteQueryResult<String, Object, int>>[];

      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) {
            return data.pageParams.last < 5 ? data.pageParams.last + 1 : null;
          },
        ),
      );
      addTearDown(observer.dispose);

      observer.subscribe((result) => capturedResults.add(result));

      async.elapse(const Duration(seconds: 1));

      expect(capturedResults.length, 1);

      observer.fetchNextPage();

      expect(capturedResults.length, 2);

      async.elapse(const Duration(seconds: 1));

      expect(capturedResults.length, 3);
    }));

    test(
        'SHOULD NOT notify after unsubscribe '
        'WHEN result changes', withFakeAsync((async) {
      var calls = 0;

      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
        ),
      );
      addTearDown(observer.dispose);

      final unsubscribe = observer.subscribe((_) => calls++);

      async.elapse(const Duration(seconds: 1));
      final callsBeforeUnsubscribe = calls;

      unsubscribe();

      observer.fetchNextPage();
      async.elapse(const Duration(seconds: 1));

      expect(calls, callsBeforeUnsubscribe);
    }));
  });

  group('dispose', () {
    test(
        'SHOULD NOT notify listeners'
        '', withFakeAsync((async) {
      var calls = 0;

      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) {
            return data.pageParams.last < 5 ? data.pageParams.last + 1 : null;
          },
        ),
      );

      observer.subscribe((_) => calls++);
      observer.dispose();

      async.elapse(const Duration(seconds: 1));

      expect(calls, 0);
    }));

    test(
        'SHOULD cancel refetch interval'
        '', withFakeAsync((async) {
      var fetches = 0;

      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          refetchInterval: const Duration(seconds: 5),
        ),
      );

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);

      observer.dispose();

      async.elapse(const Duration(seconds: 100));

      expect(fetches, 1);
    }));
  });

  group('InfiniteQueryObserverOptions.queryFn', () {
    test(
        'SHOULD pass correct context '
        'WHEN fetching forward', withFakeAsync((async) {
      late InfiniteQueryFunctionContext<int> capturedContext;

      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['users', 123],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            capturedContext = context;
            return 'page-${context.pageParam}';
          },
          initialPageParam: 10,
          nextPageParamBuilder: (data) => data.pageParams.last + 10,
          meta: {'key': 'value'},
        ),
      );
      addTearDown(observer.dispose);

      // Initial fetch
      async.elapse(const Duration(seconds: 1));
      expect(capturedContext.queryKey, ['users', 123]);
      expect(capturedContext.client, same(client));
      expect(capturedContext.signal, isA<AbortSignal>());
      expect(capturedContext.meta, {'key': 'value'});
      expect(capturedContext.pageParam, 10);
      expect(capturedContext.direction, FetchDirection.forward);

      // Fetch next page
      observer.fetchNextPage();
      async.elapse(const Duration(seconds: 1));
      expect(capturedContext.queryKey, ['users', 123]);
      expect(capturedContext.client, same(client));
      expect(capturedContext.signal, isA<AbortSignal>());
      expect(capturedContext.meta, {'key': 'value'});
      expect(capturedContext.pageParam, 20);
      expect(capturedContext.direction, FetchDirection.forward);

      // Fetch another next page
      observer.fetchNextPage();
      async.elapse(const Duration(seconds: 1));
      expect(capturedContext.queryKey, ['users', 123]);
      expect(capturedContext.client, same(client));
      expect(capturedContext.signal, isA<AbortSignal>());
      expect(capturedContext.meta, {'key': 'value'});
      expect(capturedContext.pageParam, 30);
      expect(capturedContext.direction, FetchDirection.forward);
    }));

    test(
        'SHOULD pass correct context '
        'WHEN fetching backward', withFakeAsync((async) {
      late InfiniteQueryFunctionContext<int> capturedContext;

      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['users', 123],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            capturedContext = context;
            return 'page-${context.pageParam}';
          },
          initialPageParam: 50,
          nextPageParamBuilder: (data) => data.pageParams.last + 10,
          prevPageParamBuilder: (data) => data.pageParams.first - 10,
          meta: {'key': 'value'},
        ),
      );
      addTearDown(observer.dispose);

      // Initial fetch (forward)
      async.elapse(const Duration(seconds: 1));
      expect(capturedContext.queryKey, ['users', 123]);
      expect(capturedContext.client, same(client));
      expect(capturedContext.signal, isA<AbortSignal>());
      expect(capturedContext.meta, {'key': 'value'});
      expect(capturedContext.pageParam, 50);
      expect(capturedContext.direction, FetchDirection.forward);

      // Fetch previous page
      observer.fetchPreviousPage();
      async.elapse(const Duration(seconds: 1));
      expect(capturedContext.queryKey, ['users', 123]);
      expect(capturedContext.client, same(client));
      expect(capturedContext.signal, isA<AbortSignal>());
      expect(capturedContext.meta, {'key': 'value'});
      expect(capturedContext.pageParam, 40);
      expect(capturedContext.direction, FetchDirection.backward);

      // Fetch another previous page
      observer.fetchPreviousPage();
      async.elapse(const Duration(seconds: 1));
      expect(capturedContext.queryKey, ['users', 123]);
      expect(capturedContext.client, same(client));
      expect(capturedContext.signal, isA<AbortSignal>());
      expect(capturedContext.meta, {'key': 'value'});
      expect(capturedContext.pageParam, 30);
      expect(capturedContext.direction, FetchDirection.backward);
    }));
  });

  group('InfiniteQueryObserverOptions.enabled', () {
    test(
        'SHOULD fetch '
        'WHEN enabled is true', withFakeAsync((async) {
      var fetches = 0;

      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          enabled: true,
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));

      expect(fetches, 1);
    }));

    test(
        'SHOULD NOT fetch '
        'WHEN enabled is false', withFakeAsync((async) {
      var fetches = 0;

      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          enabled: false,
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));

      expect(fetches, 0);
    }));

    test(
        'SHOULD fetch '
        'WHEN enabled changes from false to true', withFakeAsync((async) {
      var fetches = 0;

      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          enabled: false,
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));

      expect(fetches, 0);

      // Enable the query
      observer.updateOptions(InfiniteQueryObserverOptions(
        const ['test'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          fetches++;
          return 'page-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        enabled: true,
      ));

      async.elapse(const Duration(seconds: 1));

      expect(fetches, 1);
    }));

    test(
        'SHOULD NOT refetch '
        'WHEN enabled changes from true to false', withFakeAsync((async) {
      var fetches = 0;

      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          staleDuration: StaleDuration.zero,
          enabled: true,
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));

      expect(fetches, 1);

      // Disable the query - data is stale but should not refetch
      observer.updateOptions(InfiniteQueryObserverOptions(
        const ['test'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          fetches++;
          return 'page-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        staleDuration: StaleDuration.zero,
        enabled: false,
      ));

      async.elapse(const Duration(seconds: 1));

      expect(fetches, 1); // Should not have refetched
    }));

    test(
        'SHOULD fetch next page '
        'WHEN enabled is false', withFakeAsync((async) {
      var fetches = 0;

      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          enabled: true,
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);

      // Disable the query
      observer.updateOptions(InfiniteQueryObserverOptions(
        const ['test'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          fetches++;
          return 'page-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        enabled: false,
      ));

      // Manual fetchNextPage should still work
      observer.fetchNextPage();
      async.elapse(const Duration(seconds: 1));

      expect(fetches, 2);
    }));

    test(
        'SHOULD fetch previous page '
        'WHEN enabled is false', withFakeAsync((async) {
      var fetches = 0;

      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'page-${context.pageParam}';
          },
          initialPageParam: 5,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          prevPageParamBuilder: (data) => data.pageParams.first - 1,
          enabled: true,
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);

      // Disable the query
      observer.updateOptions(InfiniteQueryObserverOptions(
        const ['test'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          fetches++;
          return 'page-${context.pageParam}';
        },
        initialPageParam: 5,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        prevPageParamBuilder: (data) => data.pageParams.first - 1,
        enabled: false,
      ));

      // Manual fetchPreviousPage should still work
      observer.fetchPreviousPage();
      async.elapse(const Duration(seconds: 1));

      expect(fetches, 2);
    }));

    test(
        'SHOULD refetch '
        'WHEN enabled is false', withFakeAsync((async) {
      var fetches = 0;

      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          enabled: true,
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);

      // Disable the query
      observer.updateOptions(InfiniteQueryObserverOptions(
        const ['test'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          fetches++;
          return 'page-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        enabled: false,
      ));

      // Manual refetch should still work
      observer.refetch();
      async.elapse(const Duration(seconds: 1));

      expect(fetches, 2);
    }));
  });

  group('InfiniteQueryObserverOptions.staleDuration', () {
    test(
        'SHOULD be stale immediately '
        'WHEN staleDuration == StaleDuration.zero', withFakeAsync((async) {
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          staleDuration: StaleDuration.zero,
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));

      expect(observer.result.isStale, isTrue);
    }));

    test(
        'SHOULD NOT be stale '
        'WHEN staleDuration has not elapsed', withFakeAsync((async) {
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          staleDuration: const StaleDuration(minutes: 5),
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));

      expect(observer.result.isStale, isFalse);

      // Still fresh after 4 minutes
      async.elapse(const Duration(minutes: 4));
      expect(observer.result.isStale, isFalse);
    }));

    test(
        'SHOULD be stale '
        'WHEN staleDuration has elapsed', withFakeAsync((async) {
      final options = InfiniteQueryObserverOptions<String, Object, int>(
        const ['test'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'page-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        staleDuration: const StaleDuration(minutes: 5),
      );

      final observer1 = InfiniteQueryObserver(client, options);
      addTearDown(observer1.dispose);

      async.elapse(const Duration(seconds: 1));

      expect(observer1.result.isStale, isFalse);

      // Stale after 5 minutes - check with new observer
      async.elapse(const Duration(minutes: 5));

      final observer2 = InfiniteQueryObserver(client, options);
      addTearDown(observer2.dispose);

      expect(observer2.result.isStale, isTrue);
    }));

    test(
        'SHOULD NOT be stale '
        'WHEN staleDuration == StaleDuration.infinity '
        'AND long time has elapsed', withFakeAsync((async) {
      final options = InfiniteQueryObserverOptions<String, Object, int>(
        const ['test'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'page-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        staleDuration: StaleDuration.infinity,
      );

      final observer1 = InfiniteQueryObserver(client, options);
      addTearDown(observer1.dispose);

      async.elapse(const Duration(seconds: 1));

      expect(observer1.result.isStale, isFalse);

      // Still fresh after a very long time
      async.elapse(const Duration(days: 365));

      final observer2 = InfiniteQueryObserver(client, options);
      addTearDown(observer2.dispose);

      expect(observer2.result.isStale, isFalse);
    }));

    test(
        'SHOULD NOT be stale '
        'WHEN staleDuration == StaleDuration.static '
        'AND long time has elapsed', withFakeAsync((async) {
      final options = InfiniteQueryObserverOptions<String, Object, int>(
        const ['test'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'page-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        staleDuration: StaleDuration.static,
      );

      final observer1 = InfiniteQueryObserver(client, options);
      addTearDown(observer1.dispose);

      async.elapse(const Duration(seconds: 1));

      expect(observer1.result.isStale, isFalse);

      // Still fresh after a very long time
      async.elapse(const Duration(days: 365));

      final observer2 = InfiniteQueryObserver(client, options);
      addTearDown(observer2.dispose);

      expect(observer2.result.isStale, isFalse);
    }));

    test(
        'SHOULD be stale '
        'WHEN staleDuration == StaleDuration.infinity '
        'AND cache is invalidated', withFakeAsync((async) {
      final options = InfiniteQueryObserverOptions<String, Object, int>(
        const ['test'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'page-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        staleDuration: StaleDuration.infinity,
      );

      final observer1 = InfiniteQueryObserver(client, options);
      addTearDown(observer1.dispose);

      async.elapse(const Duration(seconds: 1));

      expect(observer1.result.isStale, isFalse);

      // Invalidate the cache
      client.invalidateQueries(queryKey: const ['test']);

      // New observer should see stale data after invalidation
      final observer2 = InfiniteQueryObserver(client, options);
      addTearDown(observer2.dispose);

      expect(observer2.result.isStale, isTrue);
    }));

    test(
        'SHOULD NOT be stale '
        'WHEN staleDuration == StaleDuration.static '
        'AND cache is invalidated', withFakeAsync((async) {
      final options = InfiniteQueryObserverOptions<String, Object, int>(
        const ['test'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'page-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        staleDuration: StaleDuration.static,
      );

      final observer1 = InfiniteQueryObserver(client, options);
      addTearDown(observer1.dispose);

      async.elapse(const Duration(seconds: 1));

      expect(observer1.result.isStale, isFalse);

      // Invalidate the cache
      client.invalidateQueries(queryKey: const ['test']);

      // Static data should still NOT be stale even after invalidation
      final observer2 = InfiniteQueryObserver(client, options);
      addTearDown(observer2.dispose);

      expect(observer2.result.isStale, isFalse);
    }));
  });

  group('InfiniteQueryObserverOptions.gcDuration', () {
    test(
        'SHOULD remove query from cache '
        'WHEN gcDuration has elapsed '
        'AND there are no observers', withFakeAsync((async) {
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          gcDuration: const GcDuration(minutes: 5),
        ),
      );

      async.elapse(const Duration(seconds: 1));

      // Query should exist in cache
      expect(client.cache.findAll(queryKey: const ['test']), hasLength(1));

      // Dispose the observer (removes the observer)
      observer.dispose();

      // Query should still exist before gc duration
      expect(client.cache.findAll(queryKey: const ['test']), hasLength(1));

      // After gc duration, query should be removed
      async.elapse(const Duration(minutes: 5));

      expect(client.cache.findAll(queryKey: const ['test']), isEmpty);
    }));

    test(
        'SHOULD NOT remove query from cache '
        'WHEN gcDuration has elapsed '
        'AND there are observers', withFakeAsync((async) {
      final options = InfiniteQueryObserverOptions<String, Object, int>(
        const ['test'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'page-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        gcDuration: const GcDuration(minutes: 5),
      );

      final observer1 = InfiniteQueryObserver(client, options);
      addTearDown(observer1.dispose);

      async.elapse(const Duration(seconds: 1));

      // Create second observer
      final observer2 = InfiniteQueryObserver(client, options);
      addTearDown(observer2.dispose);

      // Dispose first observer
      observer1.dispose();

      // After gc duration, query should still exist because observer2 is still active
      async.elapse(const Duration(minutes: 5));

      expect(client.cache.findAll(queryKey: const ['test']), hasLength(1));
    }));

    test(
        'SHOULD remove query from cache immediately '
        'WHEN gcDuration == GcDuration.zero '
        'AND there are no observers', withFakeAsync((async) {
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          gcDuration: GcDuration.zero,
        ),
      );

      async.elapse(const Duration(seconds: 1));

      expect(client.cache.findAll(queryKey: const ['test']), hasLength(1));

      // Dispose the observer
      observer.dispose();

      // Query should be removed immediately (after zero-duration timer fires)
      async.elapse(Duration.zero);

      expect(client.cache.findAll(queryKey: const ['test']), isEmpty);
    }));

    test(
        'SHOULD NOT remove query from cache '
        'WHEN gcDuration == GcDuration.infinity '
        'AND long time has elapsed', withFakeAsync((async) {
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          gcDuration: GcDuration.infinity,
        ),
      );

      async.elapse(const Duration(seconds: 1));

      // Dispose the observer
      observer.dispose();

      // Query should still exist even after a very long time
      async.elapse(const Duration(days: 365));

      expect(client.cache.findAll(queryKey: const ['test']), hasLength(1));
    }));
  });

  group('InfiniteQueryObserverOptions.placeholder', () {
    test(
        'SHOULD use placeholder '
        '', withFakeAsync((async) {
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          placeholder: const InfiniteData(['page-ph'], [0]),
        ),
      );
      addTearDown(observer.dispose);

      expect(observer.result.pages, ['page-ph']);
      expect(observer.result.isPlaceholderData, isTrue);
      expect(observer.result.isSuccess, isTrue);
    }));

    test(
        'SHOULD NOT persist placeholder to cache'
        '', withFakeAsync((async) {
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          placeholder: const InfiniteData(['page-ph'], [0]),
        ),
      );
      addTearDown(observer.dispose);

      expect(client.cache.get(const ['test'])!.state.data, isNull);
    }));

    test(
        'SHOULD be replaced by fetched data'
        '', withFakeAsync((async) {
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          placeholder: const InfiniteData(['page-ph'], [0]),
        ),
      );
      addTearDown(observer.dispose);

      expect(observer.result.pages, ['page-ph']);
      expect(observer.result.isPlaceholderData, isTrue);

      async.elapse(const Duration(seconds: 1));

      expect(observer.result.pages, ['page-0']);
      expect(observer.result.isPlaceholderData, isFalse);
    }));

    test(
        'SHOULD NOT use placeholder '
        'WHEN data already exists', withFakeAsync((async) {
      final options = InfiniteQueryObserverOptions<String, Object, int>(
        const ['test'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'page-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        placeholder: const InfiniteData(['page-ph'], [0]),
      );

      // First observer fetches real data
      final observer1 = InfiniteQueryObserver(client, options);
      addTearDown(observer1.dispose);

      async.elapse(const Duration(seconds: 1));

      // Second observer should use cached real data, not placeholder
      final observer2 = InfiniteQueryObserver(client, options);
      addTearDown(observer2.dispose);

      expect(observer2.result.pages, ['page-0']);
      expect(observer2.result.isPlaceholderData, isFalse);
    }));

    test(
        'SHOULD NOT use placeholder '
        'WHEN provided by another observer', withFakeAsync((async) {
      final observer1 = InfiniteQueryObserver(
        client,
        InfiniteQueryObserverOptions<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          placeholder: const InfiniteData(['page-ph'], [0]),
        ),
      );
      addTearDown(observer1.dispose);

      final observer2 = InfiniteQueryObserver(
        client,
        InfiniteQueryObserverOptions<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
        ),
      );
      addTearDown(observer2.dispose);

      expect(observer1.result.pages, ['page-ph']);
      expect(observer1.result.isPlaceholderData, isTrue);
      expect(observer2.result.pages, []);
      expect(observer2.result.isPlaceholderData, isFalse);
    }));
  });

  group('InfiniteQueryObserverOptions.refetchOnMount', () {
    test(
        'SHOULD refetch on mount '
        'WHEN refetchOnMount == RefetchOnMount.stale '
        'AND data is stale', withFakeAsync((async) {
      var fetches = 0;
      final options = InfiniteQueryObserverOptions<String, Object, int>(
        const ['test'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          fetches++;
          return 'page-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        staleDuration: const StaleDuration(minutes: 5),
        refetchOnMount: RefetchOnMount.stale,
      );

      final observer1 = InfiniteQueryObserver(client, options);
      addTearDown(observer1.dispose);

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);

      // Make data stale
      async.elapse(const Duration(minutes: 5));

      // New observer should refetch stale data
      final observer2 = InfiniteQueryObserver(client, options);
      addTearDown(observer2.dispose);

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 2);
    }));

    test(
        'SHOULD NOT refetch on mount '
        'WHEN refetchOnMount == RefetchOnMount.stale '
        'AND data is fresh', withFakeAsync((async) {
      var fetches = 0;
      final options = InfiniteQueryObserverOptions<String, Object, int>(
        const ['test'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          fetches++;
          return 'page-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        staleDuration: const StaleDuration(minutes: 5),
        refetchOnMount: RefetchOnMount.stale,
      );

      final observer1 = InfiniteQueryObserver(client, options);
      addTearDown(observer1.dispose);

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);

      // Data is still fresh
      final observer2 = InfiniteQueryObserver(client, options);
      addTearDown(observer2.dispose);

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);
    }));

    test(
        'SHOULD NOT refetch on mount '
        'WHEN refetchOnMount == RefetchOnMount.never '
        'AND data is stale', withFakeAsync((async) {
      var fetches = 0;
      final options = InfiniteQueryObserverOptions<String, Object, int>(
        const ['test'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          fetches++;
          return 'page-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        staleDuration: const StaleDuration(minutes: 5),
        refetchOnMount: RefetchOnMount.never,
      );

      final observer1 = InfiniteQueryObserver(client, options);
      addTearDown(observer1.dispose);

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);

      // Make data stale
      async.elapse(const Duration(minutes: 5));

      // New observer should NOT refetch even with stale data
      final observer2 = InfiniteQueryObserver(client, options);
      addTearDown(observer2.dispose);

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);
    }));

    test(
        'SHOULD NOT refetch on mount '
        'WHEN refetchOnMount == RefetchOnMount.never '
        'AND data is fresh', withFakeAsync((async) {
      var fetches = 0;
      final options = InfiniteQueryObserverOptions<String, Object, int>(
        const ['test'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          fetches++;
          return 'page-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        staleDuration: const StaleDuration(minutes: 5),
        refetchOnMount: RefetchOnMount.never,
      );

      final observer1 = InfiniteQueryObserver(client, options);
      addTearDown(observer1.dispose);

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);

      // Data is still fresh - new observer should NOT refetch
      final observer2 = InfiniteQueryObserver(client, options);
      addTearDown(observer2.dispose);

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);
    }));

    test(
        'SHOULD refetch on mount '
        'WHEN refetchOnMount == RefetchOnMount.always '
        'AND data is stale', withFakeAsync((async) {
      var fetches = 0;
      final options = InfiniteQueryObserverOptions<String, Object, int>(
        const ['test'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          fetches++;
          return 'page-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        staleDuration: const StaleDuration(minutes: 5),
        refetchOnMount: RefetchOnMount.always,
      );

      final observer1 = InfiniteQueryObserver(client, options);
      addTearDown(observer1.dispose);

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);

      // Make data stale
      async.elapse(const Duration(minutes: 5));

      // New observer should refetch
      final observer2 = InfiniteQueryObserver(client, options);
      addTearDown(observer2.dispose);

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 2);
    }));

    test(
        'SHOULD refetch on mount '
        'WHEN refetchOnMount == RefetchOnMount.always '
        'AND data is fresh', withFakeAsync((async) {
      var fetches = 0;
      final options = InfiniteQueryObserverOptions<String, Object, int>(
        const ['test'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          fetches++;
          return 'page-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        staleDuration: const StaleDuration(minutes: 5),
        refetchOnMount: RefetchOnMount.always,
      );

      final observer1 = InfiniteQueryObserver(client, options);
      addTearDown(observer1.dispose);

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);

      // Data is still fresh - but new observer should refetch anyway
      final observer2 = InfiniteQueryObserver(client, options);
      addTearDown(observer2.dispose);

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 2);
    }));
  });

  group('InfiniteQueryObserverOptions.refetchOnResume', () {
    test(
        'SHOULD refetch on resume '
        'WHEN refetchOnResume == RefetchOnResume.stale '
        'AND data is stale', withFakeAsync((async) {
      var fetches = 0;

      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          staleDuration: const StaleDuration(minutes: 5),
          refetchOnResume: RefetchOnResume.stale,
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);

      // Make data stale
      async.elapse(const Duration(minutes: 5));

      // Resume should refetch stale data
      observer.onResume();
      async.elapse(const Duration(seconds: 1));

      expect(fetches, 2);
    }));

    test(
        'SHOULD NOT refetch on resume '
        'WHEN refetchOnResume == RefetchOnResume.stale '
        'AND data is fresh', withFakeAsync((async) {
      var fetches = 0;

      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          staleDuration: const StaleDuration(minutes: 5),
          refetchOnResume: RefetchOnResume.stale,
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);

      // Data is still fresh - resume should NOT refetch
      observer.onResume();
      async.elapse(const Duration(seconds: 1));

      expect(fetches, 1);
    }));

    test(
        'SHOULD NOT refetch on resume '
        'WHEN refetchOnResume == RefetchOnResume.never '
        'AND data is stale', withFakeAsync((async) {
      var fetches = 0;

      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          staleDuration: const StaleDuration(minutes: 5),
          refetchOnResume: RefetchOnResume.never,
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);

      // Make data stale
      async.elapse(const Duration(minutes: 5));

      // Resume should NOT refetch even with stale data
      observer.onResume();
      async.elapse(const Duration(seconds: 1));

      expect(fetches, 1);
    }));

    test(
        'SHOULD NOT refetch on resume '
        'WHEN refetchOnResume == RefetchOnResume.never '
        'AND data is fresh', withFakeAsync((async) {
      var fetches = 0;

      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          staleDuration: const StaleDuration(minutes: 5),
          refetchOnResume: RefetchOnResume.never,
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);

      // Data is still fresh - resume should NOT refetch
      observer.onResume();
      async.elapse(const Duration(seconds: 1));

      expect(fetches, 1);
    }));

    test(
        'SHOULD refetch on resume '
        'WHEN refetchOnResume == RefetchOnResume.always '
        'AND data is stale', withFakeAsync((async) {
      var fetches = 0;

      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          staleDuration: const StaleDuration(minutes: 5),
          refetchOnResume: RefetchOnResume.always,
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);

      // Make data stale
      async.elapse(const Duration(minutes: 5));

      // Resume should refetch
      observer.onResume();
      async.elapse(const Duration(seconds: 1));

      expect(fetches, 2);
    }));

    test(
        'SHOULD refetch on resume '
        'WHEN refetchOnResume == RefetchOnResume.always '
        'AND data is fresh', withFakeAsync((async) {
      var fetches = 0;

      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          staleDuration: const StaleDuration(minutes: 5),
          refetchOnResume: RefetchOnResume.always,
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);

      // Data is still fresh - but resume should refetch anyway
      observer.onResume();
      async.elapse(const Duration(seconds: 1));

      expect(fetches, 2);
    }));
  });

  group('InfiniteQueryObserverOptions.refetchInterval', () {
    test(
        'SHOULD refetch at intervals'
        '', withFakeAsync((async) {
      final startedAt = clock.now();
      var fetches = 0;

      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          refetchInterval: const Duration(seconds: 5),
        ),
      );
      addTearDown(observer.dispose);

      // Initial fetch
      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);

      // First interval refetch
      async.elapseUntil(startedAt.add(const Duration(seconds: 5)));
      async.elapse(const Duration(seconds: 1));
      expect(fetches, 2);

      // Second interval refetch
      async.elapseUntil(startedAt.add(const Duration(seconds: 10)));
      async.elapse(const Duration(seconds: 1));
      expect(fetches, 3);
    }));
  });

  group('InfiniteQueryObserverOptions.retry', () {
    test(
        'SHOULD retry on failure '
        'WHEN retry returns Duration', withFakeAsync((async) {
      var attempts = 0;

      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            attempts++;
            if (attempts < 3) {
              throw Exception();
            }
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          retry: (retryCount, error) {
            if (retryCount >= 3) return null;
            return const Duration(seconds: 1);
          },
        ),
      );
      addTearDown(observer.dispose);

      // First attempt fails, retry is scheduled
      async.flushMicrotasks();
      expect(attempts, 1);
      expect(observer.result.failureCount, 1);

      // First retry after 1s delay - still fails
      async.elapse(const Duration(seconds: 1));
      expect(attempts, 2);
      expect(observer.result.failureCount, 2);

      // Second retry after 1s delay - succeeds
      async.elapse(const Duration(seconds: 1));
      expect(attempts, 3);
      expect(observer.result.isSuccess, isTrue);
      expect(observer.result.failureCount, 0);
    }));

    test(
        'SHOULD NOT retry '
        'WHEN retry returns null', withFakeAsync((async) {
      var attempts = 0;

      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            attempts++;
            throw Exception();
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          retry: (_, __) => null,
        ),
      );
      addTearDown(observer.dispose);

      // First attempt fails
      async.flushMicrotasks();
      expect(attempts, 1);
      expect(observer.result.isError, isTrue);

      // Wait more - no retries should happen
      async.elapse(const Duration(seconds: 10));
      expect(attempts, 1);
    }));

    test(
        'SHOULD NOT retry further '
        'WHEN retry returns null ongoing', withFakeAsync((async) {
      var attempts = 0;

      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            attempts++;
            throw Exception();
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          retry: (retryCount, error) {
            if (retryCount >= 2) return null; // Max 2 retries
            return const Duration(seconds: 1);
          },
        ),
      );
      addTearDown(observer.dispose);

      // First attempt fails
      async.flushMicrotasks();
      expect(attempts, 1);

      // First retry
      async.elapse(const Duration(seconds: 1));
      expect(attempts, 2);

      // Second retry
      async.elapse(const Duration(seconds: 1));
      expect(attempts, 3);

      // No more retries - wait and verify
      async.elapse(const Duration(seconds: 10));
      expect(attempts, 3);
      expect(observer.result.isError, isTrue);
    }));
  });

  group('InfiniteQueryObserverOptions.retryOnMount', () {
    test(
        'SHOULD retry on mount '
        'WHEN retryOnMount == true '
        'AND query is in error state', withFakeAsync((async) {
      var fetches = 0;
      final options = InfiniteQueryObserverOptions<String, Object, int>(
        const ['test'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          fetches++;
          if (fetches < 2) {
            throw Exception();
          }
          return 'page-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        retry: (_, __) => null,
        retryOnMount: true,
      );

      // First observer - fails and enters error state
      final observer1 = InfiniteQueryObserver(client, options);

      // Wait for first observer to fail
      async.elapse(const Duration(seconds: 1));
      expect(observer1.result.isError, isTrue);
      expect(fetches, 1);

      // Dispose first observer
      observer1.dispose();

      // Second observer with retryOnMount: true (default)
      final observer2 = InfiniteQueryObserver(client, options);
      addTearDown(observer2.dispose);

      // Should retry - fetches should increment
      async.elapse(const Duration(seconds: 1));
      expect(fetches, 2);
      expect(observer2.result.isSuccess, isTrue);
    }));

    test(
        'SHOULD NOT retry on mount '
        'WHEN retryOnMount == false '
        'AND query is in error state', withFakeAsync((async) {
      var fetches = 0;
      final options = InfiniteQueryObserverOptions<String, Object, int>(
        const ['test'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          fetches++;
          throw Exception();
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        retry: (_, __) => null,
        retryOnMount: false,
      );

      // First observer - fails and enters error state
      final observer1 = InfiniteQueryObserver(client, options);

      // Wait for first observer to fail
      async.elapse(const Duration(seconds: 1));
      expect(observer1.result.isError, isTrue);
      expect(fetches, 1);

      // Dispose first observer
      observer1.dispose();

      // Second observer with retryOnMount: false
      final observer2 = InfiniteQueryObserver(client, options);
      addTearDown(observer2.dispose);

      // Should NOT retry - fetches should stay the same
      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);
      expect(observer2.result.isError, isTrue);
    }));

    test(
        'SHOULD fetch on mount '
        'WHEN retryOnMount == false '
        'AND query has no data', withFakeAsync((async) {
      var fetches = 0;

      // Observer with retryOnMount: false but no existing query data
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          retryOnMount: false,
        ),
      );
      addTearDown(observer.dispose);

      // Should fetch since there's no existing data (not error state)
      async.elapse(const Duration(seconds: 1));
      expect(fetches, 1);
      expect(observer.result.isSuccess, isTrue);
    }));
  });

  group('InfiniteQueryObserverOptions.seed', () {
    test(
        'SHOULD use seed for data'
        '', withFakeAsync((async) {
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          seed: const InfiniteData(['page-seed'], [0]),
        ),
      );
      addTearDown(observer.dispose);

      expect(
        observer.result.data,
        const InfiniteData(['page-seed'], [0]),
      );
      expect(observer.result.dataUpdateCount, 0);
      expect(observer.result.isSuccess, isTrue);
    }));

    test(
        'SHOULD persist seed to cache'
        '', withFakeAsync((async) {
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          seed: const InfiniteData(['page-seed'], [0]),
        ),
      );
      addTearDown(observer.dispose);

      expect(
        client.cache.get(const ['test'])?.state.data,
        const InfiniteData(['page-seed'], [0]),
      );
    }));

    test(
        'SHOULD take precedence over placeholder'
        '', withFakeAsync((async) {
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          placeholder: const InfiniteData(['page-ph'], [0]),
          seed: const InfiniteData(['page-seed'], [0]),
        ),
      );
      addTearDown(observer.dispose);

      expect(observer.result.data!.pages, ['page-seed']);
      expect(observer.result.isPlaceholderData, isFalse);
    }));

    test(
        'SHOULD be replaced fetched data'
        '', withFakeAsync((async) {
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          seed: const InfiniteData(['page-seed'], [0]),
          staleDuration: StaleDuration.zero,
        ),
      );
      addTearDown(observer.dispose);

      expect(observer.result.data!.pages, ['page-seed']);

      async.elapse(const Duration(seconds: 1));

      expect(observer.result.data!.pages, ['page-0']);
    }));
  });

  group('InfiniteQueryObserverOptions.seedUpdatedAt', () {
    test(
        'SHOULD use current time '
        'WHEN seedUpdatedAt is not provided', withFakeAsync((async) {
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          seed: const InfiniteData(['page-seed'], [0]),
        ),
      );
      addTearDown(observer.dispose);

      expect(observer.result.dataUpdatedAt, clock.now());
    }));

    test(
        'SHOULD make data stale '
        'WHEN seedUpdatedAt is older than staleDuration',
        withFakeAsync((async) {
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          seed: const InfiniteData(['page-seed'], [0]),
          seedUpdatedAt: clock.minutesAgo(10),
          staleDuration: const StaleDuration(minutes: 5),
        ),
      );
      addTearDown(observer.dispose);

      expect(observer.result.isStale, isTrue);
    }));

    test(
        'SHOULD NOT make data stale '
        'WHEN seedUpdatedAt is within staleDuration', withFakeAsync((async) {
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          seed: const InfiniteData(['page-seed'], [0]),
          seedUpdatedAt: clock.minutesAgo(2),
          staleDuration: const StaleDuration(minutes: 5),
        ),
      );
      addTearDown(observer.dispose);

      expect(observer.result.isStale, isFalse);
    }));

    test(
        'SHOULD extend freshness period '
        'WHEN seedUpdatedAt is set to future DateTime', withFakeAsync((async) {
      final options = InfiniteQueryObserverOptions<String, Object, int>(
        const ['test'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'page-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        seed: const InfiniteData(['page-seed'], [0]),
        seedUpdatedAt: clock.minutesFromNow(60),
        staleDuration: const StaleDuration(minutes: 5),
      );

      final observer1 = InfiniteQueryObserver(client, options);
      addTearDown(observer1.dispose);

      // Data should NOT be stale (seedUpdatedAt is 1 hour in the future)
      expect(observer1.result.isStale, isFalse);

      // Even after 30 minutes, data should still be fresh
      async.elapse(const Duration(minutes: 30));
      final observer2 = InfiniteQueryObserver(client, options);
      addTearDown(observer2.dispose);
      expect(observer2.result.isStale, isFalse);

      // After 1 hour + 5 minutes (seedUpdatedAt + staleDuration), data becomes stale
      async.elapse(const Duration(minutes: 35));
      final observer3 = InfiniteQueryObserver(client, options);
      addTearDown(observer3.dispose);
      expect(observer3.result.isStale, isTrue);
    }));
  });

  group('InfiniteQueryObserverOptions.meta', () {
    test(
        'SHOULD deep merge values'
        'WHEN provided by multiple observers', withFakeAsync((async) {
      final observer1 = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          meta: {
            'source': 'observer1',
            'nested': {'a': 1, 'b': 2},
          },
        ),
      );
      addTearDown(observer1.dispose);

      final observer2 = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          meta: {
            'extra': 'value',
            'nested': {'c': 3},
          },
        ),
      );
      addTearDown(observer2.dispose);

      final query = client.cache.get(const ['test'])!;
      expect(query.meta, {
        'source': 'observer1',
        'extra': 'value',
        'nested': {'a': 1, 'b': 2, 'c': 3},
      });
    }));
  });

  group('InfiniteQueryResult.failureCount', () {
    test(
        'SHOULD increment on each retry '
        '', withFakeAsync((async) {
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            throw Exception();
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          retry: (retryCount, error) {
            if (retryCount >= 3) return null;
            return const Duration(seconds: 1);
          },
        ),
      );
      addTearDown(observer.dispose);

      // First attempt fails
      async.flushMicrotasks();
      expect(observer.result.failureCount, 1);

      // First retry fails
      async.elapse(const Duration(seconds: 1));
      expect(observer.result.failureCount, 2);

      // Second retry fails
      async.elapse(const Duration(seconds: 1));
      expect(observer.result.failureCount, 3);

      // Third retry fails - max reached
      async.elapse(const Duration(seconds: 1));
      expect(observer.result.failureCount, 4);
    }));

    test(
        'SHOULD be reset to 0 '
        'WHEN query succeeds after retry', withFakeAsync((async) {
      var attempts = 0;

      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            attempts++;
            if (attempts < 3) {
              throw Exception();
            }
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          retry: (retryCount, error) {
            if (retryCount >= 3) return null;
            return const Duration(seconds: 1);
          },
        ),
      );
      addTearDown(observer.dispose);

      // First attempt fails
      async.flushMicrotasks();
      expect(observer.result.failureCount, 1);

      // First retry fails
      async.elapse(const Duration(seconds: 1));
      expect(observer.result.failureCount, 2);

      // Second retry succeeds
      async.elapse(const Duration(seconds: 1));
      expect(observer.result.isSuccess, isTrue);
      expect(observer.result.failureCount, 0);
    }));

    test(
        'SHOULD be reset to 0 on new fetch cycle '
        'WHEN previous fetch cycle ended in error state',
        withFakeAsync((async) {
      var fetchCount = 0;

      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            fetchCount++;
            // First fetch cycle fails (fetchCount 1-2), second succeeds (fetchCount 3)
            if (fetchCount < 3) {
              throw Exception();
            }
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          retry: (retryCount, error) {
            if (retryCount >= 1) return null; // Only 1 retry
            return const Duration(seconds: 1);
          },
        ),
      );
      addTearDown(observer.dispose);

      // First attempt fails
      async.flushMicrotasks();
      expect(observer.result.failureCount, 1);

      // Retry fails - max reached, query is in error state
      async.elapse(const Duration(seconds: 1));
      expect(observer.result.failureCount, 2);
      expect(observer.result.isError, isTrue);

      // Start new fetch cycle via refetch
      observer.refetch();

      // failureCount should be reset to 0 at the start of new fetch cycle
      expect(observer.result.failureCount, 0);
      expect(observer.result.isFetching, isTrue);

      // New fetch cycle succeeds
      async.flushMicrotasks();
      expect(observer.result.isSuccess, isTrue);
      expect(observer.result.failureCount, 0);
    }));
  });

  group('InfiniteQueryResult.isFetchedAfterMount', () {
    test(
        'SHOULD return true '
        'WHEN data has been fetched at least once', withFakeAsync((async) {
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
        ),
      );
      addTearDown(observer.dispose);

      expect(observer.result.isFetchedAfterMount, isFalse);

      async.elapse(const Duration(seconds: 1));

      expect(observer.result.isFetchedAfterMount, isTrue);
    }));

    test(
        'SHOULD return true '
        'WHEN error has been thrown at least once', withFakeAsync((async) {
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            throw Exception();
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
        ),
      );
      addTearDown(observer.dispose);

      expect(observer.result.isFetchedAfterMount, isFalse);

      async.elapse(const Duration(seconds: 1));

      expect(observer.result.isFetchedAfterMount, isTrue);
    }));
  });

  group('InfiniteQueryResult.isRefetching', () {
    test(
        'SHOULD return true '
        'WHEN refetching', withFakeAsync((async) {
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));

      expect(observer.result.isRefetching, isFalse);

      observer.refetch();

      expect(observer.result.isRefetching, isTrue);
    }));

    test(
        'SHOULD return false '
        'WHEN fetching initial page', withFakeAsync((async) {
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
        ),
      );
      addTearDown(observer.dispose);

      expect(observer.result.isRefetching, isFalse);
    }));

    test(
        'SHOULD return false '
        'WHEN not fetching', withFakeAsync((async) {
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));

      expect(observer.result.isRefetching, isFalse);
    }));

    test(
        'SHOULD return false '
        'WHEN fetchNextPage is in progress', withFakeAsync((async) {
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));

      observer.fetchNextPage();

      expect(observer.result.isRefetching, isFalse);
    }));

    test(
        'SHOULD return false '
        'WHEN fetchPreviousPage is in progress', withFakeAsync((async) {
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 5,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          prevPageParamBuilder: (data) => data.pageParams.first - 1,
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));

      observer.fetchPreviousPage();

      expect(observer.result.isRefetching, isFalse);
    }));
  });

  group('InfiniteQueryResult.hasNextPage', () {
    test(
        'SHOULD return false '
        'WHEN data is null', withFakeAsync((async) {
      // Case 1: Before fetch completes
      final observer1 = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test1'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
        ),
      );
      addTearDown(observer1.dispose);

      expect(observer1.result.data, isNull);
      expect(observer1.result.hasNextPage, isFalse);

      // Case 2: After initial fetch failed
      final observer2 = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test2'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            throw Exception();
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
        ),
      );
      addTearDown(observer2.dispose);
      async.elapse(const Duration(seconds: 1));

      expect(observer2.result.data, isNull);
      expect(observer2.result.hasNextPage, isFalse);
    }));

    test(
        'SHOULD return false '
        'WHEN nextPageParamBuilder returns null', withFakeAsync((async) {
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (_) => null,
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));

      expect(observer.result.data, isNotNull);
      expect(observer.result.hasNextPage, isFalse);
    }));

    test(
        'SHOULD return true '
        'WHEN nextPageParamBuilder returns non-null', withFakeAsync((async) {
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));

      expect(observer.result.data, isNotNull);
      expect(observer.result.hasNextPage, isTrue);
    }));

    test(
        "SHOULD return value depending on nextPageParamBuilder's return value"
        '', withFakeAsync((async) {
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) {
            // Limit to 2 pages
            if (data.pages.length >= 2) return null;
            return data.pageParams.last + 1;
          },
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));

      // After initial fetch, hasNextPage should be true
      expect(observer.result.hasNextPage, isTrue);

      observer.fetchNextPage();
      async.elapse(const Duration(seconds: 1));

      // After fetching the last page, hasNextPage should be false
      expect(observer.result.hasNextPage, isFalse);
    }));
  });

  group('InfiniteQueryResult.hasPreviousPage', () {
    test(
        'SHOULD return false '
        'WHEN data is null', withFakeAsync((async) {
      // Case 1: Before fetch completes
      final observer1 = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test1'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 5,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          prevPageParamBuilder: (data) => data.pageParams.first - 1,
        ),
      );
      addTearDown(observer1.dispose);

      expect(observer1.result.data, isNull);
      expect(observer1.result.hasPreviousPage, isFalse);

      // Case 2: After initial fetch failed
      final observer2 = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test2'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            throw Exception();
          },
          initialPageParam: 5,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          prevPageParamBuilder: (data) => data.pageParams.first - 1,
        ),
      );
      addTearDown(observer2.dispose);

      async.elapse(const Duration(seconds: 1));

      expect(observer2.result.data, isNull);
      expect(observer2.result.hasPreviousPage, isFalse);
    }));

    test(
        'SHOULD return false '
        'WHEN prevPageParamBuilder is not provided', withFakeAsync((async) {
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 5,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          // prevPageParamBuilder not provided
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));

      expect(observer.result.data, isNotNull);
      expect(observer.result.hasPreviousPage, isFalse);
    }));

    test(
        'SHOULD return false '
        'WHEN prevPageParamBuilder returns null', withFakeAsync((async) {
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          prevPageParamBuilder: (_) => null,
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));

      expect(observer.result.data, isNotNull);
      expect(observer.result.hasPreviousPage, isFalse);
    }));

    test(
        'SHOULD return true '
        'WHEN prevPageParamBuilder returns non-null', withFakeAsync((async) {
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 5,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          prevPageParamBuilder: (data) => data.pageParams.first - 1,
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));

      expect(observer.result.data, isNotNull);
      expect(observer.result.hasPreviousPage, isTrue);
    }));

    test(
        "SHOULD return value depending on prevPageParamBuilder's return value"
        '', withFakeAsync((async) {
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 1,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          prevPageParamBuilder: (data) {
            // Only allow fetching previous if first page param > 0
            if (data.pageParams.first <= 0) return null;
            return data.pageParams.first - 1;
          },
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));

      // After initial fetch, hasPreviousPage should be true
      expect(observer.result.hasPreviousPage, isTrue);

      observer.fetchPreviousPage();
      async.elapse(const Duration(seconds: 1));

      // After fetching the first page, hasPreviousPage should be false
      expect(observer.result.hasPreviousPage, isFalse);
    }));
  });

  group('InfiniteQueryResult.isFetchingNextPage', () {
    test(
        'SHOULD return false '
        'WHEN not fetching', withFakeAsync((async) {
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));

      expect(observer.result.isFetching, isFalse);
      expect(observer.result.isFetchingNextPage, isFalse);
    }));

    test(
        'SHOULD return false '
        'WHEN fetching initial page', withFakeAsync((async) {
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
        ),
      );
      addTearDown(observer.dispose);

      expect(observer.result.isFetching, isTrue);
      expect(observer.result.isFetchingNextPage, isFalse);
    }));

    test(
        'SHOULD return true '
        'WHEN fetchNextPage is in progress', withFakeAsync((async) {
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));

      observer.fetchNextPage();

      expect(observer.result.isFetching, isTrue);
      expect(observer.result.isFetchingNextPage, isTrue);
    }));

    test(
        'SHOULD return false '
        'WHEN fetchPreviousPage is in progress', withFakeAsync((async) {
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 5,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          prevPageParamBuilder: (data) => data.pageParams.first - 1,
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));

      observer.fetchPreviousPage();

      expect(observer.result.isFetching, isTrue);
      expect(observer.result.isFetchingNextPage, isFalse);
    }));

    test(
        'SHOULD return false '
        'WHEN refetching', withFakeAsync((async) {
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));

      observer.refetch();

      expect(observer.result.isFetching, isTrue);
      expect(observer.result.isRefetching, isTrue);
      expect(observer.result.isFetchingNextPage, isFalse);
    }));
  });

  group('InfiniteQueryResult.isFetchingPreviousPage', () {
    test(
        'SHOULD return false '
        'WHEN not fetching', withFakeAsync((async) {
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 5,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          prevPageParamBuilder: (data) => data.pageParams.first - 1,
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));

      expect(observer.result.isFetching, isFalse);
      expect(observer.result.isFetchingPreviousPage, isFalse);
    }));

    test(
        'SHOULD return false '
        'WHEN fetching initial page', withFakeAsync((async) {
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 5,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          prevPageParamBuilder: (data) => data.pageParams.first - 1,
        ),
      );
      addTearDown(observer.dispose);

      expect(observer.result.isFetching, isTrue);
      expect(observer.result.isFetchingPreviousPage, isFalse);
    }));

    test(
        'SHOULD return false '
        'WHEN fetchNextPage is in progress', withFakeAsync((async) {
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 5,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          prevPageParamBuilder: (data) => data.pageParams.first - 1,
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));

      observer.fetchNextPage();

      expect(observer.result.isFetching, isTrue);
      expect(observer.result.isFetchingPreviousPage, isFalse);
    }));

    test(
        'SHOULD return true '
        'WHEN fetchPreviousPage is in progress', withFakeAsync((async) {
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 5,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          prevPageParamBuilder: (data) => data.pageParams.first - 1,
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));

      observer.fetchPreviousPage();

      expect(observer.result.isFetching, isTrue);
      expect(observer.result.isFetchingPreviousPage, isTrue);
    }));

    test(
        'SHOULD return false '
        'WHEN refetching', withFakeAsync((async) {
      final observer = InfiniteQueryObserver<String, Object, int>(
        client,
        InfiniteQueryObserverOptions(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 5,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          prevPageParamBuilder: (data) => data.pageParams.first - 1,
        ),
      );
      addTearDown(observer.dispose);

      async.elapse(const Duration(seconds: 1));

      observer.refetch();

      expect(observer.result.isFetching, isTrue);
      expect(observer.result.isRefetching, isTrue);
      expect(observer.result.isFetchingPreviousPage, isFalse);
    }));
  });
}

extension on FakeAsync {
  void elapseUntil(DateTime target) {
    final duration = target.difference(clock.now());

    if (duration.isNegative) {
      throw Exception('Cannot elapse to a time in the past');
    }

    elapse(duration);
  }
}
