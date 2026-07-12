import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_hooks_test/flutter_hooks_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_query/src/core/core.dart';
import 'package:flutter_query/src/hooks/hooks.dart';
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

  testWidgets(
      'SHOULD succeed fetching on mount'
      '', withCleanup((tester) async {
    final hook = await buildHook(
      () => useInfiniteQuery<String, Object, int>(
        const ['test'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'page-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        client: client,
      ),
    );

    expect(hook.current.isPending, isTrue);
    expect(hook.current.fetchStatus, FetchStatus.fetching);
    expect(hook.current.dataOrNull, isNull);
    expect(hook.current.dataUpdatedAt, isNull);
    expect(hook.current.dataUpdateCount, 0);

    await tester.pump(const Duration(seconds: 1));

    expect(hook.current.isSuccess, isTrue);
    expect(hook.current.fetchStatus, FetchStatus.idle);
    expect(hook.current.dataOrNull, InfiniteData(['page-0'], [0]));
    expect(hook.current.dataUpdatedAt, clock.now());
    expect(hook.current.dataUpdateCount, 1);
  }));

  testWidgets(
      'SHOULD fail fetching on mount'
      '', withCleanup((tester) async {
    final expectedError = Exception();

    final hook = await buildHook(
      () => useInfiniteQuery<String, Object, int>(
        const ['test'],
        (context) async {
          await Future.delayed(const Duration(seconds: 1));
          throw expectedError;
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        client: client,
      ),
    );

    expect(hook.current.isPending, isTrue);
    expect(hook.current.fetchStatus, FetchStatus.fetching);
    expect(hook.current.isError, isFalse);
    expect(hook.current.errorUpdatedAt, isNull);
    expect(hook.current.errorUpdateCount, 0);

    await tester.pump(const Duration(seconds: 1));

    expect(hook.current.isError, isTrue);
    expect(hook.current.fetchStatus, FetchStatus.idle);
    expect((hook.current as InfiniteQueryError<String, Object, int>).error,
        same(expectedError));
    expect(hook.current.errorUpdatedAt, clock.now());
    expect(hook.current.errorUpdateCount, 1);
  }));

  testWidgets(
      'SHOULD fetch only once '
      'WHEN multiple hooks share same key', withCleanup((tester) async {
    var fetches = 0;
    late InfiniteQuerySnapshot<String, Object, int> result1;
    late InfiniteQuerySnapshot<String, Object, int> result2;

    await tester.pumpWidget(Column(children: [
      HookBuilder(
        builder: (context) {
          result1 = useInfiniteQuery<String, Object, int>(
            const ['key'],
            (context) async {
              await Future.delayed(const Duration(seconds: 1));
              fetches++;
              return 'page-$fetches';
            },
            initialPageParam: 0,
            nextPageParamBuilder: (data) => data.pageParams.last + 1,
            client: client,
          );
          return Container();
        },
      ),
      HookBuilder(
        builder: (context) {
          result2 = useInfiniteQuery<String, Object, int>(
            const ['key'],
            (context) async {
              await Future.delayed(const Duration(seconds: 1));
              fetches++;
              return 'page-$fetches';
            },
            initialPageParam: 0,
            nextPageParamBuilder: (data) => data.pageParams.last + 1,
            client: client,
          );
          return Container();
        },
      ),
    ]));

    expect(result1.dataOrNull, null);
    expect(result2.dataOrNull, null);

    await tester.pump(const Duration(seconds: 1));

    expect(fetches, 1);
    expect(result1.pages, ['page-1']);
    expect(result2.pages, ['page-1']);
  }));

  testWidgets(
      'SHOULD fetch individually '
      'WHEN multiple hooks have different keys', withCleanup((tester) async {
    late InfiniteQuerySnapshot<String, Object, int> result1;
    late InfiniteQuerySnapshot<String, Object, int> result2;

    await tester.pumpWidget(Column(
      children: [
        HookBuilder(builder: (context) {
          result1 = useInfiniteQuery<String, Object, int>(
            const ['key1'],
            (context) async {
              await Future.delayed(const Duration(seconds: 1));
              return 'key1-page-${context.pageParam}';
            },
            initialPageParam: 0,
            nextPageParamBuilder: (_) => null,
            client: client,
          );
          return Container();
        }),
        HookBuilder(builder: (context) {
          result2 = useInfiniteQuery<String, Object, int>(
            const ['key2'],
            (context) async {
              await Future.delayed(const Duration(seconds: 2));
              return 'key2-page-${context.pageParam}';
            },
            initialPageParam: 0,
            nextPageParamBuilder: (_) => null,
            client: client,
          );
          return Container();
        }),
      ],
    ));

    await tester.pump(const Duration(seconds: 1));

    expect(result1.pages, ['key1-page-0']);
    expect(result2.pages, []);

    await tester.pump(const Duration(seconds: 1));

    expect(result1.pages, ['key1-page-0']);
    expect(result2.pages, ['key2-page-0']);
  }));

  group('Params: queryKey', () {
    testWidgets(
        'SHOULD switch to new query '
        'WHEN queryKey changes', withCleanup((tester) async {
      final hook = await buildHookWithProps(
        (key) => useInfiniteQuery<String, Object, int>(
          key,
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return '$key-page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          client: client,
        ),
        initialProps: const ['test1'],
      );

      await tester.pump(const Duration(seconds: 1));
      expect(hook.current.isSuccess, isTrue);
      expect(hook.current.pages, ['[test1]-page-0']);

      await hook.rebuildWithProps(const ['test2']);
      expect(hook.current.isPending, isTrue);
      expect(hook.current.pages, []);

      await tester.pump(const Duration(seconds: 1));
      expect(hook.current.isSuccess, isTrue);
      expect(hook.current.pages, ['[test2]-page-0']);
    }));
  });

  group('Params: queryFn', () {
    testWidgets(
        'SHOULD receive correct InfiniteQueryFunctionContext'
        '', withCleanup((tester) async {
      late InfiniteQueryFunctionContext<int> capturedContext;

      await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['users', 123],
          (context) async {
            capturedContext = context;
            return 'page-${context.pageParam}';
          },
          initialPageParam: 10,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          meta: {'key': 'value'},
          client: client,
        ),
      );

      expect(capturedContext.queryKey, const ['users', 123]);
      expect(capturedContext.client, same(client));
      expect(capturedContext.signal, isA<AbortSignal>());
      expect(capturedContext.meta, {'key': 'value'});
      expect(capturedContext.pageParam, 10);
      expect(capturedContext.direction, FetchDirection.forward);
    }));

    testWidgets(
        'SHOULD receive context with direction forward '
        'WHEN fetchNextPage is called', withCleanup((tester) async {
      final capturedContexts = <InfiniteQueryFunctionContext<int>>[];

      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            capturedContexts.add(context);
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          client: client,
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      expect(capturedContexts.length, 1);
      expect(capturedContexts[0].pageParam, 0);
      expect(capturedContexts[0].direction, FetchDirection.forward);

      await act(hook.current.fetchNextPage);
      await tester.pump(const Duration(seconds: 1));

      expect(capturedContexts.length, 2);
      expect(capturedContexts[1].pageParam, 1);
      expect(capturedContexts[1].direction, FetchDirection.forward);
    }));

    testWidgets(
        'SHOULD receive context with direction backward '
        'WHEN fetchPreviousPage is called', withCleanup((tester) async {
      final capturedContexts = <InfiniteQueryFunctionContext<int>>[];

      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            capturedContexts.add(context);
            return 'page-${context.pageParam}';
          },
          initialPageParam: 5,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          prevPageParamBuilder: (data) => data.pageParams.first - 1,
          client: client,
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      expect(capturedContexts.length, 1);
      expect(capturedContexts[0].pageParam, 5);
      expect(capturedContexts[0].direction, FetchDirection.forward);

      await act(hook.current.fetchPreviousPage);
      await tester.pump(const Duration(seconds: 1));

      expect(capturedContexts.length, 2);
      expect(capturedContexts[1].pageParam, 4);
      expect(capturedContexts[1].direction, FetchDirection.backward);
    }));
  });

  group('Params: enabled', () {
    testWidgets(
        'SHOULD fetch on mount '
        'WHEN enabled == true', withCleanup((tester) async {
      var fetches = 0;

      await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          enabled: true,
          client: client,
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      expect(fetches, 1);
    }));

    testWidgets(
        'SHOULD NOT fetch on mount '
        'WHEN enabled == false', withCleanup((tester) async {
      var fetches = 0;

      await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          enabled: false,
          client: client,
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      expect(fetches, 0);
    }));

    testWidgets(
        'SHOULD fetch '
        'WHEN enabled changes from false to true', withCleanup((tester) async {
      var fetches = 0;

      final hook = await buildHookWithProps(
        (enabled) => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          enabled: enabled,
          client: client,
        ),
        initialProps: false,
      );

      await tester.pump(const Duration(seconds: 1));
      expect(fetches, 0);

      await hook.rebuildWithProps(true);

      await tester.pump(const Duration(seconds: 1));
      expect(fetches, 1);
    }));

    testWidgets(
        'SHOULD allow fetching next page '
        'WHEN enabled == false', withCleanup((tester) async {
      var fetches = 0;

      final hook = await buildHookWithProps(
        (enabled) => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          enabled: enabled,
          client: client,
        ),
        initialProps: true,
      );

      await tester.pump(const Duration(seconds: 1));
      expect(fetches, 1);

      await hook.rebuildWithProps(false);
      await act(hook.current.fetchNextPage);

      await tester.pump(const Duration(seconds: 1));
      expect(fetches, 2);
    }));

    testWidgets(
        'SHOULD allow fetching previous page '
        'WHEN enabled == false', withCleanup((tester) async {
      var fetches = 0;

      final hook = await buildHookWithProps(
        (enabled) => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'page-${context.pageParam}';
          },
          initialPageParam: 5,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          prevPageParamBuilder: (data) => data.pageParams.first - 1,
          enabled: enabled,
          client: client,
        ),
        initialProps: true,
      );

      await tester.pump(const Duration(seconds: 1));
      expect(fetches, 1);

      await hook.rebuildWithProps(false);
      await act(hook.current.fetchPreviousPage);

      await tester.pump(const Duration(seconds: 1));
      expect(fetches, 2);
    }));

    testWidgets(
        'SHOULD allow refetching '
        'WHEN enabled == false', withCleanup((tester) async {
      var fetches = 0;

      final hook = await buildHookWithProps(
        (enabled) => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          enabled: enabled,
          client: client,
        ),
        initialProps: true,
      );

      await tester.pump(const Duration(seconds: 1));
      expect(fetches, 1);

      await hook.rebuildWithProps(false);
      await act(hook.current.refetch);

      await tester.pump(const Duration(seconds: 1));
      expect(fetches, 2);
    }));
  });

  group('Params: staleDuration', () {
    testWidgets(
        'SHOULD be stale immediately '
        'WHEN staleDuration == StaleDuration.zero', withCleanup((tester) async {
      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          staleDuration: StaleDuration.zero,
          client: client,
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      expect(hook.current.isStale, isTrue);
    }));

    testWidgets(
        'SHOULD be stale '
        'WHEN staleDuration has elapsed', withCleanup((tester) async {
      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          staleDuration: const StaleDuration(minutes: 5),
          client: client,
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      expect(hook.current.isStale, isFalse);

      await hook.unmount();
      await tester.binding.delayed(const Duration(minutes: 5));
      await hook.rebuild();

      expect(hook.current.isStale, isTrue);
    }));

    testWidgets(
        'SHOULD NOT be stale forever'
        'WHEN staleDuration == StaleDuration.infinity',
        withCleanup((tester) async {
      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          staleDuration: StaleDuration.infinity,
          client: client,
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      expect(hook.current.isStale, isFalse);

      await tester.binding.delayed(const Duration(days: 365));

      expect(hook.current.isStale, isFalse);
    }));

    testWidgets(
        'SHOULD NOT be stale forever'
        'WHEN staleDuration == StaleDuration.static',
        withCleanup((tester) async {
      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          staleDuration: StaleDuration.static,
          client: client,
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      expect(hook.current.isStale, isFalse);

      await tester.binding.delayed(const Duration(days: 365));

      expect(hook.current.isStale, isFalse);
    }));

    testWidgets(
        'SHOULD be stale on cache invalidation '
        'WHEN staleDuration == StaleDuration.infinity',
        withCleanup((tester) async {
      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          staleDuration: StaleDuration.infinity,
          client: client,
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      expect(hook.current.isStale, isFalse);

      await hook.unmount();
      client.invalidateQueries(queryKey: const ['test']);
      await hook.rebuild();

      expect(hook.current.isStale, isTrue);
    }));

    testWidgets(
        'SHOULD NOT be stale on cache invalidation '
        'WHEN staleDuration == StaleDuration.static',
        withCleanup((tester) async {
      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          staleDuration: StaleDuration.static,
          client: client,
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      expect(hook.current.isStale, isFalse);

      await hook.unmount();
      client.invalidateQueries(queryKey: const ['test']);
      await hook.rebuild();

      expect(hook.current.isStale, isFalse);
    }));
  });

  group('Params: gcDuration', () {
    testWidgets(
        'SHOULD remove query from cache '
        'WHEN gcDuration has elapsed '
        'AND there are no observers', withCleanup((tester) async {
      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          gcDuration: const GcDuration(minutes: 5),
          client: client,
        ),
      );

      // Garbage collection is scheduled after fetch completes
      await tester.binding.delayed(const Duration(seconds: 1));

      expect(client.cache.get(const ['test']), isNotNull);

      await hook.unmount();
      await tester.binding.delayed(const Duration(minutes: 5));

      expect(client.cache.get(const ['test']), isNull);
    }));

    testWidgets(
        'SHOULD NOT remove query from cache '
        'WHEN gcDuration has elapsed '
        'AND there are remaining observers', withCleanup((tester) async {
      // Create two hooks in the same widget tree
      await tester.pumpWidget(Column(
        children: [
          HookBuilder(
            key: Key('hook1'),
            builder: (context) {
              useInfiniteQuery<String, Object, int>(
                const ['test'],
                (context) async {
                  await Future.delayed(const Duration(seconds: 1));
                  return 'page-${context.pageParam}';
                },
                initialPageParam: 0,
                nextPageParamBuilder: (data) => data.pageParams.last + 1,
                gcDuration: const GcDuration(minutes: 5),
                client: client,
              );
              return Container();
            },
          ),
          HookBuilder(
            key: Key('hook2'),
            builder: (context) {
              useInfiniteQuery<String, Object, int>(
                const ['test'],
                (context) async {
                  await Future.delayed(const Duration(seconds: 1));
                  return 'page-${context.pageParam}';
                },
                initialPageParam: 0,
                nextPageParamBuilder: (data) => data.pageParams.last + 1,
                gcDuration: const GcDuration(minutes: 5),
                client: client,
              );
              return Container();
            },
          ),
        ],
      ));

      expect(client.cache.get(const ['test']), isNotNull);

      // Remove only the first hook, keeping the second one
      await tester.pumpWidget(Column(
        children: [
          HookBuilder(
            key: Key('hook2'),
            builder: (context) {
              useInfiniteQuery<String, Object, int>(
                const ['test'],
                (context) async {
                  await Future.delayed(const Duration(seconds: 1));
                  return 'page-${context.pageParam}';
                },
                initialPageParam: 0,
                nextPageParamBuilder: (data) => data.pageParams.last + 1,
                gcDuration: const GcDuration(minutes: 5),
                client: client,
              );
              return Container();
            },
          ),
        ],
      ));

      await tester.binding.delayed(const Duration(minutes: 5));

      // Query should still exist because second hook is still mounted
      expect(client.cache.get(const ['test']), isNotNull);
    }));

    testWidgets(
        'SHOULD remove query from cache immediately '
        'WHEN gcDuration == GcDuration.zero '
        'AND there are no observers', withCleanup((tester) async {
      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          gcDuration: GcDuration.zero,
          client: client,
        ),
      );

      // Wait for fetch to complete
      await tester.pump(const Duration(seconds: 1));

      expect(client.cache.get(const ['test']), isNotNull);

      await hook.unmount();
      // Query should be removed immediately (after zero-duration timer fires)
      await tester.binding.delayed(Duration.zero);

      expect(client.cache.get(const ['test']), isNull);
    }));

    testWidgets(
        'SHOULD NOT remove query from cache '
        'WHEN gcDuration == GcDuration.infinity', withCleanup((tester) async {
      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          gcDuration: GcDuration.infinity,
          client: client,
        ),
      );

      await hook.unmount();
      await tester.binding.delayed(const Duration(days: 365));

      expect(client.cache.get(const ['test']), isNotNull);
    }));

    testWidgets(
        'SHOULD use longest gcDuration '
        'WHEN multiple observers have different values',
        withCleanup((tester) async {
      // Create two hooks with different gcDurations
      await tester.pumpWidget(Column(
        children: [
          HookBuilder(
            key: const Key('hook1'),
            builder: (context) {
              useInfiniteQuery<String, Object, int>(
                const ['test'],
                (context) async {
                  await Future.delayed(const Duration(seconds: 1));
                  return 'page-${context.pageParam}';
                },
                initialPageParam: 0,
                nextPageParamBuilder: (data) => data.pageParams.last + 1,
                gcDuration: const GcDuration(minutes: 5),
                client: client,
              );
              return Container();
            },
          ),
          HookBuilder(
            key: const Key('hook2'),
            builder: (context) {
              useInfiniteQuery<String, Object, int>(
                const ['test'],
                (context) async {
                  await Future.delayed(const Duration(seconds: 1));
                  return 'page-${context.pageParam}';
                },
                initialPageParam: 0,
                nextPageParamBuilder: (data) => data.pageParams.last + 1,
                gcDuration: const GcDuration(minutes: 10),
                client: client,
              );
              return Container();
            },
          ),
        ],
      ));

      // Garbage collection is scheduled after fetch completes
      await tester.binding.delayed(const Duration(seconds: 1));

      expect(client.cache.get(const ['test']), isNotNull);

      // Unmount both hooks
      await tester.pumpWidget(Container());

      // Wait for shorter gcDuration (5 minutes)
      await tester.binding.delayed(const Duration(minutes: 5));

      // Query should still exist (longest gcDuration is 10 minutes)
      expect(client.cache.get(const ['test']), isNotNull);

      // Wait for remaining time until longest gcDuration
      await tester.binding.delayed(const Duration(minutes: 5));

      // Now query should be removed
      expect(client.cache.get(const ['test']), isNull);
    }));

    testWidgets(
        'SHOULD use remaining observer gcDuration '
        'WHEN observer with longer gcDuration is unmounted first',
        withCleanup((tester) async {
      // Create two hooks: hook1 with longer gcDuration, hook2 with shorter
      await tester.pumpWidget(Column(
        children: [
          HookBuilder(
            key: const Key('hook1'),
            builder: (context) {
              useInfiniteQuery<String, Object, int>(
                const ['test'],
                (context) async {
                  await Future.delayed(const Duration(seconds: 1));
                  return 'page-${context.pageParam}';
                },
                initialPageParam: 0,
                nextPageParamBuilder: (data) => data.pageParams.last + 1,
                gcDuration: const GcDuration(minutes: 10),
                client: client,
              );
              return Container();
            },
          ),
          HookBuilder(
            key: const Key('hook2'),
            builder: (context) {
              useInfiniteQuery<String, Object, int>(
                const ['test'],
                (context) async {
                  await Future.delayed(const Duration(seconds: 1));
                  return 'page-${context.pageParam}';
                },
                initialPageParam: 0,
                nextPageParamBuilder: (data) => data.pageParams.last + 1,
                gcDuration: const GcDuration(minutes: 3),
                client: client,
              );
              return Container();
            },
          ),
        ],
      ));

      await tester.pump(const Duration(seconds: 1));

      expect(client.cache.get(const ['test']), isNotNull);

      // Unmount hook1 (longer gcDuration), keep hook2 (shorter gcDuration)
      await tester.pumpWidget(Column(
        children: [
          HookBuilder(
            key: const Key('hook2'),
            builder: (context) {
              useInfiniteQuery<String, Object, int>(
                const ['test'],
                (context) async {
                  await Future.delayed(const Duration(seconds: 1));
                  return 'page-${context.pageParam}';
                },
                initialPageParam: 0,
                nextPageParamBuilder: (data) => data.pageParams.last + 1,
                gcDuration: const GcDuration(minutes: 3),
                client: client,
              );
              return Container();
            },
          ),
        ],
      ));

      // Query should still exist (hook2 is still mounted)
      expect(client.cache.get(const ['test']), isNotNull);

      // Unmount hook2 as well
      await tester.pumpWidget(Container());

      // Wait for hook2's gcDuration (3 minutes), not hook1's (10 minutes)
      await tester.binding.delayed(const Duration(minutes: 3));

      // Query should be removed after hook2's gcDuration
      expect(client.cache.get(const ['test']), isNull);
    }));
  });

  group('Params: placeholder', () {
    testWidgets(
        'SHOULD use placeholder'
        '', withCleanup((tester) async {
      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          placeholder: const InfiniteData(['page-ph'], [0]),
          client: client,
        ),
      );

      expect(hook.current.pages, ['page-ph']);
      expect(
          (hook.current as InfiniteQuerySuccess<String, Object, int>)
              .isPlaceholder,
          isTrue);
      expect(hook.current.isSuccess, isTrue);
    }));

    testWidgets(
        'SHOULD NOT persist placeholder to cache'
        '', withCleanup((tester) async {
      await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          placeholder: const InfiniteData(['page-ph'], [0]),
          client: client,
        ),
      );

      expect(client.cache.get(const ['test'])!.state.data, isNull);
    }));

    testWidgets(
        'SHOULD be replaced by fetched data'
        '', withCleanup((tester) async {
      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          placeholder: const InfiniteData(['page-ph'], [0]),
          client: client,
        ),
      );

      expect(hook.current.pages, ['page-ph']);
      expect(
          (hook.current as InfiniteQuerySuccess<String, Object, int>)
              .isPlaceholder,
          isTrue);

      await tester.pump(const Duration(seconds: 1));

      expect(hook.current.pages, ['page-0']);
      expect(
          (hook.current as InfiniteQuerySuccess<String, Object, int>)
              .isPlaceholder,
          isFalse);
    }));

    testWidgets(
        'SHOULD NOT use placeholder '
        'WHEN data already exists', withCleanup((tester) async {
      // First hook fetches real data
      final hook1 = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          client: client,
        ),
      );

      await tester.pump(const Duration(seconds: 1));
      expect(hook1.current.pages, ['page-0']);

      // Second hook should use cached real data, not placeholder
      late InfiniteQuerySnapshot<String, Object, int> result2;
      await tester.pumpWidget(HookBuilder(
        builder: (context) {
          result2 = useInfiniteQuery<String, Object, int>(
            const ['test'],
            (context) async {
              await Future.delayed(const Duration(seconds: 1));
              return 'page-${context.pageParam}';
            },
            initialPageParam: 0,
            nextPageParamBuilder: (data) => data.pageParams.last + 1,
            placeholder: const InfiniteData(['page-ph'], [0]),
            client: client,
          );
          return Container();
        },
      ));

      expect(result2.pages, ['page-0']);
      expect(
          (result2 as InfiniteQuerySuccess<String, Object, int>).isPlaceholder,
          isFalse);
    }));
  });

  group('Params: refetchOnMount', () {
    testWidgets(
        'SHOULD refetch on mount '
        'WHEN refetchOnMount == RefetchOnMount.stale '
        'AND data is stale', withCleanup((tester) async {
      var fetches = 0;

      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
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
          client: client,
        ),
      );

      await tester.pump(const Duration(seconds: 1));
      expect(fetches, 1);

      // Make data stale
      await tester.binding.delayed(const Duration(minutes: 5));
      await hook.unmount();
      await hook.rebuild();

      expect(hook.current.isStale, isTrue);

      await tester.pump(const Duration(seconds: 1));
      expect(fetches, 2);
    }));

    testWidgets(
        'SHOULD NOT refetch on mount '
        'WHEN refetchOnMount == RefetchOnMount.stale '
        'AND data is fresh', withCleanup((tester) async {
      var fetches = 0;

      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
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
          client: client,
        ),
      );

      await tester.pump(const Duration(seconds: 1));
      expect(fetches, 1);

      // Unmount first observer
      await hook.unmount();
      await hook.rebuild();

      expect(hook.current.isStale, isFalse);

      await tester.pump(const Duration(seconds: 1));
      expect(fetches, 1);
    }));

    testWidgets(
        'SHOULD NOT refetch on mount '
        'WHEN refetchOnMount == RefetchOnMount.never '
        'AND data is stale', withCleanup((tester) async {
      var fetches = 0;

      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
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
          client: client,
        ),
      );

      await tester.pump(const Duration(seconds: 1));
      expect(fetches, 1);

      // Make data stale
      await tester.binding.delayed(const Duration(minutes: 5));
      await hook.unmount();
      await hook.rebuild();

      expect(hook.current.isStale, isTrue);

      await tester.pump(const Duration(seconds: 1));
      expect(fetches, 1);
    }));

    testWidgets(
        'SHOULD refetch on mount '
        'WHEN refetchOnMount == RefetchOnMount.always '
        'AND data is fresh', withCleanup((tester) async {
      var fetches = 0;

      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
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
          client: client,
        ),
      );

      await tester.pump(const Duration(seconds: 1));
      expect(fetches, 1);

      await hook.unmount();
      await hook.rebuild();

      expect(hook.current.isStale, isFalse);

      await tester.pump(const Duration(seconds: 1));
      expect(fetches, 2);
    }));
  });

  group('Params: refetchOnResume', () {
    testWidgets(
        'SHOULD refetch on resume '
        'WHEN refetchOnResume == RefetchOnResume.stale '
        'AND data is stale', withCleanup((tester) async {
      var fetches = 0;

      await buildHook(
        () => useInfiniteQuery<String, Object, int>(
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
          client: client,
        ),
      );

      await tester.pump(const Duration(seconds: 1));
      expect(fetches, 1);

      await tester.binding.delayed(const Duration(minutes: 5));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      await tester.pump(const Duration(seconds: 1));
      expect(fetches, 2);
    }));

    testWidgets(
        'SHOULD NOT refetch on resume '
        'WHEN refetchOnResume == RefetchOnResume.stale '
        'AND data is fresh', withCleanup((tester) async {
      var fetches = 0;

      await buildHook(
        () => useInfiniteQuery<String, Object, int>(
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
          client: client,
        ),
      );

      await tester.pump(const Duration(seconds: 1));
      expect(fetches, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      await tester.pump(const Duration(seconds: 1));
      expect(fetches, 1);
    }));

    testWidgets(
        'SHOULD NOT refetch on resume '
        'WHEN refetchOnResume == RefetchOnResume.never '
        'AND data is stale', withCleanup((tester) async {
      var fetches = 0;

      await buildHook(
        () => useInfiniteQuery<String, Object, int>(
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
          client: client,
        ),
      );

      await tester.pump(const Duration(seconds: 1));
      expect(fetches, 1);

      await tester.binding.delayed(const Duration(minutes: 5));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      await tester.pump(const Duration(seconds: 1));
      expect(fetches, 1);
    }));

    testWidgets(
        'SHOULD refetch on resume '
        'WHEN refetchOnResume == RefetchOnResume.always '
        'AND data is fresh', withCleanup((tester) async {
      var fetches = 0;

      await buildHook(
        () => useInfiniteQuery<String, Object, int>(
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
          client: client,
        ),
      );

      await tester.pump(const Duration(seconds: 1));
      expect(fetches, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      await tester.pump(const Duration(seconds: 1));
      expect(fetches, 2);
    }));
  });

  group('Parameter: refetchOnReconnect', () {
    testWidgets(
        'SHOULD refetch stale data '
        'WHEN refetchOnReconnect == RefetchOnReconnect.stale',
        withCleanup((tester) async {
      final connectivityController = StreamController<bool>();
      addTearDown(connectivityController.close);

      final reconnectClient = QueryClient(
        connectivityChanges: connectivityController.stream,
      );
      addTearDown(reconnectClient.clear);

      var fetches = 0;
      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          staleDuration: StaleDuration.zero,
          refetchOnReconnect: RefetchOnReconnect.stale,
          client: reconnectClient,
        ),
      );

      // Emit initial online state
      connectivityController.add(true);
      await tester.pump(const Duration(seconds: 1));

      expect(hook.current.dataOrNull?.pages, ['page-0']);
      expect(hook.current.isStale, isTrue);
      expect(fetches, 1);

      // Go offline then back online - should trigger reconnect
      connectivityController.add(false);
      connectivityController.add(true);
      await tester.pumpAndSettle();

      expect(hook.current.fetchStatus, FetchStatus.fetching);

      await tester.pump(const Duration(seconds: 1));

      expect(hook.current.fetchStatus, FetchStatus.idle);
      expect(hook.current.dataOrNull?.pages, ['page-0']);
      expect(fetches, 2);
    }));

    testWidgets(
        'SHOULD NOT refetch fresh data '
        'WHEN refetchOnReconnect == RefetchOnReconnect.stale',
        withCleanup((tester) async {
      final connectivityController = StreamController<bool>();
      addTearDown(connectivityController.close);

      final reconnectClient = QueryClient(
        connectivityChanges: connectivityController.stream,
      );
      addTearDown(reconnectClient.clear);

      var fetches = 0;
      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          staleDuration: StaleDuration.infinity,
          refetchOnReconnect: RefetchOnReconnect.stale,
          client: reconnectClient,
        ),
      );

      // Emit initial online state and process stream event
      connectivityController.add(true);
      await tester.pump(const Duration(seconds: 1));

      expect(hook.current.dataOrNull?.pages, ['page-0']);
      expect(hook.current.isStale, isFalse);
      expect(fetches, 1);

      // Go offline and go back online - should not trigger reconnect
      connectivityController.add(false);
      connectivityController.add(true);
      await tester.pumpAndSettle();

      expect(hook.current.fetchStatus, FetchStatus.idle);

      await tester.pump(const Duration(seconds: 1));

      expect(hook.current.fetchStatus, FetchStatus.idle);
      expect(hook.current.dataOrNull?.pages, ['page-0']);
      expect(fetches, 1);
    }));

    testWidgets(
        'SHOULD NOT refetch stale data '
        'WHEN refetchOnReconnect == RefetchOnReconnect.never',
        withCleanup((tester) async {
      final connectivityController = StreamController<bool>();
      addTearDown(connectivityController.close);

      final reconnectClient = QueryClient(
        connectivityChanges: connectivityController.stream,
      );
      addTearDown(reconnectClient.clear);

      var fetches = 0;
      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          staleDuration: StaleDuration.zero,
          refetchOnReconnect: RefetchOnReconnect.never,
          client: reconnectClient,
        ),
      );

      // Emit initial online state and process stream event
      connectivityController.add(true);
      await tester.pump(const Duration(seconds: 1));

      expect(hook.current.dataOrNull?.pages, ['page-0']);
      expect(hook.current.isStale, isTrue);
      expect(fetches, 1);

      // Go offline and go back online - should NOT trigger reconnect since never
      connectivityController.add(false);
      connectivityController.add(true);
      await tester.pumpAndSettle();

      expect(hook.current.fetchStatus, FetchStatus.idle);
      expect(hook.current.dataOrNull?.pages, ['page-0']);
      expect(fetches, 1);

      await tester.pump(const Duration(seconds: 1));

      expect(hook.current.fetchStatus, FetchStatus.idle);
      expect(hook.current.dataOrNull?.pages, ['page-0']);
      expect(fetches, 1);
    }));

    testWidgets(
        'SHOULD refetch fresh data '
        'WHEN refetchOnReconnect == RefetchOnReconnect.always',
        withCleanup((tester) async {
      final connectivityController = StreamController<bool>();
      addTearDown(connectivityController.close);

      final reconnectClient = QueryClient(
        connectivityChanges: connectivityController.stream,
      );
      addTearDown(reconnectClient.clear);

      var fetches = 0;
      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            fetches++;
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          staleDuration: StaleDuration.infinity,
          refetchOnReconnect: RefetchOnReconnect.always,
          client: reconnectClient,
        ),
      );

      // Emit initial online state and process stream event
      connectivityController.add(true);
      await tester.pump(const Duration(seconds: 1));

      expect(hook.current.dataOrNull?.pages, ['page-0']);
      expect(hook.current.isStale, isFalse);
      expect(fetches, 1);

      // Go offline and go back online - should trigger reconnect even when fresh
      connectivityController.add(false);
      connectivityController.add(true);
      await tester.pumpAndSettle();

      expect(hook.current.fetchStatus, FetchStatus.fetching);

      await tester.pump(const Duration(seconds: 1));

      expect(hook.current.fetchStatus, FetchStatus.idle);
      expect(hook.current.dataOrNull?.pages, ['page-0']);
      expect(fetches, 2);
    }));

    testWidgets(
        'SHOULD NOT refetch '
        'WHEN refetchOnReconnect == RefetchOnReconnect.always '
        'AND staleDuration == StaleDuration.static',
        withCleanup((tester) async {
      final connectivityController = StreamController<bool>();
      addTearDown(connectivityController.close);

      final reconnectClient = QueryClient(
        connectivityChanges: connectivityController.stream,
      );
      addTearDown(reconnectClient.clear);

      var fetches = 0;
      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            fetches++;
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          staleDuration: StaleDuration.static,
          refetchOnReconnect: RefetchOnReconnect.always,
          client: reconnectClient,
        ),
      );

      // Emit initial online state and process stream event
      connectivityController.add(true);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(hook.current.dataOrNull?.pages, ['page-0']);
      expect(hook.current.isStale, isFalse);
      expect(fetches, 1);

      // Go offline and go back online - should NOT trigger reconnect since static
      connectivityController.add(false);
      connectivityController.add(true);
      await tester.pumpAndSettle();

      expect(hook.current.fetchStatus, FetchStatus.idle);
      expect(hook.current.dataOrNull?.pages, ['page-0']);
      expect(fetches, 1);

      await tester.pump(const Duration(seconds: 1));

      expect(hook.current.fetchStatus, FetchStatus.idle);
      expect(hook.current.dataOrNull?.pages, ['page-0']);
      expect(fetches, 1);
    }));
  });

  group('Params: refetchInterval', () {
    testWidgets(
        'SHOULD refetch at interval'
        '', withCleanup((tester) async {
      var fetches = 0;

      await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            fetches++;
            return 'page-$fetches';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          refetchInterval: const Duration(seconds: 5),
          client: client,
        ),
      );

      await tester.pump();
      expect(fetches, 1);

      // Wait for first interval
      await tester.pump(const Duration(seconds: 5));
      expect(fetches, 2);

      // Wait for second interval
      await tester.pump(const Duration(seconds: 5));
      expect(fetches, 3);
    }));

    testWidgets(
        'SHOULD stop refetch interval on unmount'
        '', withCleanup((tester) async {
      var fetches = 0;

      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            fetches++;
            return 'page-$fetches';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          refetchInterval: const Duration(seconds: 5),
          client: client,
        ),
      );

      await tester.pump();
      expect(fetches, 1);

      // Unmount
      await hook.unmount();

      // Interval should not fire after unmount
      await tester.pump(const Duration(seconds: 100));
      expect(fetches, 1);
    }));
  });

  group('Params: retry', () {
    testWidgets(
        'SHOULD retry on failure '
        'WHEN retry returns Duration', withCleanup((tester) async {
      var attempts = 0;

      await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            attempts++;
            throw Exception();
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          retry: (retryCount, error) {
            if (retryCount >= 3) return null;
            return const Duration(seconds: 1);
          },
          client: client,
        ),
      );

      // First attempt fails, retry is scheduled
      await tester.pump();
      expect(attempts, 1);

      await tester.pump(const Duration(seconds: 1));
      expect(attempts, 2);
      await tester.pump(const Duration(seconds: 1));
      expect(attempts, 3);
      await tester.pump(const Duration(seconds: 1));
      expect(attempts, 4);
    }));

    testWidgets(
        'SHOULD NOT retry '
        'WHEN retry returns null', withCleanup((tester) async {
      var attempts = 0;

      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            attempts++;
            throw Exception();
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          retry: (_, __) => null,
          client: client,
        ),
      );

      // First attempt fails
      await tester.pump();
      expect(attempts, 1);
      expect(hook.current.isError, isTrue);

      // Wait more - no retries should happen
      await tester.pump(const Duration(seconds: 10));
      expect(attempts, 1);
    }));

    testWidgets(
        'SHOULD NOT retry further '
        'WHEN retry returns null ongoing', withCleanup((tester) async {
      var attempts = 0;

      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
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
          client: client,
        ),
      );

      // First attempt fails
      await tester.pump();
      expect(attempts, 1);

      // First retry
      await tester.pump(const Duration(seconds: 1));
      expect(attempts, 2);

      // Second retry
      await tester.pump(const Duration(seconds: 1));
      expect(attempts, 3);

      // No more retries - wait and verify
      await tester.pump(const Duration(seconds: 10));
      expect(attempts, 3);
      expect(hook.current.isError, isTrue);
    }));
  });

  group('Params: retryOnMount', () {
    testWidgets(
        'SHOULD retry on mount '
        'WHEN retryOnMount == true '
        'AND query is in error state', withCleanup((tester) async {
      var fetches = 0;

      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            throw Exception();
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          retry: (_, __) => null,
          retryOnMount: true,
          client: client,
        ),
      );

      // Wait for first fetch to fail
      await tester.pump(const Duration(seconds: 1));
      expect(hook.current.isError, isTrue);
      expect(fetches, 1);

      // Unmount and remount
      await hook.unmount();
      await hook.rebuild();

      // Should retry - fetches should increment
      await tester.pump(const Duration(seconds: 1));
      expect(fetches, 2);
    }));

    testWidgets(
        'SHOULD NOT retry on mount '
        'WHEN retryOnMount == false '
        'AND query is in error state', withCleanup((tester) async {
      var fetches = 0;

      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
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
          client: client,
        ),
      );

      // Wait for first fetch to fail
      await tester.pump(const Duration(seconds: 1));
      expect(hook.current.isError, isTrue);
      expect(fetches, 1);

      // Unmount and remount
      await hook.unmount();
      await hook.rebuild();

      // Should NOT retry - fetches should stay the same
      await tester.pump(const Duration(seconds: 1));
      expect(fetches, 1);
    }));

    testWidgets(
        'SHOULD fetch on mount '
        'WHEN retryOnMount == false '
        'AND query has no data', withCleanup((tester) async {
      var fetches = 0;

      await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          retryOnMount: false,
          client: client,
        ),
      );

      // Should fetch since there's no existing data (not error state)
      await tester.pump(const Duration(seconds: 1));
      expect(fetches, 1);
    }));
  });

  group('Params: seed', () {
    testWidgets(
        'SHOULD use seed for data'
        '', withCleanup((tester) async {
      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          seed: const Seed.value(InfiniteData(['page-seed'], [0])),
          client: client,
        ),
      );

      expect(
        hook.current.dataOrNull,
        const InfiniteData(['page-seed'], [0]),
      );
      expect(hook.current.dataUpdateCount, 0);
      expect(hook.current.isSuccess, isTrue);
    }));

    testWidgets(
        'SHOULD persist seed to cache'
        '', withCleanup((tester) async {
      await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          seed: const Seed.value(InfiniteData(['page-seed'], [0])),
          client: client,
        ),
      );

      expect(
        client.cache.get(const ['test'])?.state.data,
        const InfiniteData(['page-seed'], [0]),
      );
    }));

    testWidgets(
        'SHOULD take precedence over placeholder'
        '', withCleanup((tester) async {
      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          placeholder: const InfiniteData(['page-ph'], [0]),
          seed: const Seed.value(InfiniteData(['page-seed'], [0])),
          client: client,
        ),
      );

      expect(hook.current.dataOrNull!.pages, ['page-seed']);
      expect(
          (hook.current as InfiniteQuerySuccess<String, Object, int>)
              .isPlaceholder,
          isFalse);
    }));

    testWidgets(
        'SHOULD be replaced by fetched data'
        '', withCleanup((tester) async {
      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          seed: const Seed.value(InfiniteData(['page-seed'], [0])),
          staleDuration: StaleDuration.zero,
          client: client,
        ),
      );

      expect(hook.current.dataOrNull!.pages, ['page-seed']);

      await tester.pump(const Duration(seconds: 1));

      expect(hook.current.dataOrNull!.pages, ['page-0']);
    }));
  });

  group('Params: seedUpdatedAt', () {
    testWidgets(
        'SHOULD use current time '
        'WHEN seedUpdatedAt is not provided', withCleanup((tester) async {
      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          seed: const Seed.value(InfiniteData(['page-seed'], [0])),
          client: client,
        ),
      );

      expect(hook.current.dataUpdatedAt, clock.now());
    }));

    testWidgets(
        'SHOULD make data stale '
        'WHEN seedUpdatedAt is older than staleDuration',
        withCleanup((tester) async {
      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          seed: const Seed.value(InfiniteData(['page-seed'], [0])),
          seedUpdatedAt: SeedUpdatedAt.value(clock.minutesAgo(10)),
          staleDuration: const StaleDuration(minutes: 5),
          client: client,
        ),
      );

      expect(hook.current.isStale, isTrue);
    }));

    testWidgets(
        'SHOULD NOT make data stale '
        'WHEN seedUpdatedAt is within staleDuration',
        withCleanup((tester) async {
      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          seed: const Seed.value(InfiniteData(['page-seed'], [0])),
          seedUpdatedAt: SeedUpdatedAt.value(clock.minutesAgo(2)),
          staleDuration: const StaleDuration(minutes: 5),
          client: client,
        ),
      );

      expect(hook.current.isStale, isFalse);
    }));

    testWidgets(
        'SHOULD extend freshness period '
        'WHEN seedUpdatedAt is set to future DateTime',
        withCleanup((tester) async {
      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          seed: const Seed.value(InfiniteData(['page-seed'], [0])),
          seedUpdatedAt: SeedUpdatedAt.value(clock.minutesFromNow(60)),
          staleDuration: const StaleDuration(minutes: 5),
          client: client,
        ),
      );

      // Data should NOT be stale (seedUpdatedAt is 1 hour in the future)
      expect(hook.current.isStale, isFalse);

      // Even after 30 minutes, data should still be fresh
      await tester.binding.delayed(const Duration(minutes: 30));
      await hook.unmount();
      await hook.rebuild();
      expect(hook.current.isStale, isFalse);

      // After 1 hour + 5 minutes (seedUpdatedAt + staleDuration), data becomes stale
      await tester.binding.delayed(const Duration(minutes: 35));
      await hook.unmount();
      await hook.rebuild();
      expect(hook.current.isStale, isTrue);
    }));
  });

  // group('Params: meta', () {
  //   testWidgets(
  //       'SHOULD deep merge values '
  //       'WHEN provided by multiple hooks', withCleanup((tester) async {
  //     await tester.pumpWidget(Column(children: [
  //       HookBuilder(
  //         key: Key('hook1'),
  //         builder: (context) {
  //           useInfiniteQuery<String, Object, int>(
  //             const ['test'],
  //             (context) async {
  //               await Future.delayed(const Duration(seconds: 1));
  //               return 'page-${context.pageParam}';
  //             },
  //             initialPageParam: 0,
  //             nextPageParamBuilder: (data) => data.pageParams.last + 1,
  //             meta: {
  //               'source': 'hook1',
  //               'nested': {'a': 1, 'b': 2},
  //             },
  //             client: client,
  //           );
  //           return Container();
  //         },
  //       ),
  //       HookBuilder(
  //         key: Key('hook2'),
  //         builder: (context) {
  //           useInfiniteQuery<String, Object, int>(
  //             const ['test'],
  //             (context) async {
  //               await Future.delayed(const Duration(seconds: 1));
  //               return 'page-${context.pageParam}';
  //             },
  //             initialPageParam: 0,
  //             nextPageParamBuilder: (data) => data.pageParams.last + 1,
  //             meta: {
  //               'extra': 'value',
  //               'nested': {'c': 3},
  //             },
  //             client: client,
  //           );
  //           return Container();
  //         },
  //       ),
  //     ]));

  //     final query = client.cache.get(const ['test'])!;
  //     expect(query.meta, {
  //       'source': 'hook1',
  //       'extra': 'value',
  //       'nested': {'a': 1, 'b': 2, 'c': 3},
  //     });
  //   }));
  // });

  group('Returns: fetchNextPage', () {
    testWidgets(
        'SHOULD succeed fetching next page'
        '', withCleanup((tester) async {
      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          client: client,
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      await act(hook.current.fetchNextPage);

      expect(hook.current.fetchStatus, FetchStatus.fetching);
      expect(hook.current.dataOrNull, InfiniteData(['page-0'], [0]));

      await tester.pump(const Duration(seconds: 1));

      expect(hook.current.isSuccess, isTrue);
      expect(hook.current.fetchStatus, FetchStatus.idle);
      expect(
          hook.current.dataOrNull, InfiniteData(['page-0', 'page-1'], [0, 1]));
    }));

    testWidgets(
        'SHOULD fail fetching next page'
        '', withCleanup((tester) async {
      final expectedError = Exception();

      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
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
          client: client,
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      await act(hook.current.fetchNextPage);

      expect(hook.current.fetchStatus, FetchStatus.fetching);
      expect(hook.current.isError, isFalse);

      await tester.pump(const Duration(seconds: 1));

      expect(hook.current.isError, isTrue);
      expect(hook.current.fetchStatus, FetchStatus.idle);
      expect((hook.current as InfiniteQueryError<String, Object, int>).error,
          same(expectedError));
    }));

    testWidgets(
        'SHOULD NOT fetch more pages '
        'WHEN hasNextPage is false', withCleanup((tester) async {
      var fetches = 0;

      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => null,
          client: client,
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      expect(fetches, 1);
      expect(hook.current.hasNextPage, isFalse);

      // Try to fetch next page
      await act(hook.current.fetchNextPage);

      await tester.pump(const Duration(seconds: 1));

      // Should NOT have fetched again
      expect(fetches, 1);
    }));

    testWidgets(
        'SHOULD respect maxPages limit'
        '', withCleanup((tester) async {
      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          maxPages: 2,
          client: client,
        ),
      );

      await tester.pump(const Duration(seconds: 1));
      expect(hook.current.dataOrNull, InfiniteData(['page-0'], [0]));

      await act(hook.current.fetchNextPage);
      await tester.pump(const Duration(seconds: 1));
      expect(
          hook.current.dataOrNull, InfiniteData(['page-0', 'page-1'], [0, 1]));

      await act(hook.current.fetchNextPage);
      await tester.pump(const Duration(seconds: 1));
      expect(
          hook.current.dataOrNull, InfiniteData(['page-1', 'page-2'], [1, 2]));
    }));

    testWidgets(
        'SHOULD cancel in-progress fetch and start new one '
        'WHEN cancelRefetch == true', withCleanup((tester) async {
      var fetches = 0;
      final fetchNextPageResults =
          <InfiniteQuerySnapshot<String, Object, int>>[];

      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'page-${context.pageParam}-fetch-$fetches';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          client: client,
        ),
      );

      // Wait for initial fetch to complete
      await tester.pump(const Duration(seconds: 1));
      expect(hook.current.pages, ['page-0-fetch-1']);

      // Call fetchNextPage multiple times rapidly (before previous completes)
      hook.current
          .fetchNextPage()
          .then((result) => fetchNextPageResults.add(result));
      hook.current
          .fetchNextPage(cancelRefetch: true)
          .then((result) => fetchNextPageResults.add(result));
      hook.current
          .fetchNextPage(cancelRefetch: true)
          .then((result) => fetchNextPageResults.add(result));

      // Should have started multiple fetches (cancelling previous ones)
      // but only the last one completes
      await tester.pump(const Duration(seconds: 1));
      expect(hook.current.pages, ['page-0-fetch-1', 'page-1-fetch-4']);
      expect(fetchNextPageResults, hasLength(3));
      expect(
        fetchNextPageResults.map((result) => result.pages),
        everyElement(['page-0-fetch-1', 'page-1-fetch-4']),
      );
    }));

    testWidgets(
        'SHOULD return existing promise '
        'WHEN cancelRefetch == false ', withCleanup((tester) async {
      var fetches = 0;
      final fetchNextPageResults =
          <InfiniteQuerySnapshot<String, Object, int>>[];

      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            fetches++;
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}-fetch-$fetches';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          client: client,
        ),
      );

      // Wait for initial fetch to complete
      await tester.pump(const Duration(seconds: 1));
      expect(hook.current.pages, ['page-0-fetch-1']);

      // Call fetchNextPage with cancelRefetch: false multiple times
      hook.current
          .fetchNextPage()
          .then((result) => fetchNextPageResults.add(result));
      hook.current
          .fetchNextPage(cancelRefetch: false)
          .then((result) => fetchNextPageResults.add(result));
      hook.current
          .fetchNextPage(cancelRefetch: false)
          .then((result) => fetchNextPageResults.add(result));

      await tester.pump(const Duration(seconds: 1));

      // Should have fetched only once (deduplication)
      expect(hook.current.pages, ['page-0-fetch-1', 'page-1-fetch-2']);
      expect(fetchNextPageResults, hasLength(3));
      expect(
        fetchNextPageResults.map((result) => result.pages),
        everyElement(['page-0-fetch-1', 'page-1-fetch-2']),
      );
    }));

    testWidgets(
        'SHOULD dedupe multiple calls on initial mount'
        '', withCleanup((tester) async {
      var fetches = 0;

      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            fetches++;
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}-fetch-$fetches';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          client: client,
        ),
      );

      // Initial fetch is in progress (no data yet)
      expect(hook.current.dataOrNull, isNull);
      expect(hook.current.isFetching, isTrue);

      // Try to fetch next page while initial fetch is in progress
      // This should be deduplicated since there's no data yet
      hook.current.fetchNextPage();
      hook.current.fetchNextPage();

      // Wait for initial fetch to complete
      await tester.pump(const Duration(seconds: 1));

      // Should only have one fetch (deduplication because no data existed)
      expect(fetches, 1);
      expect(hook.current.pages, ['page-0-fetch-1']);
    }));
  });

  group('Returns: fetchPreviousPage', () {
    testWidgets(
        'SHOULD succeed fetching previous page'
        '', withCleanup((tester) async {
      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 5,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          prevPageParamBuilder: (data) => data.pageParams.first - 1,
          client: client,
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      await act(hook.current.fetchPreviousPage);

      expect(hook.current.fetchStatus, FetchStatus.fetching);
      expect(hook.current.dataOrNull, InfiniteData(['page-5'], [5]));

      await tester.pump(const Duration(seconds: 1));

      expect(hook.current.isSuccess, isTrue);
      expect(hook.current.fetchStatus, FetchStatus.idle);
      expect(
          hook.current.dataOrNull, InfiniteData(['page-4', 'page-5'], [4, 5]));
    }));

    testWidgets(
        'SHOULD fail fetching previous page'
        '', withCleanup((tester) async {
      final expectedError = Exception();

      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
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
          client: client,
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      await act(hook.current.fetchPreviousPage);

      expect(hook.current.fetchStatus, FetchStatus.fetching);
      expect(hook.current.isError, isFalse);

      await tester.pump(const Duration(seconds: 1));

      expect(hook.current.isError, isTrue);
      expect(hook.current.fetchStatus, FetchStatus.idle);
      expect((hook.current as InfiniteQueryError<String, Object, int>).error,
          same(expectedError));
    }));

    testWidgets(
        'SHOULD NOT fetch more pages '
        'WHEN hasPreviousPage is false', withCleanup((tester) async {
      var fetches = 0;

      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          prevPageParamBuilder: (data) => null,
          client: client,
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      expect(fetches, 1);
      expect(hook.current.hasPreviousPage, isFalse);

      await act(hook.current.fetchPreviousPage);

      await tester.pump(const Duration(seconds: 1));

      expect(fetches, 1);
    }));

    testWidgets(
        'SHOULD respect maxPages limit'
        '', withCleanup((tester) async {
      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 5,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          prevPageParamBuilder: (data) => data.pageParams.first - 1,
          maxPages: 2,
          client: client,
        ),
      );

      await tester.pump(const Duration(seconds: 1));
      expect(hook.current.dataOrNull, InfiniteData(['page-5'], [5]));

      await act(hook.current.fetchPreviousPage);
      await tester.pump(const Duration(seconds: 1));
      expect(
          hook.current.dataOrNull, InfiniteData(['page-4', 'page-5'], [4, 5]));

      await act(hook.current.fetchPreviousPage);
      await tester.pump(const Duration(seconds: 1));
      expect(
          hook.current.dataOrNull, InfiniteData(['page-3', 'page-4'], [3, 4]));
    }));

    testWidgets(
        'SHOULD cancel in-progress fetch and start new one '
        'WHEN cancelRefetch == true', withCleanup((tester) async {
      var fetches = 0;
      final fetchPreviousPageResults =
          <InfiniteQuerySnapshot<String, Object, int>>[];

      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'page-${context.pageParam}-fetch-$fetches';
          },
          initialPageParam: 5,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          prevPageParamBuilder: (data) => data.pageParams.first - 1,
          client: client,
        ),
      );

      // Wait for initial fetch to complete
      await tester.pump(const Duration(seconds: 1));
      expect(hook.current.pages, ['page-5-fetch-1']);

      // Call fetchNextPage multiple times rapidly (before previous completes)
      hook.current
          .fetchPreviousPage()
          .then((result) => fetchPreviousPageResults.add(result));
      hook.current
          .fetchPreviousPage(cancelRefetch: true)
          .then((result) => fetchPreviousPageResults.add(result));
      hook.current
          .fetchPreviousPage(cancelRefetch: true)
          .then((result) => fetchPreviousPageResults.add(result));

      // Should have started multiple fetches (cancelling previous ones)
      // but only the last one completes
      await tester.pump(const Duration(seconds: 1));
      expect(hook.current.pages, ['page-4-fetch-4', 'page-5-fetch-1']);
      expect(fetchPreviousPageResults, hasLength(3));
      expect(
        fetchPreviousPageResults.map((result) => result.pages),
        everyElement(['page-4-fetch-4', 'page-5-fetch-1']),
      );
    }));

    testWidgets(
        'SHOULD return existing promise '
        'WHEN cancelRefetch == false ', withCleanup((tester) async {
      var fetches = 0;
      final fetchPreviousPageResults =
          <InfiniteQuerySnapshot<String, Object, int>>[];

      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            fetches++;
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}-fetch-$fetches';
          },
          initialPageParam: 5,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          prevPageParamBuilder: (data) => data.pageParams.first - 1,
          client: client,
        ),
      );

      // Wait for initial fetch to complete
      await tester.pump(const Duration(seconds: 1));
      expect(hook.current.pages, ['page-5-fetch-1']);

      // Call fetchNextPage with cancelRefetch: false multiple times
      hook.current
          .fetchPreviousPage()
          .then((result) => fetchPreviousPageResults.add(result));
      hook.current
          .fetchPreviousPage(cancelRefetch: false)
          .then((result) => fetchPreviousPageResults.add(result));
      hook.current
          .fetchPreviousPage(cancelRefetch: false)
          .then((result) => fetchPreviousPageResults.add(result));

      await tester.pump(const Duration(seconds: 1));

      // Should have fetched only once (deduplication)
      expect(hook.current.pages, ['page-4-fetch-2', 'page-5-fetch-1']);
      expect(fetchPreviousPageResults, hasLength(3));
      expect(
        fetchPreviousPageResults.map((result) => result.pages),
        everyElement(['page-4-fetch-2', 'page-5-fetch-1']),
      );
    }));

    testWidgets(
        'SHOULD dedupe multiple calls on initial mount'
        '', withCleanup((tester) async {
      var fetches = 0;

      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            fetches++;
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}-fetch-$fetches';
          },
          initialPageParam: 5,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          prevPageParamBuilder: (data) => data.pageParams.first - 1,
          client: client,
        ),
      );

      // Initial fetch is in progress (no data yet)
      expect(hook.current.dataOrNull, isNull);
      expect(hook.current.isFetching, isTrue);

      // Try to fetch next page while initial fetch is in progress
      // This should be deduplicated since there's no data yet
      hook.current.fetchPreviousPage();
      hook.current.fetchPreviousPage();

      // Wait for initial fetch to complete
      await tester.pump(const Duration(seconds: 1));

      // Should only have one fetch (deduplication because no data existed)
      expect(fetches, 1);
      expect(hook.current.pages, ['page-5-fetch-1']);
    }));
  });

  group('Returns: hasNextPage', () {
    testWidgets(
        'SHOULD return false '
        'WHEN data is null', withCleanup((tester) async {
      // Case 1: Before fetch completes
      final hook1 = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test1'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          client: client,
        ),
      );

      expect(hook1.current.dataOrNull, isNull);
      expect(hook1.current.hasNextPage, isFalse);

      // Case 2: After initial fetch failed
      final hook2 = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test2'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            throw Exception();
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          client: client,
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      expect(hook2.current.dataOrNull, isNull);
      expect(hook2.current.hasNextPage, isFalse);
    }));

    testWidgets(
        'SHOULD return false '
        'WHEN nextPageParamBuilder returns null', withCleanup((tester) async {
      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (_) => null,
          client: client,
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      expect(hook.current.dataOrNull, isNotNull);
      expect(hook.current.hasNextPage, isFalse);
    }));

    testWidgets(
        'SHOULD return true '
        'WHEN nextPageParamBuilder returns non-null',
        withCleanup((tester) async {
      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          client: client,
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      expect(hook.current.dataOrNull, isNotNull);
      expect(hook.current.hasNextPage, isTrue);
    }));
  });

  group('Returns: hasPreviousPage', () {
    testWidgets(
        'SHOULD return false '
        'WHEN data is null', withCleanup((tester) async {
      // Case 1: Before fetch completes
      final hook1 = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test1'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 5,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          prevPageParamBuilder: (data) => data.pageParams.first - 1,
          client: client,
        ),
      );

      expect(hook1.current.dataOrNull, isNull);
      expect(hook1.current.hasPreviousPage, isFalse);

      // Case 2: After initial fetch failed
      final hook2 = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test2'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            throw Exception();
          },
          initialPageParam: 5,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          prevPageParamBuilder: (data) => data.pageParams.first - 1,
          client: client,
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      expect(hook2.current.dataOrNull, isNull);
      expect(hook2.current.hasPreviousPage, isFalse);
    }));

    testWidgets(
        'SHOULD return false '
        'WHEN prevPageParamBuilder is not provided',
        withCleanup((tester) async {
      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 5,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          // prevPageParamBuilder not provided
          client: client,
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      expect(hook.current.dataOrNull, isNotNull);
      expect(hook.current.hasPreviousPage, isFalse);
    }));

    testWidgets(
        'SHOULD return false '
        'WHEN prevPageParamBuilder returns null', withCleanup((tester) async {
      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          prevPageParamBuilder: (_) => null,
          client: client,
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      expect(hook.current.dataOrNull, isNotNull);
      expect(hook.current.hasPreviousPage, isFalse);
    }));

    testWidgets(
        'SHOULD return true '
        'WHEN prevPageParamBuilder returns non-null',
        withCleanup((tester) async {
      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 5,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          prevPageParamBuilder: (data) => data.pageParams.first - 1,
          client: client,
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      expect(hook.current.dataOrNull, isNotNull);
      expect(hook.current.hasPreviousPage, isTrue);
    }));
  });

  group('Returns: isFetchingNextPage', () {
    testWidgets(
        'SHOULD return false '
        'WHEN not fetching', withCleanup((tester) async {
      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          client: client,
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      expect(hook.current.isFetchingNextPage, isFalse);
    }));

    testWidgets(
        'SHOULD return false '
        'WHEN fetching initial page', withCleanup((tester) async {
      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          client: client,
        ),
      );

      expect(hook.current.isFetchingNextPage, isFalse);
    }));

    testWidgets(
        'SHOULD return true '
        'WHEN fetchNextPage is in progress', withCleanup((tester) async {
      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          client: client,
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      await act(hook.current.fetchNextPage);

      expect(hook.current.isFetchingNextPage, isTrue);
    }));

    testWidgets(
        'SHOULD return false '
        'WHEN fetchPreviousPage is in progress', withCleanup((tester) async {
      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 5,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          prevPageParamBuilder: (data) => data.pageParams.first - 1,
          client: client,
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      await act(hook.current.fetchPreviousPage);

      expect(hook.current.isFetchingNextPage, isFalse);
    }));

    testWidgets(
        'SHOULD return false '
        'WHEN refetch is in progress', withCleanup((tester) async {
      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          client: client,
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      await act(hook.current.refetch);

      expect(hook.current.isFetchingNextPage, isFalse);
    }));
  });

  group('Returns: isFetchingPreviousPage', () {
    testWidgets(
        'SHOULD return false '
        'WHEN not fetching', withCleanup((tester) async {
      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 5,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          prevPageParamBuilder: (data) => data.pageParams.first - 1,
          client: client,
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      expect(hook.current.isFetchingPreviousPage, isFalse);
    }));

    testWidgets(
        'SHOULD return false '
        'WHEN fetching initial page', withCleanup((tester) async {
      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 5,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          prevPageParamBuilder: (data) => data.pageParams.first - 1,
          client: client,
        ),
      );

      expect(hook.current.isFetchingPreviousPage, isFalse);
    }));

    testWidgets(
        'SHOULD return false '
        'WHEN fetchNextPage is in progress', withCleanup((tester) async {
      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 5,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          prevPageParamBuilder: (data) => data.pageParams.first - 1,
          client: client,
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      await act(hook.current.fetchNextPage);

      expect(hook.current.isFetchingPreviousPage, isFalse);
    }));

    testWidgets(
        'SHOULD return true '
        'WHEN fetchPreviousPage is in progress', withCleanup((tester) async {
      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 5,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          prevPageParamBuilder: (data) => data.pageParams.first - 1,
          client: client,
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      await act(hook.current.fetchPreviousPage);

      expect(hook.current.isFetchingPreviousPage, isTrue);
    }));

    testWidgets(
        'SHOULD return false '
        'WHEN refetch is in progress', withCleanup((tester) async {
      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 5,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          prevPageParamBuilder: (data) => data.pageParams.first - 1,
          client: client,
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      await act(hook.current.refetch);

      expect(hook.current.isFetchingPreviousPage, isFalse);
    }));
  });

  group('Returns: refetch', () {
    testWidgets(
        'SHOULD refetch all existing pages sequentially'
        '', withCleanup((tester) async {
      var fetches = 0;

      final hook = await buildHook(
        () => useInfiniteQuery<String, Object, int>(
          const ['test'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            fetches++;
            return 'page-${context.pageParam}:fetches-$fetches';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          client: client,
        ),
      );

      await tester.pump(const Duration(seconds: 1));
      expect(fetches, 1);

      await act(hook.current.fetchNextPage);
      await tester.pump(const Duration(seconds: 1));
      expect(fetches, 2);
      expect(
        hook.current.dataOrNull,
        InfiniteData(['page-0:fetches-1', 'page-1:fetches-2'], [0, 1]),
      );

      // Refetch all pages
      await act(hook.current.refetch);
      await tester.pump(const Duration(seconds: 1));

      // First page refetched, still fetching second page
      expect(fetches, 3);
      expect(hook.current.isFetching, isTrue);

      await tester.pump(const Duration(seconds: 1));

      // All pages refetched
      expect(fetches, 4);
      expect(hook.current.isFetching, isFalse);
      expect(
        hook.current.dataOrNull,
        InfiniteData(['page-0:fetches-3', 'page-1:fetches-4'], [0, 1]),
      );
    }));
  });

  group('Parameter: networkMode', () {
    late StreamController<bool> connectivityController;

    setUp(() {
      connectivityController = StreamController<bool>();
      client = QueryClient(
        connectivityChanges: connectivityController.stream,
      );
    });

    tearDown(() {
      client.clear();
      connectivityController.close();
    });

    group('== NetworkMode.online', () {
      // Pauses when offline, resumes when online

      testWidgets(
          'SHOULD fetch normally online'
          '', withCleanup((tester) async {
        // Start online
        connectivityController.add(true);

        final hook = await buildHook(
          () => useInfiniteQuery<String, Object, int>(
            const ['key'],
            (_) async {
              await Future.delayed(const Duration(seconds: 1));
              return 'page-0';
            },
            initialPageParam: 0,
            nextPageParamBuilder: (data) => data.pageParams.last + 1,
            networkMode: NetworkMode.online,
            client: client,
          ),
        );

        expect(hook.current.fetchStatus, FetchStatus.fetching);
        expect(hook.current.isPaused, isFalse);

        await tester.pump(const Duration(seconds: 1));
        expect(hook.current.isSuccess, isTrue);
        expect(hook.current.dataOrNull?.pages, ['page-0']);
      }));

      testWidgets(
          'SHOULD pause offline, then resume on going online'
          '', withCleanup((tester) async {
        // Start offline
        connectivityController.add(false);

        final hook = await buildHook(
          () => useInfiniteQuery<String, Object, int>(
            const ['key'],
            (_) async {
              await Future.delayed(const Duration(seconds: 1));
              return 'page-0';
            },
            initialPageParam: 0,
            nextPageParamBuilder: (data) => data.pageParams.last + 1,
            networkMode: NetworkMode.online,
            client: client,
          ),
        );

        expect(hook.current.fetchStatus, FetchStatus.paused);
        expect(hook.current.isPaused, isTrue);

        // Should be kept paused
        await tester.pump(const Duration(days: 365));
        expect(hook.current.fetchStatus, FetchStatus.paused);
        expect(hook.current.isPaused, isTrue);

        // Go online
        connectivityController.add(true);
        await tester.pump();
        await tester.pump();
        expect(hook.current.fetchStatus, FetchStatus.fetching);
        expect(hook.current.isPaused, isFalse);

        await tester.pump(const Duration(seconds: 1));
        expect(hook.current.isSuccess, isTrue);
        expect(hook.current.dataOrNull?.pages, ['page-0']);
      }));

      testWidgets(
          'SHOULD pause retries on going offline, then resume on going online'
          '', withCleanup((tester) async {
        // Start online
        connectivityController.add(true);

        var queryFnCount = 0;
        final hook = await buildHook(
          () => useInfiniteQuery<String, Object, int>(
            const ['key'],
            (_) async {
              queryFnCount++;
              throw Exception();
            },
            initialPageParam: 0,
            nextPageParamBuilder: (data) => data.pageParams.last + 1,
            networkMode: NetworkMode.online,
            retry: (retryCount, _) {
              if (retryCount < 3) {
                return const Duration(seconds: 1);
              }
              return null;
            },
            client: client,
          ),
        );

        expect(hook.current.isPaused, isFalse);
        expect(queryFnCount, 1);

        // Go offline
        connectivityController.add(false);
        await tester.pump();
        await tester.pump();
        expect(hook.current.isPaused, isTrue);
        expect(queryFnCount, 1);

        // Go online
        connectivityController.add(true);
        await tester.pump();
        await tester.pump();
        expect(hook.current.isPaused, isFalse);
        expect(queryFnCount, 2);

        // Wait for remaining retries to complete
        await tester.pump(const Duration(seconds: 1));
        expect(queryFnCount, 3);
        await tester.pump(const Duration(seconds: 1));
        expect(queryFnCount, 4);
        expect(hook.current.isError, isTrue);
      }));
    });

    group('== NetworkMode.always', () {
      // Never pauses, ignores network state

      testWidgets(
          'SHOULD fetch normally online'
          '', withCleanup((tester) async {
        // Start online
        connectivityController.add(true);

        final hook = await buildHook(
          () => useInfiniteQuery<String, Object, int>(
            const ['key'],
            (_) async {
              await Future.delayed(const Duration(seconds: 1));
              return 'page-0';
            },
            initialPageParam: 0,
            nextPageParamBuilder: (data) => data.pageParams.last + 1,
            networkMode: NetworkMode.always,
            client: client,
          ),
        );

        expect(hook.current.fetchStatus, FetchStatus.fetching);
        expect(hook.current.isPaused, isFalse);

        await tester.pump(const Duration(seconds: 1));
        expect(hook.current.isSuccess, isTrue);
        expect(hook.current.dataOrNull?.pages, ['page-0']);
      }));

      testWidgets(
          'SHOULD fetch normally offline'
          '', withCleanup((tester) async {
        // Start offline
        connectivityController.add(false);

        final hook = await buildHook(
          () => useInfiniteQuery<String, Object, int>(
            const ['key'],
            (_) async {
              await Future.delayed(const Duration(seconds: 1));
              return 'page-0';
            },
            initialPageParam: 0,
            nextPageParamBuilder: (data) => data.pageParams.last + 1,
            networkMode: NetworkMode.always,
            client: client,
          ),
        );

        expect(hook.current.fetchStatus, FetchStatus.fetching);
        expect(hook.current.isPaused, isFalse);

        await tester.pump(const Duration(seconds: 1));
        expect(hook.current.isSuccess, isTrue);
        expect(hook.current.dataOrNull?.pages, ['page-0']);
      }));

      testWidgets(
          'SHOULD NOT pause on going offline'
          '', withCleanup((tester) async {
        // Start online
        connectivityController.add(true);

        final hook = await buildHook(
          () => useInfiniteQuery<String, Object, int>(
            const ['key'],
            (_) async {
              await Future.delayed(const Duration(seconds: 1));
              return 'page-0';
            },
            initialPageParam: 0,
            nextPageParamBuilder: (data) => data.pageParams.last + 1,
            networkMode: NetworkMode.always,
            client: client,
          ),
        );

        expect(hook.current.fetchStatus, FetchStatus.fetching);
        expect(hook.current.isPaused, isFalse);

        // Go offline
        connectivityController.add(false);
        await tester.pump();
        await tester.pump();
        expect(hook.current.fetchStatus, FetchStatus.fetching);
        expect(hook.current.isPaused, isFalse);

        await tester.pump(const Duration(seconds: 1));
        expect(hook.current.isSuccess, isTrue);
        expect(hook.current.dataOrNull?.pages, ['page-0']);
      }));

      testWidgets(
          'SHOULD NOT pause retries on going offline'
          '', withCleanup((tester) async {
        // Start online
        connectivityController.add(true);

        var queryFnCount = 0;
        final hook = await buildHook(
          () => useInfiniteQuery<String, Object, int>(
            const ['key'],
            (_) async {
              queryFnCount++;
              throw Exception();
            },
            initialPageParam: 0,
            nextPageParamBuilder: (data) => data.pageParams.last + 1,
            networkMode: NetworkMode.always,
            retry: (retryCount, _) {
              if (retryCount < 3) {
                return const Duration(seconds: 1);
              }
              return null;
            },
            client: client,
          ),
        );

        expect(hook.current.isPaused, isFalse);
        expect(queryFnCount, 1);

        // Go offline
        connectivityController.add(false);
        await tester.pump();
        await tester.pump();
        expect(hook.current.isPaused, isFalse);
        expect(queryFnCount, 1);

        // Should continue retrying
        await tester.pump(const Duration(seconds: 1));
        expect(queryFnCount, 2);
        await tester.pump(const Duration(seconds: 1));
        expect(queryFnCount, 3);
        await tester.pump(const Duration(seconds: 1));
        expect(queryFnCount, 4);
        expect(hook.current.isError, isTrue);
      }));
    });

    group('== NetworkMode.offlineFirst', () {
      // Always runs first execution, pauses retries offline

      testWidgets(
          'SHOULD execute initial fetch normally online'
          '', withCleanup((tester) async {
        // Start online
        connectivityController.add(true);

        final hook = await buildHook(
          () => useInfiniteQuery<String, Object, int>(
            const ['key'],
            (_) async {
              await Future.delayed(const Duration(seconds: 1));
              return 'page-0';
            },
            initialPageParam: 0,
            nextPageParamBuilder: (data) => data.pageParams.last + 1,
            networkMode: NetworkMode.offlineFirst,
            client: client,
          ),
        );

        expect(hook.current.fetchStatus, FetchStatus.fetching);
        expect(hook.current.isPaused, isFalse);

        await tester.pump(const Duration(seconds: 1));
        expect(hook.current.isSuccess, isTrue);
        expect(hook.current.dataOrNull?.pages, ['page-0']);
      }));

      testWidgets(
          'SHOULD execute initial fetch normally offline'
          '', withCleanup((tester) async {
        // Start offline
        connectivityController.add(false);

        final hook = await buildHook(
          () => useInfiniteQuery<String, Object, int>(
            const ['key'],
            (_) async {
              await Future.delayed(const Duration(seconds: 1));
              return 'page-0';
            },
            initialPageParam: 0,
            nextPageParamBuilder: (data) => data.pageParams.last + 1,
            networkMode: NetworkMode.offlineFirst,
            client: client,
          ),
        );

        expect(hook.current.fetchStatus, FetchStatus.fetching);
        expect(hook.current.isPaused, isFalse);

        await tester.pump(const Duration(seconds: 1));
        expect(hook.current.isSuccess, isTrue);
        expect(hook.current.dataOrNull?.pages, ['page-0']);
      }));

      testWidgets(
          'SHOULD pause retries offline, then resume on going online'
          '', withCleanup((tester) async {
        // Start offline
        connectivityController.add(false);

        var queryFnCount = 0;
        final hook = await buildHook(
          () => useInfiniteQuery<String, Object, int>(
            const ['key'],
            (_) async {
              queryFnCount++;
              throw Exception();
            },
            initialPageParam: 0,
            nextPageParamBuilder: (data) => data.pageParams.last + 1,
            networkMode: NetworkMode.offlineFirst,
            retry: (retryCount, _) {
              if (retryCount < 3) {
                return const Duration(seconds: 1);
              }
              return null;
            },
            client: client,
          ),
        );

        await tester.pump();
        expect(hook.current.isPaused, isTrue);
        expect(hook.current.failureCount, 1);
        expect(queryFnCount, 1);

        // Should NOT retry when paused
        await tester.pump(const Duration(days: 365));
        expect(hook.current.isPaused, isTrue);
        expect(queryFnCount, 1);

        // Go online
        connectivityController.add(true);
        await tester.pump();
        await tester.pump();
        expect(hook.current.isPaused, isFalse);
        expect(queryFnCount, 2);

        // Should continue retrying
        await tester.pump(const Duration(seconds: 1));
        expect(queryFnCount, 3);
        await tester.pump(const Duration(seconds: 1));
        expect(queryFnCount, 4);
        expect(hook.current.isError, isTrue);
      }));
    });
  });

  group('Shared key', () {
    // Regression test for https://github.com/jezsung/query/issues/40
    testWidgets(
        'SHOULD NOT throw markNeedsBuild error '
        'WHEN navigating to screen that shares the same query key',
        withCleanup((tester) async {
      late InfiniteQuerySnapshot<String, Object, int> screenAResult;

      await tester.pumpWidget(
        Column(
          children: [
            HookBuilder(
              key: const Key('screen-a'),
              builder: (context) {
                screenAResult = useInfiniteQuery<String, Object, int>(
                  ['branch', 'id-1'],
                  (context) async {
                    await Future.delayed(const Duration(seconds: 1));
                    return 'data-a-${context.pageParam}';
                  },
                  initialPageParam: 0,
                  nextPageParamBuilder: (data) => data.pageParams.last + 1,
                  client: client,
                );
                return Container();
              },
            ),
          ],
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(screenAResult.isSuccess, isTrue);
      expect(screenAResult.dataOrNull?.pages, ['data-a-0']);

      late InfiniteQuerySnapshot<String, Object, int> screenBResult;

      // Add Screen B while keeping Screen A alive via Key.
      // Without the fix, Screen B's onMount triggers _fetch() which
      // notifies Screen A's observer, calling markNeedsBuild() during
      // Screen B's build phase.
      await tester.pumpWidget(
        Column(
          children: [
            HookBuilder(
              key: const Key('screen-a'),
              builder: (context) {
                screenAResult = useInfiniteQuery<String, Object, int>(
                  ['branch', 'id-1'],
                  (context) async {
                    await Future.delayed(const Duration(seconds: 1));
                    return 'data-a-${context.pageParam}';
                  },
                  initialPageParam: 0,
                  nextPageParamBuilder: (data) => data.pageParams.last + 1,
                  client: client,
                );
                return Container();
              },
            ),
            HookBuilder(
              key: const Key('screen-b'),
              builder: (context) {
                screenBResult = useInfiniteQuery<String, Object, int>(
                  ['branch', 'id-1'],
                  (context) async {
                    await Future.delayed(const Duration(seconds: 1));
                    return 'data-b-${context.pageParam}';
                  },
                  initialPageParam: 0,
                  nextPageParamBuilder: (data) => data.pageParams.last + 1,
                  client: client,
                );
                return Container();
              },
            ),
          ],
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(screenAResult.isSuccess, isTrue);
      expect(screenBResult.isSuccess, isTrue);
    }));

    // Regression test for the disposed-notifier race: a widget subscribed to a
    // shared key can be removed in the same frame a sibling advances the query
    // during build. The build-phase notification schedules a post-frame write,
    // but the widget unmounts before the frame fires, disposing its result
    // notifier — so the deferred write must bail instead of throwing
    // "used after being disposed".
    testWidgets(
        'SHOULD NOT write to a disposed result '
        'WHEN a subscribed widget is removed in the same frame a shared-key '
        'sibling mounts', withCleanup((tester) async {
      // Frame 0: Screen A subscribes and settles with data.
      await tester.pumpWidget(HookBuilder(
        key: const Key('screen-a'),
        builder: (context) {
          useInfiniteQuery<String, Object, int>(
            ['branch', 'id-1'],
            (context) async {
              await Future.delayed(const Duration(seconds: 1));
              return 'data-a-${context.pageParam}';
            },
            initialPageParam: 0,
            nextPageParamBuilder: (data) => data.pageParams.last + 1,
            client: client,
          );
          return const SizedBox();
        },
      ));
      await tester.pump(const Duration(seconds: 1));

      // Frame 1: swap Screen A out for Screen B (same key). B's onMount
      // triggers _fetch(), which notifies A's still-attached observer during
      // B's build phase and schedules a post-frame write. A unmounts this same
      // frame, disposing its result notifier.
      await tester.pumpWidget(HookBuilder(
        key: const Key('screen-b'),
        builder: (context) {
          useInfiniteQuery<String, Object, int>(
            ['branch', 'id-1'],
            (context) async {
              await Future.delayed(const Duration(seconds: 1));
              return 'data-b-${context.pageParam}';
            },
            initialPageParam: 0,
            nextPageParamBuilder: (data) => data.pageParams.last + 1,
            client: client,
          );
          return const SizedBox();
        },
      ));
      // Flush the scheduled post-frame callback; it must not throw.
      await tester.pump();

      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(seconds: 1));
    }));
  });

  group('Params: shouldRebuild', () {
    testWidgets('SHOULD rebuild on success WHEN shouldRebuild is null',
        withCleanup((tester) async {
      var builds = 0;

      await buildHook(() {
        builds++;
        return useInfiniteQuery<String, Object, int>(
          const ['feed'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          client: client,
        );
      });

      expect(builds, 1);

      await tester.pump(const Duration(seconds: 1));

      // Pending -> success rebuilds by default.
      expect(builds, 2);
    }));

    testWidgets('SHOULD NOT rebuild WHEN shouldRebuild returns false',
        withCleanup((tester) async {
      var builds = 0;

      final hookResult = await buildHook(() {
        builds++;
        return useInfiniteQuery<String, Object, int>(
          const ['feed'],
          (context) async {
            await Future.delayed(const Duration(seconds: 1));
            return 'page-${context.pageParam}';
          },
          initialPageParam: 0,
          nextPageParamBuilder: (data) => data.pageParams.last + 1,
          shouldRebuild: (previous, next) => false,
          client: client,
        );
      });

      expect(builds, 1);
      expect(hookResult.current.isPending, isTrue);

      await tester.pump(const Duration(seconds: 1));

      // Success arrived but the predicate suppressed the rebuild.
      expect(builds, 1);
      expect(hookResult.current.isPending, isTrue);
    }));

    testWidgets(
        'SHOULD gate each hook independently '
        'WHEN two hooks share a key with different shouldRebuild',
        withCleanup((tester) async {
      var buildsA = 0;
      var buildsB = 0;
      late InfiniteQuerySnapshot<String, Object, int> resultA;
      late InfiniteQuerySnapshot<String, Object, int> resultB;

      await tester.pumpWidget(Column(children: [
        HookBuilder(builder: (context) {
          buildsA++;
          resultA = useInfiniteQuery<String, Object, int>(
            const ['feed'],
            (context) async {
              await Future.delayed(const Duration(seconds: 1));
              return 'page-${context.pageParam}';
            },
            initialPageParam: 0,
            nextPageParamBuilder: (data) => data.pageParams.last + 1,
            // Suppresses every update.
            shouldRebuild: (previous, next) => false,
            client: client,
          );
          return Container();
        }),
        HookBuilder(builder: (context) {
          buildsB++;
          resultB = useInfiniteQuery<String, Object, int>(
            const ['feed'],
            (context) async {
              await Future.delayed(const Duration(seconds: 1));
              return 'page-${context.pageParam}';
            },
            initialPageParam: 0,
            nextPageParamBuilder: (data) => data.pageParams.last + 1,
            // Rebuilds whenever the data changes.
            shouldRebuild: (previous, next) =>
                previous.dataOrNull != next.dataOrNull,
            client: client,
          );
          return Container();
        }),
      ]));

      // Both share the same key, so both start pending with no data.
      expect(buildsA, 1);
      expect(buildsB, 1);
      expect(resultA.isPending, isTrue);
      expect(resultB.isPending, isTrue);

      // The single shared fetch completes, notifying both hooks' observers.
      await tester.pump(const Duration(seconds: 1));

      // Hook A's predicate suppressed the rebuild: still pending, no data.
      expect(buildsA, 1);
      expect(resultA.isPending, isTrue);
      expect(resultA.dataOrNull, isNull);

      // Hook B's predicate accepted the same update and rebuilt to success.
      // Each hook applies its own predicate even though they observe the same
      // query.
      expect(buildsB, 2);
      expect(resultB.isSuccess, isTrue);
      expect(resultB.pages, ['page-0']);
    }));
  });
}
