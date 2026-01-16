import 'package:flutter/material.dart';

import 'package:clock/clock.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_hooks_test/flutter_hooks_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_query/src/core/core.dart';
import 'package:flutter_query/src/hooks/use_query.dart';
import 'package:flutter_query/src/widgets/query_client_provider.dart';

extension on WidgetTester {
  Future<void> pumpUntil(DateTime target) async {
    final duration = target.difference(clock.now());

    if (duration.isNegative) {
      throw Exception('Cannot pump to a time in the past');
    }

    await pump(duration);
  }
}

void main() {
  late QueryClient client;

  setUp(() {
    client = QueryClient();
  });

  tearDown(() {
    client.clear();
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

      // Then clear cache to prevent new GC timers
      client.clear();

      // Wait until all pending timers finish
      await tester.binding.delayed(const Duration(days: 365));
    };
  }

  testWidgets('SHOULD fetch and succeed', withCleanup((tester) async {
    final startedAt = clock.now();
    final data = Object();

    final hookResult = await buildHook(
      () => useQuery(
        const ['key'],
        (context) async {
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
    expect(result.failureCount, 0);
    expect(result.failureReason, null);
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
    expect(result.failureCount, 0);
    expect(result.failureReason, null);
    expect(result.isEnabled, true);
  }));

  testWidgets('SHOULD fetch and fail', withCleanup((tester) async {
    final startedAt = clock.now();
    final error = Exception();

    final hookResult = await buildHook(
      () => useQuery<String, Object>(
        const ['key'],
        (context) async {
          // Take 5 seconds to finish
          await Future.delayed(const Duration(seconds: 5));
          throw error;
        },
        retry: (_, __) => null,
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
    expect(result.failureCount, 0);
    expect(result.failureReason, null);
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
    expect(result.failureCount, 1);
    expect(result.failureReason, same(error));
    expect(result.isEnabled, true);
  }));

  testWidgets('SHOULD pass QueryFunctionContext to queryFn',
      withCleanup((tester) async {
    QueryFunctionContext? capturedContext;
    final queryKey = ['users', 123];

    await buildHook(
      () => useQuery(
        queryKey,
        (context) async {
          capturedContext = context;
          return 'data';
        },
        queryClient: client,
      ),
    );

    await tester.pump();

    expect(capturedContext, isNotNull);
    expect(capturedContext!.queryKey, equals(queryKey));
    expect(capturedContext!.client, same(client));
  }));

  testWidgets('SHOULD fetch and succeed (synchronous queryFn)',
      withCleanup((tester) async {
    final data = Object();

    final hookResult = await buildHook(
      () => useQuery(
        const ['key'],
        (context) async => data,
        queryClient: client,
      ),
    );

    var result = hookResult.current;
    expect(result.status, QueryStatus.pending);
    expect(result.fetchStatus, FetchStatus.fetching);
    expect(result.data, null);

    await tester.pump();

    result = hookResult.current;
    expect(result.status, QueryStatus.success);
    expect(result.fetchStatus, FetchStatus.idle);
    expect(result.data, same(data));
  }));

  testWidgets('SHOULD fetch only once WHEN multiple hooks share same key',
      withCleanup((tester) async {
    var fetchCount = 0;
    late QueryResult<String, Object> result1;
    late QueryResult<String, Object> result2;

    await tester.pumpWidget(Column(children: [
      HookBuilder(
        builder: (context) {
          result1 = useQuery(
            ["key"],
            (context) async => 'data-${++fetchCount}',
            queryClient: client,
          );
          return Container();
        },
      ),
      HookBuilder(
        builder: (context) {
          result2 = useQuery(
            ["key"],
            (context) async => 'data-${++fetchCount}',
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
        key,
        (context) async => 'data-$key',
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
        const ['key'],
        (context) async => 'data',
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
    late QueryResult<String, Object> result1;
    late QueryResult<String, Object> result2;

    await tester.pumpWidget(Column(
      children: [
        HookBuilder(builder: (context) {
          result1 = useQuery(
            const ['key1'],
            (context) async => 'data1',
            queryClient: client,
          );
          return Container();
        }),
        HookBuilder(builder: (context) {
          result2 = useQuery(
            const ['key2'],
            (context) async => 'data2',
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
          const ['key'],
          (context) async => 'data',
          enabled: false,
          queryClient: client,
        ),
      );

      // Advance to resolve the delayed fetch
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(hookResult.current.status, QueryStatus.pending);
      expect(hookResult.current.data, null);
    }));

    testWidgets('SHOULD fetch WHEN enabled changes from false to true',
        withCleanup((tester) async {
      final hookResult = await buildHookWithProps(
        (enabled) => useQuery(
          const ['key'],
          (context) async => 'data',
          enabled: enabled,
          queryClient: client,
        ),
        initialProps: false,
      );

      // Advance to resolve the delayed fetch
      await tester.pump(const Duration(seconds: 2));
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
          const ['key'],
          (context) async => 'data',
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
          const ['key'],
          (context) async => 'data',
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
          const ['key'],
          (context) async => 'data',
          staleDuration: staleDuration,
          queryClient: client,
        ),
        initialProps: const StaleDuration(minutes: 5),
      );
      await tester.pumpAndSettle();

      expect(hookResult.current.isStale, false);

      // Change staleDuration to zero to make data stale immediately
      await hookResult.rebuildWithProps(const StaleDuration());
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
          const ['key'],
          (context) async => 'data',
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
          const ['key'],
          (context) async => 'data',
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
          const ['key'],
          (context) async => 'data',
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
      final query = client.cache.build(QueryOptions<String, Object>(
        ['key'],
        (context) async => 'initial',
      ));
      await query.fetch();

      final hookResult = await buildHook(
        () => useQuery<String, Object>(
          ['key'],
          (context) async => 'data',
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

    testWidgets('SHOULD NOT mark data as stale WHEN using never',
        withCleanup((tester) async {
      final hookResult = await buildHook(
        () => useQuery(
          const ['key'],
          (context) async => 'data',
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
        'SHOULD NOT refetch on mount WHEN using never and time passed was shorter than gcDuration',
        withCleanup((tester) async {
      final hookResult = await buildHook(
        () => useQuery(
          ['key'],
          (context) async => 'data',
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
        'SHOULD refetch on mount WHEN using never and time passed was longer than gcDuration',
        withCleanup((tester) async {
      final hookResult = await buildHook(
        () => useQuery(
          ['key'],
          (context) async => 'data',
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

    testWidgets(
        'SHOULD NOT mark data as stale WHEN using StaleDuration.infinity',
        withCleanup((tester) async {
      final hookResult = await buildHook(
        () => useQuery(
          const ['key'],
          (context) async => 'data',
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
        'SHOULD NOT refetch on mount WHEN using StaleDuration.infinity and time passed was shorter than gcDuration',
        withCleanup((tester) async {
      final hookResult = await buildHook(
        () => useQuery(
          ['key'],
          (context) async => 'data',
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
        'SHOULD refetch on mount WHEN using StaleDuration.infinity and time passed was longer than gcDuration',
        withCleanup((tester) async {
      final hookResult = await buildHook(
        () => useQuery(
          ['key'],
          (context) async => 'data',
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

    // TODO(staleDurationResolver): Re-enable when callback form is supported
    // testWidgets('SHOULD resolve staleDuration dynamically with resolveWith',
    //     withCleanup((tester) async {
    //   var fetchCount = 0;
    //   final hookResult = await buildHookWithProps(
    //     (duration) {
    //       return useQuery(
    //         const ['key'],
    //         (context) async => 'data-${++fetchCount}',
    //         staleDurationResolver: (query) {
    //           // Resolve to different durations based on external state
    //           return duration;
    //         },
    //         queryClient: client,
    //       );
    //     },
    //     initialProps: const StaleDuration(hours: 1),
    //   );

    //   // Wait for initial fetch to complete
    //   await tester.pumpAndSettle();

    //   // Initial fetch should succeed with 1 hour staleDuration
    //   expect(hookResult.current.data, 'data-1');
    //   expect(hookResult.current.isStale, false);

    //   // Unmount and remount immediately
    //   await hookResult.unmount();
    //   await hookResult.rebuild();

    //   // No refetch should occur since data is still fresh (< 1 hour old)
    //   expect(hookResult.current.fetchStatus, FetchStatus.idle);
    //   expect(hookResult.current.isStale, false);

    //   // Advance time by 5 minutes, then change staleDuration to 5 minutes
    //   await hookResult.unmount();
    //   await tester.binding.delayed(const Duration(minutes: 5));
    //   await hookResult.rebuildWithProps(const StaleDuration(minutes: 5));

    //   // Now data is stale (5 minutes old with 5 minute staleDuration)
    //   // Should trigger refetch on remount
    //   expect(hookResult.current.fetchStatus, FetchStatus.fetching);
    //   expect(hookResult.current.isStale, true);

    //   // Wait for refetch to complete
    //   await tester.pumpAndSettle();

    //   // Second fetch should succeed with fresh data
    //   expect(hookResult.current.data, 'data-2');
    //   expect(hookResult.current.isStale, false);
    // }));

    // TODO(staleDurationResolver): Re-enable when callback form is supported
    // testWidgets('SHOULD pass correct Query state to resolveWith callback',
    //     withCleanup((tester) async {
    //   late QueryState<String, Object> capturedState;

    //   await buildHook(
    //     () => useQuery<String, Object>(
    //       const ['key1'],
    //       (context) async => 'data',
    //       staleDurationResolver: (query) {
    //         // Capture the query state for inspection
    //         capturedState = query.state;
    //         return const StaleDuration();
    //       },
    //       queryClient: client,
    //     ),
    //   );

    //   await tester.pumpAndSettle();

    //   // Query should have success state with data
    //   expect(capturedState.status, QueryStatus.success);
    //   expect(capturedState.data, 'data');
    //   expect(capturedState.dataUpdatedAt, isA<DateTime>());
    //   expect(capturedState.error, null);
    //   expect(capturedState.errorUpdatedAt, null);
    //   expect(capturedState.errorUpdateCount, 0);

    //   await buildHook(
    //     () => useQuery<String, Object>(
    //       const ['key2'],
    //       (context) async => throw Exception(),
    //       staleDurationResolver: (query) {
    //         // Capture the query state for inspection
    //         capturedState = query.state;
    //         return const StaleDuration();
    //       },
    //       retry: (_, __) => null,
    //       queryClient: client,
    //     ),
    //   );

    //   await tester.pumpAndSettle();

    //   // Query should have error state with error
    //   expect(capturedState.status, QueryStatus.error);
    //   expect(capturedState.data, null);
    //   expect(capturedState.dataUpdatedAt, null);
    //   expect(capturedState.error, isA<Exception>());
    //   expect(capturedState.errorUpdatedAt, isA<DateTime>());
    //   expect(capturedState.errorUpdateCount, 1);
    // }));

    testWidgets('SHOULD default to zero WHEN staleDuration is not specified',
        withCleanup((tester) async {
      final hookResult = await buildHook(
        () => useQuery(
          const ['key'],
          (context) async => 'data',
          // staleDuration defaults to const StaleDuration()
          queryClient: client,
        ),
      );

      // Wait for initial fetch to complete
      await tester.pumpAndSettle();

      // Should be immediately stale with zero staleDuration
      expect(hookResult.current.isStale, true);
    }));
  });

  group('refetchOnMount', () {
    testWidgets('SHOULD refetch on mount WHEN set to stale AND data is stale',
        withCleanup((tester) async {
      final hookResult = await buildHook(
        () => useQuery(
          const ['key'],
          (context) async => 'data',
          refetchOnMount: RefetchOnMount.stale,
          staleDuration: const StaleDuration(),
          queryClient: client,
        ),
      );

      // Wait for initial fetch to complete
      await tester.pump();

      // Remount hook
      await hookResult.unmount();
      await hookResult.rebuild();

      // Should refetch when data is stale
      expect(hookResult.current.fetchStatus, FetchStatus.fetching);
      expect(hookResult.current.isStale, true);
    }));

    testWidgets(
        'SHOULD NOT refetch on mount WHEN set to stale AND data is fresh',
        withCleanup((tester) async {
      final hookResult = await buildHook(
        () => useQuery(
          const ['key'],
          (context) async => 'data',
          refetchOnMount: RefetchOnMount.stale,
          staleDuration: StaleDuration.infinity,
          queryClient: client,
        ),
      );

      // Wait for initial fetch to complete
      await tester.pump();

      // Remount hook
      await hookResult.unmount();
      await hookResult.rebuild();

      // Should NOT refetch when data is fresh
      expect(hookResult.current.fetchStatus, FetchStatus.idle);
      expect(hookResult.current.isStale, false);
    }));

    testWidgets(
        'SHOULD NOT refetch on mount WHEN set to never even if data is stale',
        withCleanup((tester) async {
      final hookResult = await buildHook(
        () => useQuery(
          const ['key'],
          (context) async => 'data',
          refetchOnMount: RefetchOnMount.never,
          staleDuration: const StaleDuration(),
          queryClient: client,
        ),
      );

      // Wait for initial fetch to complete
      await tester.pump();

      // Remount hook
      await hookResult.unmount();
      await hookResult.rebuild();

      // Should NOT be fetching even if data is stale
      expect(hookResult.current.fetchStatus, FetchStatus.idle);
      expect(hookResult.current.isStale, true);
    }));

    testWidgets(
        'SHOULD fetch on mount WHEN no data even if refetchOnMount is never',
        withCleanup((tester) async {
      final hookResult = await buildHook(
        () => useQuery(
          const ['key'],
          (context) async => 'data',
          refetchOnMount: RefetchOnMount.never,
          queryClient: client,
        ),
      );

      expect(hookResult.current.fetchStatus, FetchStatus.fetching);

      await tester.pumpAndSettle();

      expect(hookResult.current.data, 'data');
    }));

    testWidgets(
        'SHOULD refetch on mount WHEN set to always even if data is fresh',
        withCleanup((tester) async {
      final hookResult = await buildHook(
        () => useQuery(
          const ['key'],
          (context) async => 'data',
          refetchOnMount: RefetchOnMount.always,
          staleDuration: const StaleDuration(minutes: 5),
          queryClient: client,
        ),
      );

      // Wait for initial fetch to complete
      await tester.pump();

      // Remount hook
      await hookResult.unmount();
      await hookResult.rebuild();

      // Should be fetching even if data is fresh
      expect(hookResult.current.fetchStatus, FetchStatus.fetching);
      expect(hookResult.current.isStale, false);
    }));

    testWidgets(
        'SHOULD NOT refetch on mount WHEN set to always AND staleDuration is static',
        withCleanup((tester) async {
      final hookResult = await buildHook(
        () => useQuery(
          const ['key'],
          (context) async => 'data',
          refetchOnMount: RefetchOnMount.always,
          staleDuration: StaleDuration.static,
          queryClient: client,
        ),
      );

      // Wait for initial fetch to complete
      await tester.pump();

      // Remount hook
      await hookResult.unmount();
      await hookResult.rebuild();

      // Should NOT be fetching as staleDuration is set to static
      expect(hookResult.current.fetchStatus, FetchStatus.idle);
      expect(hookResult.current.isStale, false);
    }));
  });

  group('refetchOnResume == RefetchOnResume.stale', () {
    testWidgets('SHOULD refetch WHEN data is stale',
        withCleanup((tester) async {
      var fetchCount = 0;
      final hookResult = await buildHook(
        () => useQuery(
          const ['key'],
          (context) async {
            await Future.delayed(const Duration(seconds: 5));
            return 'data-${++fetchCount}';
          },
          refetchOnResume: RefetchOnResume.stale,
          staleDuration: const StaleDuration(),
          queryClient: client,
        ),
      );

      // Wait for initial fetch to complete
      await tester.pump(const Duration(seconds: 5));

      expect(hookResult.current.data, 'data-1');
      expect(hookResult.current.isStale, isTrue);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(hookResult.current.fetchStatus, FetchStatus.fetching);

      await tester.pump(const Duration(seconds: 5));

      expect(hookResult.current.fetchStatus, FetchStatus.idle);
      expect(hookResult.current.data, 'data-2');
    }));

    testWidgets('SHOULD NOT refetch WHEN data is fresh',
        withCleanup((tester) async {
      var fetchCount = 0;
      final hookResult = await buildHook(
        () => useQuery(
          const ['key'],
          (context) async {
            await Future.delayed(const Duration(seconds: 5));
            return 'data-${++fetchCount}';
          },
          refetchOnResume: RefetchOnResume.stale,
          staleDuration: StaleDuration.infinity,
          queryClient: client,
        ),
      );

      // Wait for initial fetch to complete
      await tester.pump(const Duration(seconds: 5));

      expect(hookResult.current.data, 'data-1');
      expect(hookResult.current.isStale, isFalse);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(hookResult.current.fetchStatus, FetchStatus.idle);

      await tester.pump(const Duration(seconds: 5));

      expect(hookResult.current.fetchStatus, FetchStatus.idle);
      expect(hookResult.current.data, 'data-1');
    }));

    testWidgets('SHOULD refetch WHEN data is stale (with synchronous queryFn)',
        withCleanup((tester) async {
      var fetchCount = 0;
      final hookResult = await buildHook(
        () => useQuery(
          const ['key'],
          (context) async => 'data-${++fetchCount}',
          refetchOnResume: RefetchOnResume.stale,
          staleDuration: const StaleDuration(),
          queryClient: client,
        ),
      );

      // Wait for initial fetch to complete
      await tester.pump();

      expect(hookResult.current.data, 'data-1');
      expect(hookResult.current.isStale, isTrue);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      // With synchronous queryFn (no actual async operations), the fetch completes
      // immediately in the same synchronous execution, so we only observe the final state
      expect(hookResult.current.fetchStatus, FetchStatus.idle);
      expect(hookResult.current.data, 'data-2');
    }));

    testWidgets(
        'SHOULD NOT refetch WHEN data is fresh (with synchronous queryFn)',
        withCleanup((tester) async {
      var fetchCount = 0;
      final hookResult = await buildHook(
        () => useQuery(
          const ['key'],
          (context) async => 'data-${++fetchCount}',
          refetchOnResume: RefetchOnResume.stale,
          staleDuration: StaleDuration.infinity,
          queryClient: client,
        ),
      );

      // Wait for initial fetch to complete
      await tester.pump();

      expect(hookResult.current.data, 'data-1');
      expect(hookResult.current.isStale, isFalse);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      // With synchronous queryFn (no actual async operations), the fetch completes
      // immediately in the same synchronous execution, so we only observe the final state
      expect(hookResult.current.fetchStatus, FetchStatus.idle);
      expect(hookResult.current.data, 'data-1');
    }));
  });

  group('refetchOnResume == RefetchOnResume.never', () {
    testWidgets('SHOULD NOT refetch on resumed WHEN data is stale',
        withCleanup((tester) async {
      var fetchCount = 0;
      final hookResult = await buildHook(
        () => useQuery(
          const ['key'],
          (context) async {
            await Future.delayed(const Duration(seconds: 5));
            return 'data-${++fetchCount}';
          },
          refetchOnResume: RefetchOnResume.never,
          staleDuration: const StaleDuration(),
          queryClient: client,
        ),
      );

      // Wait for initial fetch to complete
      await tester.pump(const Duration(seconds: 5));

      expect(hookResult.current.data, 'data-1');
      expect(hookResult.current.isStale, isTrue);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(hookResult.current.fetchStatus, FetchStatus.idle);
      expect(hookResult.current.data, 'data-1');

      await tester.pump(const Duration(seconds: 5));

      expect(hookResult.current.fetchStatus, FetchStatus.idle);
      expect(hookResult.current.data, 'data-1');
    }));

    testWidgets(
        'SHOULD NOT fetch on resumed WHEN query is in error state with no data',
        withCleanup((tester) async {
      var fetchCount = 0;
      final hookResult = await buildHook(
        () => useQuery(
          const ['key'],
          (context) async {
            fetchCount++;
            await Future.delayed(const Duration(seconds: 5));
            if (fetchCount == 1) {
              throw Exception();
            }
            return 'data-$fetchCount';
          },
          refetchOnResume: RefetchOnResume.never,
          retry: (_, __) => null,
          queryClient: client,
        ),
      );

      // Wait for fetch to fail
      await tester.pump(const Duration(seconds: 5));

      // Should be in error state with no data
      expect(hookResult.current.status, QueryStatus.error);
      expect(hookResult.current.fetchStatus, FetchStatus.idle);
      expect(hookResult.current.data, isNull);
      expect(fetchCount, 1);

      // Trigger resume
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      // Should NOT trigger a new fetch since refetchOnResume is never
      expect(hookResult.current.fetchStatus, FetchStatus.idle);
      expect(fetchCount, 1);

      await tester.pump(const Duration(seconds: 5));

      // Still should not have refetched
      expect(hookResult.current.fetchStatus, FetchStatus.idle);
      expect(fetchCount, 1);
    }));
  });

  group('refetchOnResume == RefetchOnResume.always', () {
    testWidgets('SHOULD refetch on mount WHEN data is fresh',
        withCleanup((tester) async {
      var fetchCount = 0;
      final hookResult = await buildHook(
        () => useQuery(
          const ['key'],
          (context) async {
            fetchCount++;
            await Future.delayed(const Duration(seconds: 5));
            return 'data-$fetchCount';
          },
          refetchOnResume: RefetchOnResume.always,
          staleDuration: StaleDuration.infinity,
          queryClient: client,
        ),
      );

      // Wait for initial fetch to complete
      await tester.pump(const Duration(seconds: 5));

      expect(hookResult.current.data, 'data-1');
      expect(hookResult.current.isStale, isFalse);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(hookResult.current.fetchStatus, FetchStatus.fetching);

      await tester.pump(const Duration(seconds: 5));

      expect(hookResult.current.fetchStatus, FetchStatus.idle);
      expect(hookResult.current.data, 'data-2');
    }));
    testWidgets('SHOULD NOT refetch on mount WHEN staleDuration is static',
        withCleanup((tester) async {
      var fetchCount = 0;
      final hookResult = await buildHook(
        () => useQuery(
          const ['key'],
          (context) async {
            fetchCount++;
            await Future.delayed(const Duration(seconds: 5));
            return 'data-$fetchCount';
          },
          refetchOnResume: RefetchOnResume.always,
          staleDuration: StaleDuration.static,
          queryClient: client,
        ),
      );

      // Wait for initial fetch to complete
      await tester.pump(const Duration(seconds: 5));

      expect(hookResult.current.data, 'data-1');
      expect(hookResult.current.isStale, isFalse);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(hookResult.current.fetchStatus, FetchStatus.idle);
      expect(hookResult.current.data, 'data-1');

      await tester.pump(const Duration(seconds: 5));

      expect(hookResult.current.fetchStatus, FetchStatus.idle);
      expect(hookResult.current.data, 'data-1');
    }));
  });

  group('gcDuration', () {
    testWidgets('SHOULD remove cache WHEN time passes gcDuration',
        (tester) async {
      final hookResult = await buildHook(
        () => useQuery(
          const ['key'],
          (context) async => 'data',
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
          const ['key'],
          (context) async => 'data',
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
                const ['key'],
                (context) async => 'data-1',
                gcDuration: const GcDuration(minutes: 5),
                queryClient: client,
              );
              return Container();
            },
          ),
          HookBuilder(
            builder: (context) {
              useQuery(
                const ['key'],
                (context) async => 'data-2',
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
                const ['key'],
                (context) async => 'data-2',
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
          const ['key'],
          (context) async => 'data',
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
          const ['key'],
          (context) async => 'data',
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
          const ['key'],
          (context) async => 'data',
        ),
        wrapper: (child) => QueryClientProvider.value(
          client,
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
          const ['key'],
          (context) async => 'data',
          queryClient: prioritizedQueryClient,
        ),
        wrapper: (child) => QueryClientProvider.value(
          client,
          child: child,
        ),
      );

      await tester.pumpAndSettle();

      expect(prioritizedQueryClient.cache.get(const ['key']), isNotNull);
      expect(client.cache.get(const ['key']), isNull);

      await hookResult.unmount();
      prioritizedQueryClient.clear();
    }));

    testWidgets('SHOULD throw WHEN QueryClient is not provided',
        (tester) async {
      await tester.pumpWidget(HookBuilder(
        builder: (context) {
          useQuery<String, Object>(
            const ['test'],
            (context) async => 'data',
          );
          return Container();
        },
      ));

      // Check that a FlutterError was thrown during build
      final exception = tester.takeException();
      expect(exception, isA<FlutterError>());
    });
  });

  group('seed', () {
    testWidgets('SHOULD start with success status WHEN seed is provided',
        withCleanup((tester) async {
      final hookResult = await buildHook(
        () => useQuery(
          const ['key'],
          (context) async => 'data',
          seed: 'initial-data',
          queryClient: client,
        ),
      );

      final result = hookResult.current;
      expect(result.status, QueryStatus.success);
      expect(result.data, 'initial-data');
    }));

    testWidgets('SHOULD refetch WHEN seed is stale',
        withCleanup((tester) async {
      final hookResult = await buildHook(
        () => useQuery(
          const ['key'],
          (context) async => 'data',
          seed: 'initial-data',
          staleDuration: const StaleDuration(),
          queryClient: client,
        ),
      );

      // Should have initial data
      expect(hookResult.current.data, 'initial-data');
      // Should be fetching because data is stale
      expect(hookResult.current.fetchStatus, FetchStatus.fetching);
      expect(hookResult.current.isStale, true);

      await tester.pumpAndSettle();

      // Should now have fetched data
      expect(hookResult.current.data, 'data');
    }));

    testWidgets('SHOULD NOT refetch WHEN seed is fresh',
        withCleanup((tester) async {
      final hookResult = await buildHook(
        () => useQuery(
          const ['key'],
          (context) async => 'data',
          seed: 'initial-data',
          staleDuration: const StaleDuration(minutes: 5),
          queryClient: client,
        ),
      );

      // Should NOT be fetching because data is fresh
      expect(hookResult.current.fetchStatus, FetchStatus.idle);
      expect(hookResult.current.isStale, false);

      await tester.pumpAndSettle();

      // Should still have initial data (no fetch occurred)
      expect(hookResult.current.fetchStatus, FetchStatus.idle);
      expect(hookResult.current.data, 'initial-data');
      expect(hookResult.current.isStale, false);
    }));

    testWidgets(
        'SHOULD update initialData WHEN Query exists without data and observer is created with seed',
        withCleanup((tester) async {
      // First, create a query without data by starting a slow fetch
      final hookResult1 = await buildHook(
        () => useQuery(
          const ['key'],
          (context) async {
            await Future.delayed(const Duration(minutes: 1));
            return 'data-1';
          },
          queryClient: client,
        ),
      );

      // Query should be pending with no data
      expect(hookResult1.current.status, QueryStatus.pending);
      expect(hookResult1.current.fetchStatus, FetchStatus.fetching);
      expect(hookResult1.current.data, null);

      // Unmount the first hook
      await hookResult1.unmount();

      // Now create a new observer with seed
      final hookResult2 = await buildHook(
        () => useQuery(
          const ['key'],
          (context) async => 'data-2',
          seed: 'initial-data',
          queryClient: client,
        ),
      );

      // Should now have initialData
      expect(hookResult2.current.status, QueryStatus.success);
      expect(hookResult2.current.data, 'initial-data');

      // Wait for pending timer created by Future.delayed
      await tester.binding.delayed(const Duration(minutes: 1));
    }));
  });

  group('seedUpdatedAt', () {
    testWidgets('SHOULD use current time WHEN seedUpdatedAt is not set',
        withCleanup((tester) async {
      final hookResult = await buildHook(
        () => useQuery(
          const ['key'],
          (context) async => 'data',
          seed: 'initial-data',
          queryClient: client,
        ),
      );

      expect(hookResult.current.dataUpdatedAt, clock.now());
    }));

    testWidgets('SHOULD use provided time WHEN seedUpdatedAt is set',
        withCleanup((tester) async {
      final specificTime = DateTime(2025, 1, 1, 12, 0, 0);

      final hookResult = await buildHook(
        () => useQuery(
          const ['key'],
          (context) async => 'data',
          seed: 'initial-data',
          seedUpdatedAt: specificTime,
          queryClient: client,
        ),
      );

      expect(hookResult.current.dataUpdatedAt, specificTime);
    }));

    testWidgets(
        'SHOULD determine staleness based on seedUpdatedAt and staleDuration',
        withCleanup((tester) async {
      var hookResult = await buildHook(
        () => useQuery(
          const ['key', 1],
          (context) async => 'data',
          seed: 'initial-data',
          seedUpdatedAt: clock.minutesAgo(10),
          staleDuration: const StaleDuration(minutes: 5),
          queryClient: client,
        ),
      );

      // Data is 10 minutes old with 5 minute staleDuration, so it's stale
      expect(hookResult.current.fetchStatus, FetchStatus.fetching);
      expect(hookResult.current.isStale, true);

      hookResult = await buildHook(
        () => useQuery(
          const ['key', 2],
          (context) async => 'data',
          seed: 'initial-data',
          seedUpdatedAt: clock.minutesAgo(10),
          staleDuration: const StaleDuration(minutes: 15),
          queryClient: client,
        ),
      );

      // Data is 10 minutes old with 15 minute staleDuration, so it's fresh
      expect(hookResult.current.fetchStatus, FetchStatus.idle);
      expect(hookResult.current.isStale, false);
    }));

    testWidgets('SHOULD refetch on mount WHEN seed becomes stale over time',
        withCleanup((tester) async {
      final hookResult = await buildHook(
        () => useQuery(
          const ['key'],
          (context) async => 'data',
          seed: 'initial-data',
          seedUpdatedAt: clock.minutesAgo(5),
          staleDuration: const StaleDuration(minutes: 10),
          gcDuration: GcDuration.infinity,
          queryClient: client,
        ),
      );

      // Initially has initial data
      expect(hookResult.current.fetchStatus, FetchStatus.idle);
      expect(hookResult.current.data, 'initial-data');

      // Unmount
      await hookResult.unmount();

      // Advance time by 10 minutes
      await tester.binding.delayed(const Duration(minutes: 10));

      // Remount - data is now 15 minutes old
      await hookResult.rebuild();

      // Should be fetching
      expect(hookResult.current.fetchStatus, FetchStatus.fetching);

      await tester.pumpAndSettle();

      // Should have new data
      expect(hookResult.current.data, 'data');
    }));
  });

  group('placeholder', () {
    testWidgets('SHOULD show placeholder data', withCleanup((tester) async {
      final hookResult = await buildHook(
        () => useQuery(
          const ['key'],
          (context) async => 'data',
          placeholder: 'placeholder',
          queryClient: client,
        ),
      );

      var result = hookResult.current;
      expect(result.status, QueryStatus.success);
      expect(result.fetchStatus, FetchStatus.fetching);
      expect(result.data, 'placeholder');
      expect(result.isPlaceholderData, true);
    }));

    testWidgets('SHOULD replace placeholder data once fetch completes',
        withCleanup((tester) async {
      final hookResult = await buildHook(
        () => useQuery(
          const ['key'],
          (context) async => 'data',
          placeholder: 'placeholder',
          queryClient: client,
        ),
      );

      var result = hookResult.current;
      expect(result.data, 'placeholder');
      expect(result.isPlaceholderData, true);

      await tester.pump();

      result = hookResult.current;
      expect(result.data, 'data');
      expect(result.isPlaceholderData, false);
    }));

    testWidgets('SHOULD show placeholder data WHEN enabled is false',
        withCleanup((tester) async {
      final hookResult = await buildHook(
        () => useQuery(
          const ['key'],
          (context) async => 'data',
          placeholder: 'placeholder',
          enabled: false,
          queryClient: client,
        ),
      );

      var result = hookResult.current;
      expect(result.status, QueryStatus.success);
      expect(result.fetchStatus, FetchStatus.idle);
      expect(result.data, 'placeholder');
      expect(result.isEnabled, false);
      expect(result.isPlaceholderData, true);
    }));

    testWidgets('SHOULD NOT show placeholder WHEN query already has data',
        withCleanup((tester) async {
      final query = client.cache.build(QueryOptions<String, Object>(
        const ['key'],
        (context) async => 'data-cached',
      ));
      await query.fetch();

      final hookResult = await buildHook(
        () => useQuery<String, Object>(
          const ['key'],
          (context) async => 'data',
          placeholder: 'placeholder',
          staleDuration: StaleDuration.infinity,
          queryClient: client,
        ),
      );

      final result = hookResult.current;
      expect(result.data, 'data-cached');
      expect(result.isPlaceholderData, false);
    }));

    testWidgets('SHOULD NOT show placeholder data WHEN seed is provided',
        withCleanup((tester) async {
      final hookResult = await buildHook(
        () => useQuery(
          const ['key'],
          (context) async => 'data',
          seed: 'initial',
          placeholder: 'placeholder',
          queryClient: client,
        ),
      );

      var result = hookResult.current;
      expect(result.status, QueryStatus.success);
      expect(result.fetchStatus, FetchStatus.fetching);
      expect(result.data, 'initial');
      expect(result.isPlaceholderData, false);
    }));

    testWidgets('SHOULD NOT persist placeholder data to cache',
        withCleanup((tester) async {
      final hookResult = await buildHook(
        () => useQuery(
          const ['key'],
          (context) async => 'data',
          placeholder: 'placeholder',
          queryClient: client,
        ),
      );

      var result = hookResult.current;
      expect(result.data, 'placeholder');
      expect(result.isPlaceholderData, true);

      final query = client.cache.get(const ['key'])!;
      expect(query.state.data, isNot('placeholder'));
    }));

    testWidgets(
        'SHOULD replace with new placeholder data WHEN fetch has not completed',
        withCleanup((tester) async {
      final hookResult = await buildHookWithProps(
        (placeholder) => useQuery(
          const ['key'],
          (context) async {
            await Future.delayed(const Duration(seconds: 5));
            return 'data';
          },
          placeholder: placeholder,
          queryClient: client,
        ),
        initialProps: 'placeholder-1',
      );

      var result = hookResult.current;
      expect(result.data, 'placeholder-1');
      expect(result.isPlaceholderData, true);

      await hookResult.rebuildWithProps('placeholder-2');

      result = hookResult.current;
      expect(result.data, 'placeholder-2');
      expect(result.isPlaceholderData, true);
    }));

    // TODO(placeholderData): Re-enable when callback form is supported
    // testWidgets('SHOULD show old data as placeholder WHEN query key changes',
    //     withCleanup((tester) async {
    //   final hookResult = await buildHookWithProps(
    //     (key) => useQuery(
    //       key,
    //       (context) async => 'data-1',
    //       placeholder: PlaceholderData.resolveWith(
    //         (previousValue, _) => previousValue,
    //       ),
    //       queryClient: client,
    //     ),
    //     initialProps: const ['todos', 1],
    //   );

    //   await tester.pumpAndSettle();

    //   expect(hookResult.current.data, 'data-1');
    //   expect(hookResult.current.isPlaceholderData, false);

    //   await hookResult.rebuildWithProps(const ['todos', 2]);

    //   expect(hookResult.current.data, 'data-1');
    //   expect(hookResult.current.isPlaceholderData, true);
    // }));

    // TODO(placeholderData): Re-enable when callback form is supported
    // testWidgets(
    //     'SHOULD pass previousValue and previousQuery to PlaceholderData.resolveWith',
    //     withCleanup((tester) async {
    //   dynamic capturedValue;
    //   dynamic capturedQuery;

    //   final hookResult = await buildHookWithProps(
    //     (key) => useQuery<String, Object>(
    //       key,
    //       (context) async {
    //         await Future.delayed(const Duration(seconds: 5));
    //         return 'data';
    //       },
    //       placeholder: PlaceholderData.resolveWith(
    //         (previousValue, previousQuery) {
    //           capturedValue = previousValue;
    //           capturedQuery = previousQuery;
    //           return 'placeholder';
    //         },
    //       ),
    //       queryClient: client,
    //     ),
    //     initialProps: const ['key-1'],
    //   );

    //   var result = hookResult.current;
    //   expect(result.data, 'placeholder');
    //   expect(result.isPlaceholderData, isTrue);
    //   expect(capturedValue, isNull);
    //   expect(capturedQuery, isNull);

    //   await tester.pump(const Duration(seconds: 5));

    //   result = hookResult.current;
    //   expect(result.data, 'data');
    //   expect(result.isPlaceholderData, isFalse);
    //   expect(capturedValue, isNull);
    //   expect(capturedQuery, isNull);

    //   await hookResult.rebuildWithProps(const ['key-2']);

    //   result = hookResult.current;
    //   expect(result.data, 'placeholder');
    //   expect(result.isPlaceholderData, isTrue);
    //   expect(capturedValue, 'data');
    //   expect(capturedQuery, isNotNull);
    // }));
  });

  group('refetchInterval', () {
    testWidgets('SHOULD refetch at interval', withCleanup((tester) async {
      final start = clock.now();
      var fetchAttempts = 0;

      final hookResult = await buildHook(
        () => useQuery(
          const ['key'],
          (context) async {
            fetchAttempts++;
            await Future.delayed(const Duration(seconds: 3));
            return 'data-$fetchAttempts';
          },
          refetchInterval: const Duration(seconds: 10),
          queryClient: client,
        ),
      );
      expect(hookResult.current.isLoading, isTrue);

      await tester.pump(const Duration(seconds: 3));
      expect(hookResult.current.isFetched, isTrue);
      expect(fetchAttempts, 1);

      for (var i = 2; i < 20; i++) {
        await tester.pumpUntil(start.add(Duration(seconds: 10 * (i - 1))));
        expect(hookResult.current.isRefetching, isTrue);
        expect(fetchAttempts, i);

        await tester.pump(const Duration(seconds: 3));
        expect(hookResult.current.data, 'data-$i');
        expect(
          hookResult.current.dataUpdatedAt,
          start.add(Duration(seconds: 10 * (i - 1) + 3)),
        );
      }
    }));

    testWidgets('SHOULD reschedule refetch WHEN interval duration changes',
        withCleanup((tester) async {
      final start = clock.now();
      var fetchAttempts = 0;

      final hookResult = await buildHookWithProps(
        (interval) => useQuery(
          const ['key'],
          (context) async {
            fetchAttempts++;
            await Future.delayed(const Duration(seconds: 3));
            return 'data-$fetchAttempts';
          },
          refetchInterval: interval,
          queryClient: client,
        ),
        initialProps: const Duration(seconds: 10),
      );
      expect(hookResult.current.isLoading, isTrue);
      expect(fetchAttempts, 1);

      await tester.pump(const Duration(seconds: 3));
      expect(hookResult.current.data, 'data-1');
      expect(
        hookResult.current.dataUpdatedAt,
        start.add(const Duration(seconds: 3)),
      );

      // 10 seconds passed since start - should trigger refetch at old interval
      await tester.pumpUntil(start.add(const Duration(seconds: 10)));
      expect(hookResult.current.isRefetching, isTrue);
      expect(fetchAttempts, 2);

      // Change interval to 5 seconds
      await hookResult.rebuildWithProps(const Duration(seconds: 5));

      // Wait 5 seconds - should trigger refetch at new interval
      await tester.pump(const Duration(seconds: 5));
      expect(hookResult.current.isRefetching, isTrue);
      expect(fetchAttempts, 3);

      // Wait another 5 seconds - should trigger refetch at new interval
      await tester.pump(const Duration(seconds: 5));
      expect(hookResult.current.isRefetching, isTrue);
      expect(fetchAttempts, 4);
    }));

    testWidgets('SHOULD NOT refetch at interval WHEN enabled is false',
        withCleanup((tester) async {
      var fetchAttempts = 0;

      final hookResult = await buildHook(
        () => useQuery(
          const ['key'],
          (context) async {
            fetchAttempts++;
            await Future.delayed(const Duration(seconds: 3));
            return 'data-$fetchAttempts';
          },
          enabled: false,
          refetchInterval: const Duration(seconds: 10),
          queryClient: client,
        ),
      );

      // Wait 10 seconds - should NOT trigger refetch because disabled
      await tester.pump(const Duration(seconds: 10));
      expect(hookResult.current.isFetched, isFalse);
      expect(hookResult.current.isRefetching, isFalse);
      expect(fetchAttempts, 0);
    }));

    testWidgets('SHOULD NOT refetch at interval WHEN enabled changes to false',
        withCleanup((tester) async {
      final start = clock.now();
      var fetchAttempts = 0;

      final hookResult = await buildHookWithProps(
        (enabled) => useQuery(
          const ['key'],
          (context) async {
            fetchAttempts++;
            await Future.delayed(const Duration(seconds: 3));
            return 'data-$fetchAttempts';
          },
          enabled: enabled,
          refetchInterval: const Duration(seconds: 10),
          queryClient: client,
        ),
        initialProps: true,
      );
      expect(hookResult.current.isLoading, isTrue);

      await tester.pump(const Duration(seconds: 3));
      expect(hookResult.current.isFetched, isTrue);
      expect(fetchAttempts, 1);

      // 10 seconds passed since start - should trigger interval refetch
      await tester.pumpUntil(start.add(const Duration(seconds: 10)));
      expect(hookResult.current.isRefetching, isTrue);
      expect(fetchAttempts, 2);

      // Disable the query
      await hookResult.rebuildWithProps(false);

      // 20 seconds passed since start - should NOT trigger refetch anymore
      await tester.pumpUntil(start.add(const Duration(seconds: 10 * 2)));
      expect(hookResult.current.isRefetching, isFalse);
      expect(fetchAttempts, 2);

      // 30 seconds passed since start - still should NOT trigger refetch
      await tester.pumpUntil(start.add(const Duration(seconds: 10 * 3)));
      expect(hookResult.current.isRefetching, isFalse);
      expect(fetchAttempts, 2);
    }));

    testWidgets('SHOULD refetch at interval WHEN data is fresh',
        withCleanup((tester) async {
      late HookResult<QueryResult> hookResult;
      for (final staleDuration in [
        StaleDuration(hours: 1),
        StaleDuration.infinity,
        StaleDuration.static,
      ]) {
        final start = clock.now();
        var fetchAttempts = 0;

        hookResult = await buildHook(
          () => useQuery(
            [staleDuration],
            (context) async {
              fetchAttempts++;
              await Future.delayed(const Duration(seconds: 3));
              return 'data-$fetchAttempts';
            },
            refetchInterval: const Duration(seconds: 10),
            staleDuration: staleDuration,
            queryClient: client,
          ),
        );
        expect(hookResult.current.isLoading, isTrue);

        await tester.pump(const Duration(seconds: 3));
        expect(hookResult.current.isFetched, isTrue);
        expect(fetchAttempts, 1);

        // 10 seconds passed since start - should trigger interval refetch
        await tester.pumpUntil(start.add(const Duration(seconds: 10)));
        expect(hookResult.current.isRefetching, isTrue);
        expect(fetchAttempts, 2);
      }
    }));
  });

  group('retry', () {
    testWidgets('SHOULD retry for N times WHEN retry returns duration N times',
        withCleanup((tester) async {
      for (final N in [0, 1, 2, 4, 8, 16, 32, 64, 128]) {
        final hook = await buildHook(
          () => useQuery(
            ['key', N],
            (context) async {
              await Future.delayed(Duration.zero);
              throw Exception();
            },
            retry: (retryCount, error) {
              if (retryCount >= N) return null;
              return const Duration(seconds: 1);
            },
            queryClient: client,
          ),
        );

        // Initial attempt
        await tester.pump(Duration.zero);
        expect(hook.current.failureCount, 1);

        // Retry for N times with fixed 1s delay
        for (var i = 0; i < N; i++) {
          final retryNth = i + 1;
          await tester.pump(const Duration(seconds: 1));
          expect(hook.current.failureCount, 1 + retryNth);
        }
      }
    }));

    testWidgets('SHOULD NOT retry WHEN retry returns null',
        withCleanup((tester) async {
      final hook = await buildHook(
        () => useQuery(
          const ['key'],
          (context) async {
            await Future.delayed(Duration.zero);
            throw Exception();
          },
          retry: (_, __) => null,
          queryClient: client,
        ),
      );

      // Initial attempt
      await tester.pump(Duration.zero);
      expect(hook.current.failureCount, 1);

      // Wait long enough
      await tester.pump(const Duration(hours: 24));
      // Should NOT have retried
      expect(hook.current.failureCount, 1);
    }));

    testWidgets('SHOULD retry with custom logic WHEN retry callback provided',
        withCleanup((tester) async {
      var attempts = 0;

      final hook = await buildHook(
        () => useQuery<Never, String>(
          const ['key'],
          (context) async {
            attempts++;
            await Future.delayed(Duration.zero);
            throw 'error-$attempts';
          },
          retry: (retryCount, error) {
            // Only retry if error message contains specific text
            // AND retry count is less than 2
            if (error.contains('error-$attempts') && retryCount < 2) {
              return const Duration(seconds: 1);
            }
            return null;
          },
          queryClient: client,
        ),
      );

      // Initial attempt
      await tester.pump(Duration.zero);
      expect(hook.current.failureCount, 1);

      // Retry for 2 times
      await tester.pump(const Duration(seconds: 1));
      expect(hook.current.failureCount, 2);
      await tester.pump(const Duration(seconds: 1));
      expect(hook.current.failureCount, 3);

      // Should stop retrying on 3rd attempt
      await tester.pump(const Duration(seconds: 1));
      expect(hook.current.failureCount, 3);
    }));

    testWidgets(
        'SHOULD increment failureCount on each retry and reset to 0 on every fetch attempt',
        withCleanup((tester) async {
      final hook = await buildHook(
        () => useQuery<Never, Exception>(
          ['key'],
          (context) async {
            await Future.delayed(Duration.zero);
            throw Exception();
          },
          retry: (retryCount, error) {
            if (retryCount >= 5) return null;
            return const Duration(seconds: 1);
          },
          retryOnMount: true,
          queryClient: client,
        ),
      );

      // Initial attempt
      await tester.pump(Duration.zero);
      expect(hook.current.failureCount, 1);
      expect(hook.current.failureReason, isA<Exception>());

      // Should retry for 5 times with fixed 1s delay
      for (var i = 0; i < 5; i++) {
        final retryNth = i + 1;
        await tester.pump(const Duration(seconds: 1));
        // Should increment failureCount on EACH retry
        expect(hook.current.failureCount, 1 + retryNth);
        expect(hook.current.failureReason, isA<Exception>());
      }

      // Remount hook
      await hook.unmount();
      await hook.rebuild();

      // Should reset to 0
      expect(hook.current.failureCount, 0);
      expect(hook.current.failureReason, null);

      // First attempt since remount
      await tester.pump(Duration.zero);

      // Should have failed
      expect(hook.current.failureCount, 1);
      expect(hook.current.failureReason, isA<Exception>());
    }));

    testWidgets('SHOULD succeed after failed retries',
        withCleanup((tester) async {
      var attempts = 0;

      final hook = await buildHook(
        () => useQuery(
          const ['key'],
          (context) async {
            attempts++;
            await Future.delayed(Duration.zero);
            if (attempts < 3) {
              throw Exception();
            }
            return 'data';
          },
          retry: (retryCount, error) {
            if (retryCount >= 3) return null;
            return const Duration(seconds: 1);
          },
          queryClient: client,
        ),
      );

      // Initial attempts
      await tester.pump(Duration.zero);
      expect(hook.current.failureCount, 1);

      // First retry fails
      await tester.pump(const Duration(seconds: 1));
      expect(hook.current.failureCount, 2);
      expect(hook.current.failureReason, isA<Exception>());

      // Second retry succeeds
      await tester.pump(const Duration(seconds: 1));
      expect(hook.current.status, QueryStatus.success);
      expect(hook.current.data, 'data');
      // Should reset failureCount and failureReason on success
      expect(hook.current.failureCount, 0);
      expect(hook.current.failureReason, null);
    }));
  });

  group('retryOnMount', () {
    testWidgets(
        'SHOULD retry on mount WHEN retryOnMount is true AND query has error',
        withCleanup((tester) async {
      final hook = await buildHookWithProps(
        (maxRetries) => useQuery(
          ['key'],
          (context) async {
            await Future.delayed(Duration.zero);
            throw Exception();
          },
          retry: (retryCount, error) {
            if (retryCount >= maxRetries) return null;
            return const Duration(seconds: 1);
          },
          retryOnMount: true,
          queryClient: client,
        ),
        // Don't retry on initial attempt
        initialProps: 0,
      );

      // Initial attempt
      await tester.pump(Duration.zero);
      expect(hook.current.status, QueryStatus.error);
      expect(hook.current.failureCount, 1);

      // Remount hook and set maxRetries to 3
      await hook.unmount();
      await hook.rebuildWithProps(3);

      // First attempt since remount (not retry)
      await tester.pump(Duration.zero);
      expect(hook.current.status, QueryStatus.error);
      expect(hook.current.failureCount, 1);

      // Retry 3 times with fixed 1s delay
      await tester.pump(const Duration(seconds: 3));
      expect(hook.current.failureCount, 4);
    }));

    testWidgets(
        'SHOULD NOT retry on mount WHEN retryOnMount is false AND query has error',
        withCleanup((tester) async {
      final hook = await buildHook(
        () => useQuery(
          const ['key'],
          (context) async {
            await Future.delayed(Duration.zero);
            throw Exception();
          },
          retry: (retryCount, error) {
            if (retryCount >= 1) return null;
            return const Duration(seconds: 1);
          },
          retryOnMount: false,
          queryClient: client,
        ),
      );

      // Initial attempt
      await tester.pump(Duration.zero);
      expect(hook.current.status, QueryStatus.pending);
      expect(hook.current.failureCount, 1);

      // Retry 1 time with fixed 1s delay
      await tester.pump(const Duration(seconds: 1));
      expect(hook.current.status, QueryStatus.error);
      expect(hook.current.failureCount, 2);

      // Remount hook
      await hook.unmount();
      await hook.rebuild();

      // First attempt since remount
      await tester.pump(Duration.zero);
      // Should keep previous result
      expect(hook.current.status, QueryStatus.error);
      expect(hook.current.failureCount, 2);

      // Wait 1s retry delay
      await tester.pump(const Duration(seconds: 1));
      // Should NOT have retried
      expect(hook.current.status, QueryStatus.error);
      expect(hook.current.failureCount, 2);
    }));

    testWidgets('SHOULD respect retry count WHEN retryOnMount triggers retry',
        withCleanup((tester) async {
      var attempts = 0;

      final hook = await buildHook(
        () => useQuery(
          const ['key'],
          (context) async {
            attempts++;
            await Future.delayed(Duration.zero);
            throw Exception();
          },
          retry: (retryCount, error) {
            if (retryCount >= 2) return null;
            return const Duration(seconds: 1);
          },
          retryOnMount: true,
          queryClient: client,
        ),
      );

      // Initial attempt
      await tester.pump(Duration.zero);
      expect(hook.current.failureCount, 1);

      // Retry 2 times with fixed 1s delay
      await tester.pump(const Duration(seconds: 1));
      expect(hook.current.failureCount, 2);
      await tester.pump(const Duration(seconds: 1));
      expect(hook.current.failureCount, 3);

      // Remount hook - this should trigger another fetch with retries
      await hook.unmount();
      await hook.rebuild();

      // First attempt since remount
      await tester.pump(Duration.zero);
      expect(hook.current.failureCount, 1);

      // Retry 2 times with fixed 1s delay
      await tester.pump(const Duration(seconds: 1));
      expect(hook.current.failureCount, 2);
      await tester.pump(const Duration(seconds: 1));
      expect(hook.current.failureCount, 3);

      // 3 from first mount + 3 from remount
      expect(attempts, 6);
    }));
  });

  group('retry delay patterns', () {
    testWidgets('SHOULD retry with exponential backoff',
        withCleanup((tester) async {
      final hook = await buildHook(
        () => useQuery(
          const ['key'],
          (context) async {
            await Future.delayed(Duration.zero);
            throw Exception();
          },
          retry: (retryCount, error) {
            if (retryCount >= 8) return null;
            // Exponential backoff: 1s, 2s, 4s, 8s, 16s, capped at 30s
            final delaySeconds = 1 << retryCount;
            return Duration(seconds: delaySeconds > 30 ? 30 : delaySeconds);
          },
          queryClient: client,
        ),
      );

      // Wait for initial attempt
      await tester.pump(Duration.zero);
      expect(hook.current.failureCount, 1);
      // Should start retrying
      await tester.pump(const Duration(seconds: 1));
      expect(hook.current.failureCount, 2);
      await tester.pump(const Duration(seconds: 2));
      expect(hook.current.failureCount, 3);
      await tester.pump(const Duration(seconds: 4));
      expect(hook.current.failureCount, 4);
      await tester.pump(const Duration(seconds: 8));
      expect(hook.current.failureCount, 5);
      await tester.pump(const Duration(seconds: 16));
      expect(hook.current.failureCount, 6);
      await tester.pump(const Duration(seconds: 30));
      expect(hook.current.failureCount, 7);
      // Should be capped at 30 seconds
      await tester.pump(const Duration(seconds: 30));
      expect(hook.current.failureCount, 8);
      await tester.pump(const Duration(seconds: 30));
      expect(hook.current.failureCount, 9);
    }));

    testWidgets('SHOULD retry with fixed delay', withCleanup((tester) async {
      final hook = await buildHook(
        () => useQuery(
          const ['key'],
          (context) async {
            await Future.delayed(Duration.zero);
            throw Exception();
          },
          retry: (retryCount, error) {
            if (retryCount >= 8) return null;
            return const Duration(seconds: 1);
          },
          queryClient: client,
        ),
      );

      // Wait for initial attempt
      await tester.pump(Duration.zero);
      expect(hook.current.failureCount, 1);

      // Should retry for 8 times with fixed delay 1 second
      for (var i = 0; i < 8; i++) {
        final retryNth = i + 1;
        await tester.pump(const Duration(seconds: 1));
        expect(hook.current.failureCount, 1 + retryNth);
      }
    }));

    testWidgets('SHOULD retry with custom delay logic',
        withCleanup((tester) async {
      final delays = <int>[];

      final hook = await buildHook(
        () => useQuery(
          const ['key'],
          (context) async {
            await Future.delayed(Duration.zero);
            throw Exception();
          },
          retry: (retryCount, error) {
            // Linear delay: 1s * (retryCount + 1)
            final delay = Duration(seconds: 1 * (retryCount + 1));
            delays.add(delay.inSeconds);
            if (retryCount >= 3) return null;
            return delay;
          },
          queryClient: client,
        ),
      );

      // Initial attempt
      await tester.pump(Duration.zero);
      expect(hook.current.failureCount, 1);

      // First retry after 1s delay
      await tester.pump(const Duration(seconds: 1));
      expect(hook.current.failureCount, 2);

      // Second retry after 2s delay
      await tester.pump(const Duration(seconds: 2));
      expect(hook.current.failureCount, 3);

      // Third retry after 3s delay
      await tester.pump(const Duration(seconds: 3));
      expect(hook.current.failureCount, 4);

      // Verify linear delays were calculated
      // Note: callback is called for each failure, even the last one
      // that doesn't result in a retry (returns null)
      expect(delays, [1, 2, 3, 4]);
    }));

    testWidgets('SHOULD pass correct args to retry callback',
        withCleanup((tester) async {
      var attempts = 0;
      final retryCounts = [];
      final errors = [];

      final hook = await buildHook(
        () => useQuery(
          const ['key'],
          (context) async {
            attempts++;
            await Future.delayed(Duration.zero);
            throw 'error-$attempts';
          },
          retry: (retryCount, error) {
            retryCounts.add(retryCount);
            errors.add(error);
            if (retryCount >= 3) return null;
            return const Duration(seconds: 1);
          },
          queryClient: client,
        ),
      );

      // Initial attempt
      await tester.pump(Duration.zero);
      expect(hook.current.failureCount, 1);

      // Retry for 3 times with fixed 1s delay
      for (var i = 0; i < 3; i++) {
        final retryNth = i + 1;
        await tester.pump(const Duration(seconds: 1));
        expect(hook.current.failureCount, 1 + retryNth);
      }

      // Verify callback received correct retryCount and error for each failure
      // Note: callback is called for each failure, even the last one
      // that doesn't result in a retry (returns null)
      expect(attempts, 4);
      expect(retryCounts, [0, 1, 2, 3]);
      expect(errors, ['error-1', 'error-2', 'error-3', 'error-4']);
    }));
  });

  group('refetch', () {
    testWidgets(
        'SHOULD refetch'
        'WHEN refetch is called', withCleanup((tester) async {
      var fetches = 0;

      final hook = await buildHook(
        () => useQuery(
          const ['key'],
          (context) async {
            fetches++;
            await Future.delayed(const Duration(seconds: 1));
            return 'data-$fetches';
          },
          staleDuration: StaleDuration.infinity,
          queryClient: client,
        ),
      );

      expect(hook.current.fetchStatus, FetchStatus.fetching);
      expect(fetches, 1);

      // Wait for initial fetch to complete
      await tester.pump(const Duration(seconds: 1));

      expect(hook.current.fetchStatus, FetchStatus.idle);
      expect(hook.current.data, 'data-1');

      // Call refetch using act to trigger state updates
      await act(() => hook.current.refetch());

      expect(hook.current.fetchStatus, FetchStatus.fetching);
      expect(fetches, 2);

      // Wait for refetch to complete
      await tester.pump(const Duration(seconds: 1));

      expect(hook.current.fetchStatus, FetchStatus.idle);
      expect(hook.current.data, 'data-2');
    }));

    testWidgets(
        'SHOULD cancel in-progress fetch AND refetch again '
        'WHEN cancelRefetch == true', withCleanup((tester) async {
      var fetches = 0;

      final hook = await buildHook(
        () => useQuery(
          const ['key'],
          (context) async {
            fetches++;
            await Future.delayed(const Duration(seconds: 5));
            return 'data-$fetches';
          },
          staleDuration: StaleDuration.infinity,
          queryClient: client,
        ),
      );

      // Wait for initial fetch to complete so we have data
      await tester.pump(const Duration(seconds: 5));
      expect(hook.current.data, 'data-1');
      expect(fetches, 1);

      // Start a refetch
      await act(() => hook.current.refetch());
      expect(hook.current.fetchStatus, FetchStatus.fetching);
      expect(fetches, 2);

      // Wait 2 seconds into the fetch (fetch takes 5 seconds)
      await tester.pump(const Duration(seconds: 2));

      // Call refetch again with cancelRefetch == true to cancel the in-progress fetch
      await act(() => hook.current.refetch(cancelRefetch: true));

      // New fetch should have started (the second fetch was cancelled)
      expect(hook.current.fetchStatus, FetchStatus.fetching);
      expect(hook.current.data, 'data-1');
      expect(fetches, 3);

      // Wait for new fetch to complete
      await tester.pump(const Duration(seconds: 5));

      // Should have data from third fetch
      expect(hook.current.fetchStatus, FetchStatus.idle);
      expect(hook.current.data, 'data-3');
    }));

    testWidgets(
        'SHOULD return in-progress fetch result '
        'WHEN cancelRefetch == false', withCleanup((tester) async {
      var fetches = 0;

      final hook = await buildHook(
        () => useQuery(
          const ['key'],
          (context) async {
            fetches++;
            await Future.delayed(const Duration(seconds: 5));
            return 'data-$fetches';
          },
          staleDuration: StaleDuration.infinity,
          queryClient: client,
        ),
      );

      // Wait for initial fetch to complete so we have data
      await tester.pump(const Duration(seconds: 5));
      expect(hook.current.data, 'data-1');
      expect(fetches, 1);

      // Start a refetch
      await act(() => hook.current.refetch());
      expect(hook.current.fetchStatus, FetchStatus.fetching);
      expect(fetches, 2);

      // Wait 2 seconds into the fetch
      await tester.pump(const Duration(seconds: 2));

      // Call refetch with cancelRefetch == false - should NOT cancel current fetch
      await act(() => hook.current.refetch(cancelRefetch: false));

      // Should NOT have started a new fetch
      expect(fetches, 2);

      // Wait for fetch to complete
      await tester.pump(const Duration(seconds: 3));

      // Should have data from second fetch
      expect(hook.current.data, 'data-2');
      expect(fetches, 2);
    }));

    testWidgets(
        'SHOULD swallow errors '
        'WHEN throwOnError == false', withCleanup((tester) async {
      var fetches = 0;

      final hook = await buildHook(
        () => useQuery<String, Object>(
          const ['key'],
          (context) async {
            fetches++;
            await Future.delayed(const Duration(seconds: 3));
            throw Exception();
          },
          retry: (_, __) => null,
          queryClient: client,
        ),
      );

      // Wait for initial fetch to fail
      await tester.pump(const Duration(seconds: 3));
      expect(hook.current.status, QueryStatus.error);
      expect(hook.current.error, isA<Exception>());
      expect(fetches, 1);

      // Call refetch using act - should NOT throw
      Object? caughtError;

      await act(() async {
        try {
          await hook.current.refetch(throwOnError: false);
        } catch (e) {
          caughtError = e;
        }
      });

      await tester.pump(const Duration(seconds: 3));

      expect(caughtError, isNull);
      expect(fetches, 2);
    }));

    testWidgets(
        'SHOULD propagate errors '
        'WHEN throwOnError == true', withCleanup((tester) async {
      var fetches = 0;
      final thrownError = Exception();

      final hook = await buildHook(
        () => useQuery<String, Object>(
          const ['key'],
          (context) async {
            fetches++;
            await Future.delayed(const Duration(seconds: 3));
            throw thrownError;
          },
          retry: (_, __) => null,
          queryClient: client,
        ),
      );

      // Wait for initial fetch to fail
      await tester.pump(const Duration(seconds: 3));
      expect(hook.current.status, QueryStatus.error);
      expect(hook.current.error, same(thrownError));
      expect(fetches, 1);

      Object? caughtError;

      await act(() async {
        try {
          await hook.current.refetch(throwOnError: true);
        } catch (e) {
          caughtError = e;
        }
      });

      await tester.pump(const Duration(seconds: 3));

      // Verify the error was thrown
      expect(caughtError, same(thrownError));
      expect(fetches, 2);
    }));

    testWidgets(
        'SHOULD return updated QueryResult'
        '', withCleanup((tester) async {
      var fetches = 0;

      final hook = await buildHook(
        () => useQuery(
          const ['key'],
          (context) async {
            fetches++;
            await Future.delayed(const Duration(seconds: 3));
            return 'data-$fetches';
          },
          staleDuration: StaleDuration.infinity,
          queryClient: client,
        ),
      );

      // Wait for initial fetch to complete
      await tester.pump(const Duration(seconds: 3));
      expect(hook.current.data, 'data-1');

      // Call refetch and capture returned result
      late final QueryResult result;

      await act(() async {
        result = await hook.current.refetch();
      });

      // Wait for refetch to complete
      await tester.pump(const Duration(seconds: 3));
      // Should return updated data
      expect(result.data, 'data-2');
    }));
  });

  group('isFetchedAfterMount', () {
    testWidgets('SHOULD be false initially and true after successful fetch',
        withCleanup((tester) async {
      final hook = await buildHook(
        () => useQuery(
          const ['key'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'data';
          },
          queryClient: client,
        ),
      );

      // Initially false (no fetch completed yet)
      expect(hook.current.isFetchedAfterMount, false);

      // Wait for fetch to complete
      await tester.pump(const Duration(seconds: 1));

      // Now true after successful fetch
      expect(hook.current.isFetchedAfterMount, true);
    }));

    testWidgets('SHOULD be true after failed fetch',
        withCleanup((tester) async {
      final hook = await buildHook(
        () => useQuery<String, Object>(
          const ['key'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            throw Exception('error');
          },
          retry: (_, __) => null,
          queryClient: client,
        ),
      );

      // Initially false
      expect(hook.current.isFetchedAfterMount, false);

      // Wait for fetch to fail
      await tester.pump(const Duration(seconds: 1));

      // True after fetch (even though it failed)
      expect(hook.current.status, QueryStatus.error);
      expect(hook.current.isFetchedAfterMount, true);
    }));

    testWidgets('SHOULD be false when using cached data from before mount',
        withCleanup((tester) async {
      // First, prime the cache with data
      final hook1 = await buildHook(
        () => useQuery(
          const ['key'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'cached-data';
          },
          queryClient: client,
        ),
      );

      // Wait for first fetch to complete
      await tester.pump(const Duration(seconds: 1));
      expect(hook1.current.data, 'cached-data');
      expect(hook1.current.isFetchedAfterMount, true);

      // Unmount first widget
      await tester.pumpWidget(Container());

      // Mount a new widget with the same key and staleDuration.infinity
      // so it won't refetch
      final hook2 = await buildHook(
        () => useQuery(
          const ['key'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'new-data';
          },
          staleDuration: StaleDuration.infinity,
          queryClient: client,
        ),
      );

      // Should have cached data immediately but isFetchedAfterMount is false
      // because the data was cached before this observer mounted
      expect(hook2.current.data, 'cached-data');
      expect(hook2.current.isFetchedAfterMount, false);
    }));

    testWidgets('SHOULD reset to false when query key changes',
        withCleanup((tester) async {
      final hook = await buildHookWithProps(
        (key) => useQuery(
          key,
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'data-${key.first}';
          },
          queryClient: client,
        ),
        initialProps: const ['key-1'],
      );

      // Wait for initial fetch to complete
      await tester.pump(const Duration(seconds: 1));
      expect(hook.current.isFetchedAfterMount, true);

      // Change query key
      await hook.rebuildWithProps(const ['key-2']);

      // Should be false for the new query (hasn't fetched yet)
      expect(hook.current.isFetchedAfterMount, false);

      // Wait for new fetch to complete
      await tester.pump(const Duration(seconds: 1));

      // Now true again after fetch completed
      expect(hook.current.isFetchedAfterMount, true);
    }));
  });

  group('meta', () {
    testWidgets('SHOULD pass meta to query function via context',
        withCleanup((tester) async {
      final meta = {'feature': 'user-list', 'experiment': 'v2'};
      Map<String, dynamic>? capturedMeta;

      await buildHook(
        () => useQuery(
          const ['users'],
          (context) async {
            capturedMeta = context.meta;
            return 'data';
          },
          meta: meta,
          queryClient: client,
        ),
      );

      await tester.pumpAndSettle();

      expect(capturedMeta, meta);
      expect(capturedMeta!['feature'], 'user-list');
      expect(capturedMeta!['experiment'], 'v2');
    }));

    testWidgets('SHOULD pass empty meta WHEN not provided',
        withCleanup((tester) async {
      Map<String, dynamic>? capturedMeta;
      var wasCalled = false;

      await buildHook(
        () => useQuery(
          const ['users'],
          (context) async {
            wasCalled = true;
            capturedMeta = context.meta;
            return 'data';
          },
          queryClient: client,
        ),
      );

      await tester.pumpAndSettle();

      expect(wasCalled, isTrue);
      expect(capturedMeta, isEmpty);
    }));
  });
}
