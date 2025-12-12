import 'package:flutter/material.dart';

import 'package:clock/clock.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_hooks_test/flutter_hooks_test.dart';
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
    final startedAt = clock.now();
    final data = Object();

    final hookResult = await buildHook(
      () => useQuery(
        queryKey: const ['key'],
        queryFn: () async {
          // Take 5 seconds to finish
          await Future.delayed(const Duration(seconds: 5));
          return data;
        },
        queryClient: client,
      ),
    );

    var result = hookResult.current;
    expect(result.status, QueryStatus.pending);
    expect(result.fetchStatus, FetchStatus.fetching);
    expect(result.data, null);
    expect(result.dataUpdatedAt, null);
    expect(result.error, null);
    expect(result.errorUpdatedAt, null);
    expect(result.errorUpdateCount, 0);
    expect(result.isEnabled, true);

    // Wait 5 seconds for fetch to complete
    await tester.pump(const Duration(seconds: 5));

    result = hookResult.current;
    expect(result.status, QueryStatus.success);
    expect(result.fetchStatus, FetchStatus.idle);
    expect(result.data, same(data));
    expect(result.dataUpdatedAt, startedAt.add(const Duration(seconds: 5)));
    expect(result.error, null);
    expect(result.errorUpdatedAt, null);
    expect(result.errorUpdateCount, 0);
    expect(result.isEnabled, true);
  }));

  testWidgets('SHOULD fetch and fail', withCleanup((tester) async {
    final startedAt = clock.now();
    final error = Exception();

    final hookResult = await buildHook(
      () => useQuery(
        queryKey: const ['key'],
        queryFn: () async {
          // Take 5 seconds to finish
          await Future.delayed(const Duration(seconds: 5));
          throw error;
        },
        queryClient: client,
      ),
    );

    var result = hookResult.current;
    expect(result.status, QueryStatus.pending);
    expect(result.fetchStatus, FetchStatus.fetching);
    expect(result.data, null);
    expect(result.dataUpdatedAt, null);
    expect(result.error, null);
    expect(result.errorUpdatedAt, null);
    expect(result.errorUpdateCount, 0);
    expect(result.isEnabled, true);

    // Wait 5 seconds for fetch to complete
    await tester.pump(const Duration(seconds: 5));

    result = hookResult.current;
    expect(result.status, QueryStatus.error);
    expect(result.fetchStatus, FetchStatus.idle);
    expect(result.data, null);
    expect(result.dataUpdatedAt, null);
    expect(result.error, same(error));
    expect(result.errorUpdatedAt, startedAt.add(const Duration(seconds: 5)));
    expect(result.errorUpdateCount, 1);
    expect(result.isEnabled, true);
  }));

  testWidgets('SHOULD fetch only once WHEN multiple hooks share same key',
      withCleanup((tester) async {
    var fetchCount = 0;
    late UseQueryResult<String, Object> result1;
    late UseQueryResult<String, Object> result2;

    await tester.pumpWidget(Column(children: [
      HookBuilder(
        builder: (context) {
          result1 = useQuery(
            queryKey: ["key"],
            queryFn: () async => 'data-${++fetchCount}',
            queryClient: client,
          );
          return Container();
        },
      ),
      HookBuilder(
        builder: (context) {
          result2 = useQuery(
            queryKey: ["key"],
            queryFn: () async => 'data-${++fetchCount}',
            queryClient: client,
          );
          return Container();
        },
      ),
    ]));

    expect(result1.data, null);
    expect(result2.data, null);

    await tester.pumpAndSettle();

    expect(result1.data, 'data-1');
    expect(result2.data, 'data-1');
  }));

  testWidgets('SHOULD fetch fresh WHEN queryKey changes',
      withCleanup((tester) async {
    final hookResult = await buildHookWithProps(
      (key) => useQuery<String, Object>(
        queryKey: key,
        queryFn: () async => 'data-$key',
        queryClient: client,
      ),
      initialProps: const ['key1'],
    );

    expect(hookResult.current.data, null);

    await tester.pumpAndSettle();

    expect(hookResult.current.data, 'data-[key1]');

    await hookResult.rebuildWithProps(const ['key2']);

    expect(hookResult.current.data, null);

    await tester.pumpAndSettle();

    expect(hookResult.current.data, 'data-[key2]');
  }));

  testWidgets('SHOULD clean up observers on unmount',
      withCleanup((tester) async {
    final hookResult = await buildHook(
      () => useQuery(
        queryKey: const ['key'],
        queryFn: () async => 'data',
        queryClient: client,
      ),
    );

    await tester.pumpAndSettle();

    final query = client.cache.get(const ['key'])!;

    expect(query.hasObservers, true);

    await hookResult.unmount();

    expect(query.hasObservers, false);
  }));

  testWidgets('SHOULD distinguish between different query keys',
      withCleanup((tester) async {
    late UseQueryResult<String, Object> result1;
    late UseQueryResult<String, Object> result2;

    await tester.pumpWidget(Column(
      children: [
        HookBuilder(builder: (context) {
          result1 = useQuery(
            queryKey: const ['key1'],
            queryFn: () async => 'data1',
            queryClient: client,
          );
          return Container();
        }),
        HookBuilder(builder: (context) {
          result2 = useQuery(
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

  group('enabled', () {
    testWidgets('SHOULD NOT fetch WHEN enabled is false',
        withCleanup((tester) async {
      final hookResult = await buildHook(
        () => useQuery(
          queryKey: const ['key'],
          queryFn: () async => 'data',
          enabled: false,
          queryClient: client,
        ),
      );

      await tester.pumpAndSettle();

      expect(hookResult.current.status, QueryStatus.pending);
      expect(hookResult.current.data, null);
    }));

    testWidgets('SHOULD fetch WHEN enabled changes from false to true',
        withCleanup((tester) async {
      final hookResult = await buildHookWithProps(
        (enabled) => useQuery(
          queryKey: const ['key'],
          queryFn: () async => 'data',
          enabled: enabled,
          queryClient: client,
        ),
        initialProps: false,
      );

      await tester.pumpAndSettle();

      expect(hookResult.current.status, QueryStatus.pending);
      expect(hookResult.current.data, null);

      await hookResult.rebuildWithProps(true);

      expect(hookResult.current.fetchStatus, FetchStatus.fetching);

      await tester.pumpAndSettle();

      expect(hookResult.current.status, QueryStatus.success);
      expect(hookResult.current.data, 'data');
    }));
  });

  group('staleDuration', () {
    testWidgets('SHOULD mark data as stale WHEN staleDuration is zero',
        withCleanup((tester) async {
      final hookResult = await buildHook(
        () => useQuery(
          queryKey: const ['key'],
          queryFn: () async => 'data',
          staleDuration: StaleDuration.zero, // Data immediately stale
          queryClient: client,
        ),
      );

      // Wait for initial fetch to complete
      await tester.pumpAndSettle();

      expect(hookResult.current.isStale, true);
    }));

    testWidgets('SHOULD mark data as fresh WHEN within staleDuration',
        withCleanup((tester) async {
      final hookResult = await buildHook(
        () => useQuery(
          queryKey: const ['key'],
          queryFn: () async => 'data',
          staleDuration: const StaleDuration(minutes: 5), // Fresh for 5 minutes
          queryClient: client,
        ),
      );

      // Wait for initial fetch to complete
      await tester.pumpAndSettle();

      expect(hookResult.current.isStale, false);

      // Advance time by 3 minutes, still within 5 minute staleDuration
      await tester.binding.delayed(const Duration(minutes: 3));

      expect(hookResult.current.isStale, false);
    }));

    testWidgets('SHOULD update isStale WHEN staleDuration changes',
        withCleanup((tester) async {
      final hookResult = await buildHookWithProps(
        (staleDuration) => useQuery(
          queryKey: const ['key'],
          queryFn: () async => 'data',
          staleDuration: staleDuration,
          queryClient: client,
        ),
        initialProps: const StaleDuration(minutes: 5),
      );
      await tester.pumpAndSettle();

      expect(hookResult.current.isStale, false);

      // Change staleDuration to zero to make data stale immediately
      await hookResult.rebuildWithProps(StaleDuration.zero);
      expect(hookResult.current.isStale, true);

      // Change staleDuration to 10 mins to make data fresh again
      await hookResult.rebuildWithProps(const StaleDuration(minutes: 10));
      expect(hookResult.current.isStale, false);
    }));

    testWidgets(
        'SHOULD refetch WHEN staleDuration changes and data becomes stale',
        withCleanup((tester) async {
      final hookResult = await buildHookWithProps(
        (staleDuration) => useQuery(
          queryKey: const ['key'],
          queryFn: () async => 'data',
          staleDuration: staleDuration,
          queryClient: client,
        ),
        initialProps: const StaleDuration(minutes: 5),
      );

      // Wait for initial fetch to complete
      await tester.pumpAndSettle();

      // Advance time by 1 minute and,
      // Change staleDuration to 30 seconds, data must become stale
      await tester.binding.delayed(const Duration(minutes: 1));
      await hookResult.rebuildWithProps(const StaleDuration(seconds: 30));

      // Should be fetching because data became stale with new staleDuration
      expect(hookResult.current.fetchStatus, FetchStatus.fetching);
      expect(hookResult.current.isStale, true);

      // Wait for refetch to complete
      await tester.pumpAndSettle();

      // Should have fresh data now
      expect(hookResult.current.isStale, false);
    }));

    testWidgets(
        'SHOULD NOT refetch WHEN staleDuration changes and data remains fresh',
        withCleanup((tester) async {
      final hookResult = await buildHookWithProps(
        (staleDuration) => useQuery(
          queryKey: const ['key'],
          queryFn: () async => 'data',
          staleDuration: staleDuration,
          queryClient: client,
        ),
        initialProps: const StaleDuration(minutes: 5),
      );

      // Wait for initial fetch to complete
      await tester.pumpAndSettle();

      // Advance time by 8 minutes, exceeding initial staleDuration
      await tester.binding.delayed(const Duration(minutes: 8));
      // Change staleDuration to 10 minutes
      await hookResult.rebuildWithProps(const StaleDuration(minutes: 10));

      // Should NOT have triggered refetch because data is still fresh
      expect(hookResult.current.fetchStatus, FetchStatus.idle);
      expect(hookResult.current.isStale, false);
    }));

    testWidgets('SHOULD refetch on mount WHEN data becomes stale',
        withCleanup((tester) async {
      final hookResult = await buildHook(
        () => useQuery(
          queryKey: const ['key'],
          queryFn: () async => 'data',
          staleDuration: const StaleDuration(minutes: 5),
          queryClient: client,
        ),
      );

      // Wait for initial fetch to complete
      await tester.pumpAndSettle();

      // Unmount widget
      await hookResult.unmount();

      // Advance time by 5 minutes to exceed staleDuration
      await tester.binding.delayed(const Duration(minutes: 5));

      // Remount widget with hook
      await hookResult.rebuild();

      // Should be fetching because data is stale
      var result = hookResult.current;
      expect(result.fetchStatus, FetchStatus.fetching);
      expect(result.isStale, true);

      await tester.pumpAndSettle();

      // Should have fresh data
      result = hookResult.current;
      expect(result.fetchStatus, FetchStatus.idle);
      expect(result.isStale, false);
    }));

    testWidgets('SHOULD NOT refetch WHEN data is fresh on mount',
        withCleanup((tester) async {
      // Pre-populate cache with fresh data
      final query = client.cache.build(['key'], () async => 'initial');
      await query.fetch();

      final hookResult = await buildHook(
        () => useQuery(
          queryKey: ['key'],
          queryFn: () async => 'data',
          staleDuration: const StaleDuration(minutes: 5),
          queryClient: client,
        ),
      );

      // Should NOT have triggered a fetch
      final result = hookResult.current;
      expect(result.fetchStatus, FetchStatus.idle);
      expect(result.data, 'initial'); // Still has old data
      expect(result.isStale, false); // Data is fresh
    }));

    testWidgets('SHOULD NOT mark data as stale WHEN using static',
        withCleanup((tester) async {
      final hookResult = await buildHook(
        () => useQuery(
          queryKey: const ['key'],
          queryFn: () async => 'data',
          staleDuration: StaleDuration.static, // Never stale
          queryClient: client,
        ),
      );

      // Wait for initial fetch to complete
      await tester.pumpAndSettle();

      expect(hookResult.current.data, 'data');
      expect(hookResult.current.isStale, false);

      // Wait for long enough time
      await tester.binding.delayed(const Duration(hours: 24));

      // Should be still fresh
      expect(hookResult.current.isStale, false);
    }));

    testWidgets(
        'SHOULD NOT refetch on mount WHEN using static and time passed was shorter than gcDuration',
        withCleanup((tester) async {
      final hookResult = await buildHook(
        () => useQuery(
          queryKey: ['key'],
          queryFn: () async => 'data',
          staleDuration: StaleDuration.static,
          gcDuration: const GcDuration(minutes: 10),
          queryClient: client,
        ),
      );

      // Wait for initial fetch to complete
      await tester.pumpAndSettle();

      // Unmount, advance time by 5 minutes, and remount
      await hookResult.unmount();
      await tester.binding.delayed(const Duration(minutes: 5));
      await hookResult.rebuild();

      // Should NOT trigger refetch
      expect(hookResult.current.fetchStatus, FetchStatus.idle);
      expect(hookResult.current.data, 'data');
      expect(hookResult.current.isStale, false);
    }));

    testWidgets(
        'SHOULD refetch on mount WHEN using static and time passed was longer than gcDuration',
        withCleanup((tester) async {
      final hookResult = await buildHook(
        () => useQuery(
          queryKey: ['key'],
          queryFn: () async => 'data',
          staleDuration: StaleDuration.static,
          gcDuration: const GcDuration(minutes: 10),
          queryClient: client,
        ),
      );

      // Wait for initial fetch to complete
      await tester.pumpAndSettle();

      // Unmount, advance time by 10 minutes passing gcDuration, and remount
      await hookResult.unmount();
      await tester.binding.delayed(const Duration(minutes: 10));
      await hookResult.rebuild();

      // Should trigger refetch
      expect(hookResult.current.fetchStatus, FetchStatus.fetching);
      // Should be stale because there's no data
      expect(hookResult.current.isStale, true);

      await tester.pumpAndSettle();

      expect(hookResult.current.data, 'data');
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

      // Wait for initial fetch to complete
      await tester.pumpAndSettle();

      expect(hookResult.current.data, 'data');
      expect(hookResult.current.isStale, false);

      // Wait for long enough time
      await tester.binding.delayed(const Duration(hours: 24));

      // Should be still fresh
      expect(hookResult.current.isStale, false);
    }));

    testWidgets(
        'SHOULD NOT refetch on mount WHEN using infinity and time passed was shorter than gcDuration',
        withCleanup((tester) async {
      final hookResult = await buildHook(
        () => useQuery(
          queryKey: ['key'],
          queryFn: () async => 'data',
          staleDuration: StaleDuration.infinity,
          gcDuration: const GcDuration(minutes: 10),
          queryClient: client,
        ),
      );

      // Wait for initial fetch to complete
      await tester.pumpAndSettle();

      // Unmount, advance time by 5 minutes, and remount
      await hookResult.unmount();
      await tester.binding.delayed(const Duration(minutes: 5));
      await hookResult.rebuild();

      // Should NOT trigger refetch
      expect(hookResult.current.fetchStatus, FetchStatus.idle);
      expect(hookResult.current.data, 'data');
      expect(hookResult.current.isStale, false);
    }));

    testWidgets(
        'SHOULD refetch on mount WHEN using infinity and time passed was longer than gcDuration',
        withCleanup((tester) async {
      final hookResult = await buildHook(
        () => useQuery(
          queryKey: ['key'],
          queryFn: () async => 'data',
          staleDuration: StaleDuration.infinity,
          gcDuration: const GcDuration(minutes: 10),
          queryClient: client,
        ),
      );

      // Wait for initial fetch to complete
      await tester.pumpAndSettle();

      // Unmount, advance time by 10 minutes passing gcDuration, and remount
      await hookResult.unmount();
      await tester.binding.delayed(const Duration(minutes: 10));
      await hookResult.rebuild();

      // Should trigger refetch
      expect(hookResult.current.fetchStatus, FetchStatus.fetching);
      // Should be stale because there's no data
      expect(hookResult.current.isStale, true);

      await tester.pumpAndSettle();

      expect(hookResult.current.data, 'data');
      expect(hookResult.current.isStale, false);
    }));

    testWidgets('SHOULD resolve staleDuration dynamically with resolveWith',
        withCleanup((tester) async {
      var fetchCount = 0;
      final hookResult = await buildHookWithProps(
        (duration) {
          return useQuery<String, Object>(
            queryKey: const ['key'],
            queryFn: () async => 'data-${++fetchCount}',
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

      // Unmount and remount immediately
      await hookResult.unmount();
      await hookResult.rebuild();

      // No refetch should occur since data is still fresh (< 1 hour old)
      expect(hookResult.current.fetchStatus, FetchStatus.idle);
      expect(hookResult.current.isStale, false);

      // Advance time by 5 minutes, then change staleDuration to 5 minutes
      await hookResult.unmount();
      await tester.binding.delayed(const Duration(minutes: 5));
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
    }));

    testWidgets('SHOULD pass correct Query state to resolveWith callback',
        withCleanup((tester) async {
      late QueryState<String, Object> capturedState;

      await buildHook(
        () => useQuery<String, Object>(
          queryKey: const ['key1'],
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

    testWidgets('SHOULD default to zero WHEN staleDuration is not specified',
        withCleanup((tester) async {
      final hookResult = await buildHook(
        () => useQuery(
          queryKey: const ['key'],
          queryFn: () async => 'data',
          // staleDuration defaults to StaleDuration.zero
          queryClient: client,
        ),
      );

      // Wait for initial fetch to complete
      await tester.pumpAndSettle();

      // Should be immediately stale with zero stale duration
      expect(hookResult.current.isStale, true);
    }));
  });

  group('gcDuration', () {
    testWidgets('SHOULD remove cache WHEN time passes gcDuration',
        (tester) async {
      final hookResult = await buildHook(
        () => useQuery(
          queryKey: const ['key'],
          queryFn: () async => 'data',
          gcDuration: const GcDuration(minutes: 5),
          queryClient: client,
        ),
      );

      // Wait for initial fetch to complete
      await tester.pumpAndSettle();

      // Verify query is in cache
      expect(client.cache.get(const ['key']), isNotNull);

      // Unmount the hook (disposes observer)
      await hookResult.unmount();

      // Wait for gc duration
      await tester.binding.delayed(const Duration(minutes: 5));

      // Should remove query from cache
      expect(client.cache.get(const ['key']), isNull);
    });

    testWidgets('SHOULD NOT remove cache WHEN gcDuration is infinity',
        (tester) async {
      final hookResult = await buildHook(
        () => useQuery(
          queryKey: const ['key'],
          queryFn: () async => 'data',
          gcDuration: GcDuration.infinity,
          queryClient: client,
        ),
      );

      // Wait for initial fetch to complete
      await tester.pumpAndSettle();

      // Verify query is in cache
      expect(client.cache.get(const ['key']), isNotNull);

      // Unmount the hook
      await hookResult.unmount();

      // Wait long enough to ensure gc would have triggered if enabled
      await tester.binding.delayed(const Duration(hours: 24));

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
              useQuery(
                queryKey: const ['key'],
                queryFn: () async => 'data-1',
                gcDuration: const GcDuration(minutes: 5),
                queryClient: client,
              );
              return Container();
            },
          ),
          HookBuilder(
            builder: (context) {
              useQuery(
                queryKey: const ['key'],
                queryFn: () async => 'data-2',
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
      expect(client.cache.get(const ['key']), isNotNull);

      // Remove first hook from widget tree
      await tester.pumpWidget(Column(
        children: [
          HookBuilder(
            builder: (context) {
              useQuery(
                queryKey: const ['key'],
                queryFn: () async => 'data-2',
                gcDuration: const GcDuration(minutes: 5),
                queryClient: client,
              );
              return Container();
            },
          ),
        ],
      ));

      // Wait for gc duration
      await tester.binding.delayed(const Duration(minutes: 5));

      // Query should still be in cache because second hook is still subscribed
      expect(client.cache.get(const ['key']), isNotNull);

      // Remove second hook
      await tester.pumpWidget(Container());

      // Wait for gc duration again
      await tester.binding.delayed(const Duration(minutes: 5));

      // Now query should be removed
      expect(client.cache.get(const ['key']), isNull);
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

      // Check if cache exists every minute 5 times
      for (var i = 0; i < 5; i++) {
        expect(client.cache.get(const ['key']), isNotNull);
        await tester.pump(const Duration(minutes: 1));
      }

      // Query should be removed after 5 minutes
      expect(client.cache.get(const ['key']), isNull);
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
      await tester.binding.delayed(const Duration(minutes: 5));

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
