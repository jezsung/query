import 'package:flutter/material.dart';

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_hooks_test/flutter_hooks_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_query/src_new/core/core.dart';
import 'package:flutter_query/src_new/hooks/use_query.dart';
import 'package:flutter_query/src_new/widgets/query_client_provider.dart';
import '../matchers/use_query_result_matcher.dart';

void main() {
  late QueryClient client;

  setUp(() {
    client = QueryClient();
  });

  tearDown(() {
    client.dispose();
  });

  testWidgets('SHOULD find QueryClient provided by QueryClientProvider',
      (tester) async {
    final hookResult = await buildHook(
      () => useQuery(
        queryKey: const ['key'],
        queryFn: () async => 'data',
      ),
      wrapper: (child) => QueryClientProvider(
        client: client,
        child: child,
      ),
    );

    await tester.pumpAndSettle();

    expect(hookResult.current.data, equals('data'));
  });

  testWidgets('SHOULD prioritize queryClient over QueryClientProvider',
      (tester) async {
    final prioritizedQueryClient = QueryClient();

    await buildHook(
      () => useQuery(
        queryKey: const ['key'],
        queryFn: () async => 'data',
        queryClient: prioritizedQueryClient,
      ),
      wrapper: (child) => QueryClientProvider(
        client: client,
        child: child,
      ),
    );

    await tester.pumpAndSettle();

    expect(prioritizedQueryClient.cache.get(const ['key']), isNotNull);
    expect(client.cache.get(const ['key']), isNull);
  });

  testWidgets('SHOULD fetch and succeed', (tester) async {
    const expectedData = 'test data';

    final hookResult = await buildHook(
      () => useQuery(
        queryKey: const ['test'],
        queryFn: () async {
          await Future.delayed(const Duration(milliseconds: 100));
          return expectedData;
        },
        queryClient: client,
      ),
    );

    expect(
      hookResult.current,
      isUseQueryResult(
        status: QueryStatus.pending,
        fetchStatus: FetchStatus.fetching,
        data: null,
        dataUpdatedAt: null,
        error: null,
        errorUpdatedAt: null,
        errorUpdateCount: 0,
        isEnabled: true,
      ),
    );

    await tester.pumpAndSettle();

    expect(
      hookResult.current,
      isUseQueryResult(
        status: QueryStatus.success,
        fetchStatus: FetchStatus.idle,
        data: expectedData,
        dataUpdatedAt: isA<DateTime>(),
        error: null,
        errorUpdatedAt: null,
        errorUpdateCount: 0,
        isEnabled: true,
      ),
    );
  });

  testWidgets('SHOULD fetch and fail', (tester) async {
    final expectedError = Exception();

    final hookResult = await buildHook(
      () => useQuery(
        queryKey: const ['test-error'],
        queryFn: () async {
          await Future.delayed(const Duration(milliseconds: 100));
          throw expectedError;
        },
        queryClient: client,
      ),
    );

    expect(
      hookResult.current,
      isUseQueryResult(
        status: QueryStatus.pending,
        fetchStatus: FetchStatus.fetching,
        data: null,
        dataUpdatedAt: null,
        error: null,
        errorUpdatedAt: null,
        errorUpdateCount: 0,
        isEnabled: true,
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));

    expect(
      hookResult.current,
      isUseQueryResult(
        status: QueryStatus.error,
        fetchStatus: FetchStatus.idle,
        data: null,
        dataUpdatedAt: null,
        error: expectedError,
        errorUpdatedAt: isA<DateTime>(),
        errorUpdateCount: 1,
        isEnabled: true,
      ),
    );
  });

  testWidgets('SHOULD NOT fetch WHEN enabled is false', (tester) async {
    var fetchCount = 0;

    final hookResult = await buildHook(
      () => useQuery<String, Object>(
        queryKey: const ['test-disabled'],
        queryFn: () async {
          fetchCount++;
          return 'data';
        },
        enabled: false,
        queryClient: client,
      ),
    );

    await tester.pumpAndSettle();

    expect(fetchCount, 0);
    expect(
      hookResult.current,
      isUseQueryResult(
        status: QueryStatus.pending,
        fetchStatus: FetchStatus.idle,
        data: null,
        dataUpdatedAt: null,
        error: null,
        errorUpdatedAt: null,
        errorUpdateCount: 0,
        isEnabled: false,
      ),
    );
  });

  testWidgets('SHOULD fetch WHEN enabled changes to true', (tester) async {
    var fetchCount = 0;
    const expectedData = 'data';

    final hookResult = await buildHookWithProps(
      (enabled) => useQuery<String, Object>(
        queryKey: const ['enabled-test'],
        queryFn: () async {
          fetchCount++;
          await Future.delayed(const Duration(milliseconds: 100));
          return expectedData;
        },
        enabled: enabled,
        queryClient: client,
      ),
      initialProps: false,
    );

    expect(fetchCount, 0);
    expect(
      hookResult.current,
      isUseQueryResult(
        status: QueryStatus.pending,
        fetchStatus: FetchStatus.idle,
        data: null,
        dataUpdatedAt: null,
        error: null,
        errorUpdatedAt: null,
        errorUpdateCount: 0,
        isEnabled: false,
      ),
    );

    await hookResult.rebuildWithProps(true);

    expect(fetchCount, 1);
    expect(
      hookResult.current,
      isUseQueryResult(
        status: QueryStatus.pending,
        fetchStatus: FetchStatus.fetching,
        data: null,
        dataUpdatedAt: null,
        error: null,
        errorUpdatedAt: null,
        errorUpdateCount: 0,
        isEnabled: true,
      ),
    );

    await tester.pumpAndSettle();

    expect(fetchCount, 1);
    expect(
      hookResult.current,
      isUseQueryResult(
        status: QueryStatus.success,
        fetchStatus: FetchStatus.idle,
        data: expectedData,
        dataUpdatedAt: isA<DateTime>(),
        error: null,
        errorUpdatedAt: null,
        errorUpdateCount: 0,
        isEnabled: true,
      ),
    );
  });

  testWidgets('SHOULD fetch only once WHEN multiple hooks share same key',
      (tester) async {
    var fetchCount = 0;
    const sharedKey = ["key"];
    const expectedData = 'data';
    late UseQueryResult<String, Object> result1;
    late UseQueryResult<String, Object> result2;

    await tester.pumpWidget(Column(
      children: [
        HookBuilder(
          builder: (context) {
            result1 = useQuery<String, Object>(
              queryKey: sharedKey,
              queryFn: () async {
                fetchCount++;
                await Future.delayed(const Duration(milliseconds: 100));
                return expectedData;
              },
              queryClient: client,
            );
            return Container();
          },
        ),
        HookBuilder(
          builder: (context) {
            result2 = useQuery<String, Object>(
              queryKey: sharedKey,
              queryFn: () async {
                fetchCount++;
                await Future.delayed(const Duration(milliseconds: 100));
                return expectedData;
              },
              queryClient: client,
            );
            return Container();
          },
        ),
      ],
    ));

    expect(fetchCount, 1);
    for (final result in [result1, result2]) {
      expect(
        result,
        isUseQueryResult(
          status: QueryStatus.pending,
          fetchStatus: FetchStatus.fetching,
          data: null,
          dataUpdatedAt: null,
          error: null,
          errorUpdatedAt: null,
          errorUpdateCount: 0,
          isEnabled: true,
        ),
      );
    }

    await tester.pumpAndSettle();

    expect(fetchCount, 1);
    for (final result in [result1, result2]) {
      expect(
        result,
        isUseQueryResult(
          status: QueryStatus.success,
          fetchStatus: FetchStatus.idle,
          data: expectedData,
          dataUpdatedAt: isA<DateTime>(),
          error: null,
          errorUpdatedAt: null,
          errorUpdateCount: 0,
          isEnabled: true,
        ),
      );
    }
  });

  testWidgets('SHOULD fetch again WHEN queryKey changes', (tester) async {
    const key1 = ["key1"];
    const key2 = ["key2"];
    const expectedData1 = 'data1';
    const expectedData2 = 'data2';

    final hookResult = await buildHookWithProps(
      (record) => useQuery<String, Object>(
        queryKey: record.key,
        queryFn: () async {
          await Future.delayed(const Duration(milliseconds: 100));
          return record.data;
        },
        queryClient: client,
      ),
      initialProps: (key: key1, data: expectedData1),
    );

    expect(
      hookResult.current,
      isUseQueryResult(
        status: QueryStatus.pending,
        fetchStatus: FetchStatus.fetching,
        data: null,
        dataUpdatedAt: null,
        error: null,
        errorUpdatedAt: null,
        errorUpdateCount: 0,
        isEnabled: true,
      ),
    );

    await tester.pumpAndSettle();

    expect(
      hookResult.current,
      isUseQueryResult(
        status: QueryStatus.success,
        fetchStatus: FetchStatus.idle,
        data: expectedData1,
        dataUpdatedAt: isA<DateTime>(),
        error: null,
        errorUpdatedAt: null,
        errorUpdateCount: 0,
        isEnabled: true,
      ),
    );

    await hookResult.rebuildWithProps((key: key2, data: expectedData2));

    expect(
      hookResult.current,
      isUseQueryResult(
        status: QueryStatus.pending,
        fetchStatus: FetchStatus.fetching,
        data: null,
        dataUpdatedAt: null,
        error: null,
        errorUpdatedAt: null,
        errorUpdateCount: 0,
        isEnabled: true,
      ),
    );

    await tester.pumpAndSettle();

    expect(
      hookResult.current,
      isUseQueryResult(
        status: QueryStatus.success,
        fetchStatus: FetchStatus.idle,
        data: expectedData2,
        dataUpdatedAt: isA<DateTime>(),
        error: null,
        errorUpdatedAt: null,
        errorUpdateCount: 0,
        isEnabled: true,
      ),
    );
  });

  testWidgets('SHOULD clean up observers on unmount', (tester) async {
    const key = ['key'];

    final hookResult = await buildHook(
      () => useQuery(
        queryKey: key,
        queryFn: () async => 'data',
        queryClient: client,
      ),
    );

    await tester.pumpAndSettle();

    final query = client.cache.get(key)!;

    expect(query.hasObservers, true);

    await hookResult.unmount();

    expect(query.hasObservers, false);
  });

  testWidgets('SHOULD throw WHEN QueryClient is not provided', (tester) async {
    await tester.pumpWidget(HookBuilder(
      builder: (context) {
        useQuery<String, Object>(
          queryKey: const ['test'],
          queryFn: () async => 'data',
        );
        return Container();
      },
    ));

    // Check that a FlutterError was thrown during build
    final exception = tester.takeException();
    expect(exception, isA<FlutterError>());
  });

  testWidgets('SHOULD distinguish between different query keys',
      (tester) async {
    late UseQueryResult<String, Object> result1;
    late UseQueryResult<String, Object> result2;

    await tester.pumpWidget(Column(
      children: [
        HookBuilder(builder: (context) {
          result1 = useQuery<String, Object>(
            queryKey: const ['key1'],
            queryFn: () async => 'data1',
            queryClient: client,
          );
          return Container();
        }),
        HookBuilder(builder: (context) {
          result2 = useQuery<String, Object>(
            queryKey: const ['key2'],
            queryFn: () async => 'data2',
            queryClient: client,
          );
          return Container();
        }),
      ],
    ));

    await tester.pumpAndSettle();

    expect(result1.data, 'data1');
    expect(result2.data, 'data2');
  });

  group('staleTime', () {
    testWidgets('SHOULD mark data as stale WHEN staleTime is zero',
        (tester) async {
      final hookResult = await buildHook(
        () => useQuery(
          queryKey: const ['test'],
          queryFn: () async => 'data',
          staleTime: Duration.zero, // Data immediately stale
          queryClient: client,
        ),
      );

      await tester.pumpAndSettle();

      expect(hookResult.current.data, 'data');
      expect(hookResult.current.isStale, true);
    });

    testWidgets('SHOULD mark data as fresh WHEN within staleTime',
        (tester) async {
      final hookResult = await buildHook(
        () => useQuery(
          queryKey: const ['test'],
          queryFn: () async => 'data',
          staleTime: const Duration(minutes: 5), // Fresh for 5 minutes
          queryClient: client,
        ),
      );

      await tester.pumpAndSettle();

      expect(hookResult.current.data, 'data');
      expect(hookResult.current.isStale, false);
    });

    testWidgets('SHOULD update isStale WHEN staleTime changes', (tester) async {
      final hookResult = await buildHookWithProps(
        (staleTime) => useQuery(
          queryKey: const ['test'],
          queryFn: () async => 'data',
          staleTime: staleTime,
          queryClient: client,
        ),
        initialProps: const Duration(minutes: 5),
      );

      await tester.pumpAndSettle();

      expect(hookResult.current.data, 'data');
      expect(hookResult.current.isStale, false);

      // Change staleTime to zero to make data stale immediately
      await hookResult.rebuildWithProps(Duration.zero);

      expect(hookResult.current.isStale, true);
    });

    testWidgets('SHOULD refetch WHEN staleTime changes and data becomes stale',
        (tester) async {
      var fetchCount = 0;

      final hookResult = await buildHookWithProps(
        (staleTime) => useQuery(
          queryKey: const ['key'],
          queryFn: () async {
            fetchCount++;
            return 'data-$fetchCount';
          },
          staleTime: staleTime,
          queryClient: client,
        ),
        initialProps: const Duration(minutes: 5),
      );

      await tester.pumpAndSettle();

      // Initial fetch completed
      expect(hookResult.current.data, 'data-1');
      expect(hookResult.current.isStale, false);
      expect(fetchCount, 1);

      // Advance time by 3 seconds (less than initial staleTime, so still fresh)
      await tester.pump(const Duration(seconds: 3));

      // Data should still be fresh with 5-minute staleTime
      expect(hookResult.current.isStale, false);
      expect(fetchCount, 1);

      // Change staleTime to 2 seconds - data is now stale (3 seconds > 2 seconds)
      await hookResult.rebuildWithProps(const Duration(seconds: 2));

      // Should be fetching because data became stale with new staleTime
      expect(hookResult.current.fetchStatus, FetchStatus.fetching);
      expect(hookResult.current.data, 'data-1'); // Old data still available
      expect(hookResult.current.isStale, true);

      await tester.pumpAndSettle();

      // Should have new data now
      expect(hookResult.current.fetchStatus, FetchStatus.idle);
      expect(hookResult.current.data, 'data-2');
      expect(hookResult.current.isStale, false);
      expect(fetchCount, 2); // Fetched twice total
    });

    testWidgets(
        'SHOULD NOT refetch WHEN staleTime changes and data remains fresh',
        (tester) async {
      var fetchCount = 0;

      final hookResult = await buildHookWithProps(
        (staleTime) => useQuery(
          queryKey: const ['key'],
          queryFn: () async {
            fetchCount++;
            return 'data-$fetchCount';
          },
          staleTime: staleTime,
          queryClient: client,
        ),
        initialProps: const Duration(seconds: 5),
      );

      await tester.pumpAndSettle();

      // Initial fetch completed
      expect(hookResult.current.data, 'data-1');
      expect(hookResult.current.isStale, false);
      expect(fetchCount, 1);

      // Change staleTime to 5 minutes
      await hookResult.rebuildWithProps(const Duration(minutes: 5));

      // Advance time by 5 second (exceeds initial staleTime)
      await tester.pump(const Duration(seconds: 5));

      await tester.pumpAndSettle();

      // Should NOT have triggered a refetch because data is still fresh
      expect(hookResult.current.fetchStatus, FetchStatus.idle);
      expect(hookResult.current.data, 'data-1'); // Still old data
      expect(hookResult.current.isStale, false);
      expect(fetchCount, 1); // No additional fetch
    });

    testWidgets('SHOULD refetch WHEN data becomes stale', (tester) async {
      var fetchCount = 0;

      final hookResult = await buildHook(
        () => useQuery(
          queryKey: const ['key'],
          queryFn: () async {
            fetchCount++;
            return 'data-$fetchCount';
          },
          staleTime: const Duration(seconds: 5),
          queryClient: client,
        ),
      );

      await tester.pumpAndSettle();

      // Initial fetch completed
      expect(hookResult.current.data, 'data-1');
      expect(hookResult.current.isStale, false); // Fresh
      expect(fetchCount, 1);

      await hookResult.unmount();

      await tester.pump(const Duration(seconds: 5));

      await hookResult.rebuild();

      // Should be fetching because data is stale
      expect(hookResult.current.fetchStatus, FetchStatus.fetching);
      expect(hookResult.current.data, 'data-1'); // Old data still available
      expect(hookResult.current.isStale, true);

      await tester.pumpAndSettle();

      // Should have new data now
      expect(hookResult.current.fetchStatus, FetchStatus.idle);
      expect(hookResult.current.data, 'data-2');
      expect(hookResult.current.isStale, false);
      expect(fetchCount, 2); // Fetched twice total
    });

    testWidgets('SHOULD NOT refetch WHEN data is fresh on mount',
        (tester) async {
      var fetchCount = 0;
      const queryKey = ['fresh-no-refetch-test'];

      // Pre-populate cache with fresh data
      final query = client.cache.build<String>(
        queryKey,
        () async => 'initial',
      );
      await query.fetch();
      expect(fetchCount, 0);

      // Mount hook immediately with long staleTime, should NOT refetch
      final hookResult = await buildHook(
        () => useQuery(
          queryKey: queryKey,
          queryFn: () async {
            fetchCount++;
            return 'refetched';
          },
          staleTime: const Duration(minutes: 5), // Data stays fresh
          queryClient: client,
        ),
      );

      await tester.pumpAndSettle();

      // Should NOT have triggered a fetch
      expect(hookResult.current.fetchStatus, FetchStatus.idle);
      expect(hookResult.current.data, 'initial'); // Still has old data
      expect(hookResult.current.isStale, false); // Data is fresh
      expect(fetchCount, 0); // No fetch triggered
    });
  });
}
