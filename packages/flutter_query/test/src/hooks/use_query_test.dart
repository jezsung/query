import 'package:flutter/material.dart';

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_hooks_test/flutter_hooks_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_query/flutter_query.dart';
import '../../matchers/use_query_result_matcher.dart';

void main() {
  late QueryClient client;

  setUp(() {
    client = QueryClient();
  });

  tearDown(() {
    client.dispose();
  });

  /// Helper function to run a test with automatic cache cleanup.
  ///
  /// This ensures proper cleanup order:
  /// 1. Test body completes
  /// 2. Widget tree is unmounted (disposes QueryObservers)
  /// 3. Cache is cleared (prevents GC timers from being scheduled)
  ///
  /// Usage:
  /// ```dart
  /// testWidgets('my test', withCleanup((tester) async {
  ///   // test body
  /// }));
  /// ```
  WidgetTesterCallback withCleanup(
    Future<void> Function(WidgetTester) testBody,
  ) {
    return (WidgetTester tester) async {
      await testBody(tester);

      // Unmount widget tree first (disposes QueryObservers)
      await tester.pumpWidget(Container());

      // Then dispose cache to prevent new GC timers
      client.dispose();
    };
  }

  testWidgets('SHOULD fetch and succeed', withCleanup((tester) async {
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
  }));

  testWidgets('SHOULD fetch and fail', withCleanup((tester) async {
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
  }));

  testWidgets('SHOULD NOT fetch WHEN enabled is false',
      withCleanup((tester) async {
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
  }));

  testWidgets('SHOULD fetch WHEN enabled changes to true',
      withCleanup((tester) async {
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
  }));

  testWidgets('SHOULD fetch only once WHEN multiple hooks share same key',
      withCleanup((tester) async {
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
  }));

  testWidgets('SHOULD fetch again WHEN queryKey changes',
      withCleanup((tester) async {
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
  }));

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

    // Clean up to prevent pending GC timer
    client.cache.clear();
  });

  testWidgets('SHOULD distinguish between different query keys',
      withCleanup((tester) async {
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
  }));

  group('staleDuration', () {
    testWidgets('SHOULD mark data as stale WHEN staleDuration is zero',
        withCleanup((tester) async {
      final hookResult = await buildHook(
        () => useQuery(
          queryKey: const ['test'],
          queryFn: () async => 'data',
          staleDuration: StaleDuration.zero, // Data immediately stale
          queryClient: client,
        ),
      );

      await tester.pumpAndSettle();

      expect(hookResult.current.data, 'data');
      expect(hookResult.current.isStale, true);
    }));

    testWidgets('SHOULD mark data as fresh WHEN within staleDuration',
        withCleanup((tester) async {
      final hookResult = await buildHook(
        () => useQuery(
          queryKey: const ['test'],
          queryFn: () async => 'data',
          staleDuration: const StaleDuration(minutes: 5), // Fresh for 5 minutes
          queryClient: client,
        ),
      );

      await tester.pumpAndSettle();

      expect(hookResult.current.data, 'data');
      expect(hookResult.current.isStale, false);
    }));

    testWidgets('SHOULD update isStale WHEN staleDuration changes',
        withCleanup((tester) async {
      final hookResult = await buildHookWithProps(
        (staleDuration) => useQuery(
          queryKey: const ['test'],
          queryFn: () async => 'data',
          staleDuration: staleDuration,
          queryClient: client,
        ),
        initialProps: const StaleDuration(minutes: 5),
      );

      await tester.pumpAndSettle();

      expect(hookResult.current.data, 'data');
      expect(hookResult.current.isStale, false);

      // Change staleDuration to zero to make data stale immediately
      await hookResult.rebuildWithProps(StaleDuration.zero);

      expect(hookResult.current.isStale, true);
    }));

    testWidgets(
        'SHOULD refetch WHEN staleDuration changes and data becomes stale',
        withCleanup((tester) async {
      var fetchCount = 0;

      final hookResult = await buildHookWithProps(
        (staleDuration) => useQuery(
          queryKey: const ['key'],
          queryFn: () async {
            fetchCount++;
            return 'data-$fetchCount';
          },
          staleDuration: staleDuration,
          queryClient: client,
        ),
        initialProps: const StaleDuration(minutes: 5),
      );

      await tester.pumpAndSettle();

      // Initial fetch completed
      expect(hookResult.current.data, 'data-1');
      expect(hookResult.current.isStale, false);
      expect(fetchCount, 1);

      // Advance time by 3 seconds (less than initial staleDuration, so still fresh)
      await tester.pump(const Duration(seconds: 3));

      // Data should still be fresh with 5-minute staleDuration
      expect(hookResult.current.isStale, false);
      expect(fetchCount, 1);

      // Change staleDuration to 2 seconds - data is now stale (3 seconds > 2 seconds)
      await hookResult.rebuildWithProps(const StaleDuration(seconds: 2));

      // Should be fetching because data became stale with new staleDuration
      expect(hookResult.current.fetchStatus, FetchStatus.fetching);
      expect(hookResult.current.data, 'data-1'); // Old data still available
      expect(hookResult.current.isStale, true);

      await tester.pumpAndSettle();

      // Should have new data now
      expect(hookResult.current.fetchStatus, FetchStatus.idle);
      expect(hookResult.current.data, 'data-2');
      expect(hookResult.current.isStale, false);
      expect(fetchCount, 2); // Fetched twice total
    }));

    testWidgets(
        'SHOULD NOT refetch WHEN staleDuration changes and data remains fresh',
        withCleanup((tester) async {
      var fetchCount = 0;

      final hookResult = await buildHookWithProps(
        (staleDuration) => useQuery(
          queryKey: const ['key'],
          queryFn: () async {
            fetchCount++;
            return 'data-$fetchCount';
          },
          staleDuration: staleDuration,
          queryClient: client,
        ),
        initialProps: const StaleDuration(seconds: 5),
      );

      await tester.pumpAndSettle();

      // Initial fetch completed
      expect(hookResult.current.data, 'data-1');
      expect(hookResult.current.isStale, false);
      expect(fetchCount, 1);

      // Change staleDuration to 5 minutes
      await hookResult.rebuildWithProps(const StaleDuration(minutes: 5));

      // Advance time by 5 second (exceeds initial staleDuration)
      await tester.pump(const Duration(seconds: 5));

      await tester.pumpAndSettle();

      // Should NOT have triggered a refetch because data is still fresh
      expect(hookResult.current.fetchStatus, FetchStatus.idle);
      expect(hookResult.current.data, 'data-1'); // Still old data
      expect(hookResult.current.isStale, false);
      expect(fetchCount, 1); // No additional fetch
    }));

    testWidgets('SHOULD refetch WHEN data becomes stale',
        withCleanup((tester) async {
      var fetchCount = 0;

      final hookResult = await buildHook(
        () => useQuery(
          queryKey: const ['key'],
          queryFn: () async {
            fetchCount++;
            return 'data-$fetchCount';
          },
          staleDuration: const StaleDuration(seconds: 5),
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
    }));

    testWidgets('SHOULD NOT refetch WHEN data is fresh on mount',
        withCleanup((tester) async {
      var fetchCount = 0;
      const queryKey = ['fresh-no-refetch-test'];

      // Pre-populate cache with fresh data
      final query = client.cache.build(queryKey, () async => 'initial');
      await query.fetch();
      expect(fetchCount, 0);

      // Mount hook immediately with long sta leTime, should NOT refetch
      final hookResult = await buildHook(
        () => useQuery(
          queryKey: queryKey,
          queryFn: () async {
            fetchCount++;
            return 'refetched';
          },
          staleDuration: const StaleDuration(minutes: 5), // Data stays fresh
          queryClient: client,
        ),
      );

      await tester.pumpAndSettle();

      // Should NOT have triggered a fetch
      expect(hookResult.current.fetchStatus, FetchStatus.idle);
      expect(hookResult.current.data, 'initial'); // Still has old data
      expect(hookResult.current.isStale, false); // Data is fresh
      expect(fetchCount, 0); // No fetch triggered
    }));

    testWidgets('SHOULD NOT mark data as stale WHEN using static',
        withCleanup((tester) async {
      final hookResult = await buildHook(
        () => useQuery(
          queryKey: const ['test-static'],
          queryFn: () async => 'data',
          staleDuration: StaleDuration.static, // Never stale
          queryClient: client,
        ),
      );

      await tester.pumpAndSettle();

      expect(hookResult.current.data, 'data');
      expect(hookResult.current.isStale, false);
    }));

    testWidgets(
        'SHOULD NOT refetch on mount WHEN using static and time passed was shorter than gcDuration',
        withCleanup((tester) async {
      // Pre-populate cache with data
      final query = client.cache.build(['key'], () async => 'initial');
      await query.fetch();

      // Mount hook with static staleDuration and 10 min gcDuration
      var fetchCount = 0;
      final hookResult = await buildHook(
        () => useQuery(
          queryKey: ['key'],
          queryFn: () async => 'data-${++fetchCount}',
          staleDuration: StaleDuration.static,
          gcDuration: const GcDuration(minutes: 10),
          queryClient: client,
        ),
      );

      await tester.pumpAndSettle();

      // Should NOT have triggered a fetch
      expect(hookResult.current.data, 'initial');
      expect(hookResult.current.isStale, false);

      // Unmount and wait 5 minutes (less than 10 min gcDuration)
      await hookResult.unmount();
      await tester.pump(const Duration(minutes: 5));

      // Remount - cache still exists, should not refetch
      await hookResult.rebuild();
      await tester.pumpAndSettle();

      expect(hookResult.current.data, 'initial');
      expect(hookResult.current.isStale, false);
    }));

    testWidgets(
        'SHOULD refetch on mount WHEN using static and time passed was longer than gcDuration',
        withCleanup((tester) async {
      // Pre-populate cache with data
      final query = client.cache.build(['key'], () async => 'initial');
      await query.fetch();

      // Mount hook with static staleDuration and 10 min gcDuration
      var fetchCount = 0;
      final hookResult = await buildHook(
        () => useQuery(
          queryKey: ['key'],
          queryFn: () async => 'data-${++fetchCount}',
          staleDuration: StaleDuration.static,
          gcDuration: const GcDuration(minutes: 10),
          queryClient: client,
        ),
      );

      await tester.pumpAndSettle();

      // Should NOT have triggered a fetch initially
      expect(hookResult.current.data, 'initial');
      expect(hookResult.current.isStale, false);

      // Unmount and wait 10 minutes (equals to 10 min gcDuration)
      await hookResult.unmount();
      await tester.pump(const Duration(minutes: 10));

      // Remount - cache is gone, MUST refetch
      await hookResult.rebuild();
      await tester.pumpAndSettle();

      expect(hookResult.current.data, 'data-1');
      expect(hookResult.current.isStale, false);
    }));

    testWidgets('SHOULD NOT mark data as stale WHEN using infinity',
        withCleanup((tester) async {
      final hookResult = await buildHook(
        () => useQuery(
          queryKey: const ['key'],
          queryFn: () async => 'data',
          staleDuration: StaleDuration.infinity, // Never stale
          queryClient: client,
        ),
      );

      await tester.pumpAndSettle();

      expect(hookResult.current.data, 'data');
      expect(hookResult.current.isStale, false);
    }));

    testWidgets(
        'SHOULD NOT refetch on mount WHEN using infinity and time passed was shorter than gcDuration',
        withCleanup((tester) async {
      // Pre-populate cache with data
      final query = client.cache.build(['key'], () async => 'initial');
      await query.fetch();

      // Mount hook with infinity staleDuration and 10 min gcDuration
      var fetchCount = 0;
      final hookResult = await buildHook(
        () => useQuery(
          queryKey: ['key'],
          queryFn: () async => 'data-${++fetchCount}',
          staleDuration: StaleDuration.infinity,
          gcDuration: const GcDuration(minutes: 10),
          queryClient: client,
        ),
      );

      await tester.pumpAndSettle();

      // Should NOT have triggered a fetch
      expect(hookResult.current.data, 'initial');
      expect(hookResult.current.isStale, false);

      // Unmount and wait 5 minutes (less than 10 min gcDuration)
      await hookResult.unmount();
      await tester.pump(const Duration(minutes: 5));

      // Remount - cache still exists, should not refetch
      await hookResult.rebuild();
      await tester.pumpAndSettle();

      expect(hookResult.current.data, 'initial');
      expect(hookResult.current.isStale, false);
    }));

    testWidgets(
        'SHOULD refetch on mount WHEN using infinity and time passed was longer than gcDuration',
        withCleanup((tester) async {
      // Pre-populate cache with data
      final query = client.cache.build(['key'], () async => 'initial');
      await query.fetch();

      // Mount hook with infinity staleDuration and 10 min gcDuration
      var fetchCount = 0;
      final hookResult = await buildHook(
        () => useQuery(
          queryKey: ['key'],
          queryFn: () async => 'data-${++fetchCount}',
          staleDuration: StaleDuration.infinity,
          gcDuration: const GcDuration(minutes: 10),
          queryClient: client,
        ),
      );

      await tester.pumpAndSettle();

      // Should NOT have triggered a fetch initially
      expect(hookResult.current.data, 'initial');
      expect(hookResult.current.isStale, false);

      // Unmount and wait 10 minutes (equals to 10 min gcDuration)
      await hookResult.unmount();
      await tester.pump(const Duration(minutes: 10));

      // Remount - cache is gone, MUST refetch
      await hookResult.rebuild();
      await tester.pumpAndSettle();

      expect(hookResult.current.data, 'data-1');
      expect(hookResult.current.isStale, false);
    }));

    testWidgets('SHOULD resolve staleDuration dynamically with resolveWith',
        withCleanup((tester) async {
      var fetchCount = 0;

      final hookResult = await buildHookWithProps(
        (duration) {
          return useQuery<String, Object>(
            queryKey: const ['resolve-test'],
            queryFn: () async {
              fetchCount++;
              return 'data-$fetchCount';
            },
            staleDuration: StaleDuration.resolveWith((query) {
              // Resolve to different durations based on external state
              return duration;
            }),
            queryClient: client,
          );
        },
        initialProps: StaleDuration(hours: 1),
      );

      // Wait for initial fetch to complete
      await tester.pumpAndSettle();

      // Initial fetch should succeed with 1 hour staleDuration
      expect(hookResult.current.data, 'data-1');
      expect(hookResult.current.isStale, false);
      expect(fetchCount, 1);

      // Unmount and remount immediately - data should still be fresh
      await hookResult.unmount();
      await hookResult.rebuild();

      // No refetch should occur since data is still fresh (< 1 hour old)
      expect(hookResult.current.fetchStatus, FetchStatus.idle);
      expect(hookResult.current.isStale, false);

      // Advance time by 5 minutes, then change staleDuration to 5 minutes
      await tester.pump(const Duration(minutes: 5));
      await hookResult.unmount();
      await hookResult.rebuildWithProps(const StaleDuration(minutes: 5));

      // Now data is stale (5 minutes old with 5 minute staleDuration)
      // Should trigger refetch on remount
      expect(hookResult.current.fetchStatus, FetchStatus.fetching);
      expect(hookResult.current.isStale, true);

      // Wait for refetch to complete
      await tester.pumpAndSettle();

      // Second fetch should succeed with fresh data
      expect(hookResult.current.data, 'data-2');
      expect(hookResult.current.isStale, false);
      expect(fetchCount, 2);
    }));

    testWidgets('SHOULD pass correct Query state to resolveWith callback',
        withCleanup((tester) async {
      late QueryState<String, Object> capturedState;

      await buildHook(
        () => useQuery<String, Object>(
          queryKey: const ['ke1'],
          queryFn: () async => 'data',
          staleDuration: StaleDuration.resolveWith<String, Object>((query) {
            // Capture the query state for inspection
            capturedState = query.state;
            return StaleDuration.zero;
          }),
          queryClient: client,
        ),
      );

      await tester.pumpAndSettle();

      // Query should have success state with data
      expect(capturedState.status, QueryStatus.success);
      expect(capturedState.data, 'data');
      expect(capturedState.dataUpdatedAt, isA<DateTime>());
      expect(capturedState.error, null);
      expect(capturedState.errorUpdatedAt, null);
      expect(capturedState.errorUpdateCount, 0);

      await buildHook(
        () => useQuery<String, Object>(
          queryKey: const ['key2'],
          queryFn: () async => throw Exception(),
          staleDuration: StaleDuration.resolveWith<String, Object>((query) {
            // Capture the query state for inspection
            capturedState = query.state;
            return StaleDuration.zero;
          }),
          queryClient: client,
        ),
      );

      await tester.pumpAndSettle();

      // Query should have error state with error
      expect(capturedState.status, QueryStatus.error);
      expect(capturedState.data, null);
      expect(capturedState.dataUpdatedAt, null);
      expect(capturedState.error, isA<Exception>());
      expect(capturedState.errorUpdatedAt, isA<DateTime>());
      expect(capturedState.errorUpdateCount, 1);
    }));

    testWidgets('SHOULD default to zero when staleDuration not specified',
        withCleanup((tester) async {
      final hookResult = await buildHook(
        () => useQuery(
          queryKey: const ['default-stale'],
          queryFn: () async => 'data',
          // staleDuration defaults to StaleDuration.zero
          queryClient: client,
        ),
      );

      await tester.pumpAndSettle();

      expect(hookResult.current.data, 'data');
      expect(hookResult.current.isStale, true); // Immediately stale with zero
    }));
  });

  group('gcDuration', () {
    testWidgets('SHOULD remove cache WHEN gcDuration is passed',
        (tester) async {
      final hookResult = await buildHook(
        () => useQuery(
          queryKey: const ['key'],
          queryFn: () async => 'data',
          gcDuration: const GcDuration(minutes: 5),
          queryClient: client,
        ),
      );

      await tester.pumpAndSettle();

      // Verify query is in cache
      expect(client.cache.get(const ['key']), isNotNull);

      // Unmount the hook (disposes observer)
      await hookResult.unmount();

      // Wait for shorter than gc duration
      await tester.pump(const Duration(minutes: 3));

      // Query should still exist
      expect(client.cache.get(const ['key']), isNotNull);

      // Wait for 2 more mins
      await tester.pump(const Duration(minutes: 2));

      // Query should now be removed from cache
      expect(client.cache.get(const ['key']), isNull);
    });

    testWidgets('SHOULD NOT remove cache WHEN gcDuration is infinity',
        (tester) async {
      final hookResult = await buildHook(
        () => useQuery(
          queryKey: const ['key'],
          queryFn: () async => 'data',
          gcDuration: GcDuration.infinity, // Disable gc
          queryClient: client,
        ),
      );

      await tester.pumpAndSettle();

      // Verify query is in cache
      expect(client.cache.get(const ['key']), isNotNull);

      // Unmount the hook
      await hookResult.unmount();

      // Wait long enough to ensure gc would have triggered if enabled
      await tester.pump(const Duration(hours: 24));

      // Query should still be in cache
      expect(client.cache.get(const ['key']), isNotNull);
    });

    testWidgets('SHOULD NOT remove cache WHEN another hook is still subscribed',
        (tester) async {
      // Create two observers on the same query using HookBuilder
      await tester.pumpWidget(Column(
        children: [
          HookBuilder(
            builder: (context) {
              useQuery<String, Object>(
                queryKey: const ['shared-key'],
                queryFn: () async => 'data',
                gcDuration: const GcDuration(minutes: 5),
                queryClient: client,
              );
              return Container();
            },
          ),
          HookBuilder(
            builder: (context) {
              useQuery<String, Object>(
                queryKey: const ['shared-key'],
                queryFn: () async => 'data',
                gcDuration: const GcDuration(minutes: 5),
                queryClient: client,
              );
              return Container();
            },
          ),
        ],
      ));

      await tester.pumpAndSettle();

      // Cache should exist
      expect(client.cache.get(const ['shared-key']), isNotNull);

      // Remove first hook from widget tree
      await tester.pumpWidget(Column(
        children: [
          HookBuilder(
            builder: (context) {
              useQuery<String, Object>(
                queryKey: const ['shared-key'],
                queryFn: () async => 'data',
                gcDuration: const GcDuration(minutes: 5),
                queryClient: client,
              );
              return Container();
            },
          ),
        ],
      ));

      // Wait for gc duration
      await tester.pump(const Duration(minutes: 5));

      // Query should still be in cache because second hook is still subscribed
      expect(client.cache.get(const ['shared-key']), isNotNull);

      // Remove second hook
      await tester.pumpWidget(Container());

      // Wait for gc duration again
      await tester.pump(const Duration(minutes: 5));

      // Now query should be removed
      expect(client.cache.get(const ['shared-key']), isNull);
    });

    testWidgets('SHOULD default to 5 mins WHEN gcDuration is not specified',
        withCleanup((tester) async {
      final hookResult = await buildHook(
        () => useQuery(
          queryKey: const ['key'],
          queryFn: () async => 'data',
          // gcDuration defaults to 5 minutes
          queryClient: client,
        ),
      );

      await tester.pumpAndSettle();

      // Verify query is in cache
      expect(client.cache.get(const ['key']), isNotNull);

      // Unmount the hook
      await hookResult.unmount();

      // Wait for a short duration (less than 5 minutes)
      await tester.pump(const Duration(minutes: 1));

      // Query should still be in cache (default 5 minute gc hasn't triggered)
      expect(client.cache.get(const ['key']), isNotNull);
    }));

    testWidgets('SHOULD cancel gc timer WHEN hook resubscribes',
        withCleanup((tester) async {
      final hookResult = await buildHook(
        () => useQuery(
          queryKey: const ['key'],
          queryFn: () async => 'data',
          gcDuration: const GcDuration(minutes: 10),
          queryClient: client,
        ),
      );

      await tester.pumpAndSettle();

      // Unmount (starts gc timer)
      await hookResult.unmount();

      // Wait halfway through gc duration
      await tester.pump(const Duration(minutes: 5));

      // Rebuild before gc triggers (cancels gc timer)
      await hookResult.rebuild();

      // Wait past original gc duration (5 mins + 5 mins = 10 mins)
      await tester.pump(const Duration(minutes: 5));

      // Query should still be in cache because rebuild cancelled gc
      expect(client.cache.get(const ['key']), isNotNull);
    }));
  });

  group('queryClient', () {
    testWidgets('SHOULD find QueryClient provided by QueryClientProvider',
        withCleanup((tester) async {
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
    }));

    testWidgets('SHOULD prioritize queryClient over QueryClientProvider',
        withCleanup((tester) async {
      final prioritizedQueryClient = QueryClient();

      final hookResult = await buildHook(
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

      await hookResult.unmount();
      prioritizedQueryClient.dispose();
    }));

    testWidgets('SHOULD throw WHEN QueryClient is not provided',
        (tester) async {
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
  });
}
