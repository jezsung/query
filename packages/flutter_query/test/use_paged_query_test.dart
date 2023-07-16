import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks_test/flutter_hooks_test.dart';
import 'package:flutter_query/flutter_query.dart';
import 'package:flutter_query/src/hooks/use_paged_query.dart';
import 'package:flutter_test/flutter_test.dart';

Widget withQueryScope(Widget widget) {
  return QueryScope(
    key: Key('query_scope'),
    child: widget,
  );
}

void main() {
  testWidgets(
    'fetches and succeeds',
    (tester) async {
      final data = 'data';
      const fetchDuration = Duration(seconds: 3);

      final result = await buildHook(
        (props) => usePagedQuery(
          'key',
          (key, _) async {
            await Future.delayed(fetchDuration);
            return data;
          },
        ),
        provide: (hookBuilder) => withQueryScope(hookBuilder),
      );

      expect(
        result.current.state,
        PagedQueryState<String>(
          status: QueryStatus.idle,
          pages: const [],
          error: null,
          dataUpdatedAt: null,
          errorUpdatedAt: null,
          isFetchingNextPage: false,
          isFetchingPreviousPage: false,
          hasNextPage: false,
          hasPreviousPage: false,
          isInvalidated: false,
        ),
      );

      await tester.pump();

      expect(
        result.current.state,
        PagedQueryState<String>(
          status: QueryStatus.fetching,
          pages: const [],
          error: null,
          dataUpdatedAt: null,
          errorUpdatedAt: null,
          isFetchingNextPage: false,
          isFetchingPreviousPage: false,
          hasNextPage: false,
          hasPreviousPage: false,
          isInvalidated: false,
        ),
      );

      await tester.pump(fetchDuration);

      expect(
        result.current.state,
        PagedQueryState<String>(
          status: QueryStatus.success,
          pages: [data],
          error: null,
          dataUpdatedAt: clock.now(),
          errorUpdatedAt: null,
          isFetchingNextPage: false,
          isFetchingPreviousPage: false,
          hasNextPage: false,
          hasPreviousPage: false,
          isInvalidated: false,
        ),
      );
    },
  );

  testWidgets(
    'fetches next page and succeeds',
    (tester) async {
      final initialData = 'initial data';
      final nextData = 'data';
      const fetchDuration = Duration(seconds: 3);

      final result = await buildHook(
        (props) => usePagedQuery(
          'key',
          (key, param) async {
            await Future.delayed(fetchDuration);

            if (param == null) return initialData;

            return nextData;
          },
          nextPageParamBuilder: (pages) {
            return 'param';
          },
        ),
        provide: (hookBuilder) => withQueryScope(hookBuilder),
      );

      await tester.pump(fetchDuration);

      await act(() => result.current.fetchNextPage());

      expect(
        result.current.state,
        PagedQueryState<String>(
          status: QueryStatus.fetching,
          pages: [initialData],
          error: null,
          dataUpdatedAt: clock.now(),
          errorUpdatedAt: null,
          isFetchingNextPage: true,
          isFetchingPreviousPage: false,
          hasNextPage: true,
          hasPreviousPage: false,
          isInvalidated: false,
        ),
      );

      await tester.pump(fetchDuration);

      expect(
        result.current.state,
        PagedQueryState<String>(
          status: QueryStatus.success,
          pages: [initialData, nextData],
          error: null,
          dataUpdatedAt: clock.now(),
          errorUpdatedAt: null,
          isFetchingNextPage: false,
          isFetchingPreviousPage: false,
          hasNextPage: true,
          hasPreviousPage: false,
          isInvalidated: false,
        ),
      );
    },
  );

  testWidgets(
    'fetcher initial param is null',
    (tester) async {
      late Object? initialParam;

      await buildHook(
        (props) => usePagedQuery(
          'key',
          (key, param) async {
            initialParam = param;
            return 'data';
          },
        ),
        provide: (hookBuilder) => withQueryScope(hookBuilder),
      );

      expect(initialParam, isNull);
    },
  );

  testWidgets(
    'fetcher param matches value returned from nextPageParamBuilder',
    (tester) async {
      final returnedParam = 'next param';
      late String receivedParam;

      final result = await buildHook(
        (props) => usePagedQuery<String, String, String>(
          'key',
          (key, param) async {
            if (param != null) {
              receivedParam = param;
            }
            return 'data';
          },
          nextPageParamBuilder: (pages) {
            return returnedParam;
          },
        ),
        provide: (hookBuilder) => withQueryScope(hookBuilder),
      );

      await act(() => result.current.fetchNextPage());

      expect(receivedParam, returnedParam);
    },
  );

  testWidgets(
    'hasNextPage is true when nextPageParam returns value',
    (tester) async {
      final result = await buildHook(
        (props) => usePagedQuery<String, String, String>(
          'key',
          (key, param) async {
            return 'data';
          },
          nextPageParamBuilder: (pages) {
            return 'param';
          },
        ),
        provide: (hookBuilder) => withQueryScope(hookBuilder),
      );

      await tester.pump();

      expect(result.current.state.hasNextPage, isTrue);
    },
  );

  testWidgets(
    'hasNextPage is false when nextPageParam returns null',
    (tester) async {
      final result = await buildHook(
        (props) => usePagedQuery<String, String, String>(
          'key',
          (key, param) async {
            return 'data';
          },
          nextPageParamBuilder: (pages) {
            return null;
          },
        ),
        provide: (hookBuilder) => withQueryScope(hookBuilder),
      );

      await tester.pump();

      expect(result.current.state.hasNextPage, isFalse);
    },
  );

  testWidgets(
    'isFetchingNext is false when fetching initial page',
    (tester) async {
      const fetchDuration = Duration(seconds: 3);

      final result = await buildHook(
        (props) => usePagedQuery<String, String, String>(
          'key',
          (key, param) async {
            await Future.delayed(fetchDuration);
            return 'data';
          },
          nextPageParamBuilder: (pages) {
            return 'data';
          },
        ),
        provide: (hookBuilder) => withQueryScope(hookBuilder),
      );

      expect(result.current.state.isFetchingNextPage, isFalse);

      await tester.binding.delayed(fetchDuration);
    },
  );

  testWidgets(
    'isFetchingNext is true when fetching next page',
    (tester) async {
      const fetchDuration = Duration(seconds: 3);

      final result = await buildHook(
        (props) => usePagedQuery<String, String, String>(
          'key',
          (key, param) async {
            await Future.delayed(fetchDuration);
            return 'data';
          },
          nextPageParamBuilder: (pages) {
            return 'data';
          },
        ),
        provide: (hookBuilder) => withQueryScope(hookBuilder),
      );

      await tester.pump(fetchDuration);

      await act(() => result.current.fetchNextPage());

      expect(result.current.state.isFetchingNextPage, isTrue);

      await tester.binding.delayed(fetchDuration);
    },
  );

  testWidgets(
    'does NOT fetch when enabled is false',
    (tester) async {
      const fetchDuration = Duration(seconds: 3);

      final result = await buildHook(
        (props) => usePagedQuery<String, String, String>(
          'key',
          (key, param) async {
            await Future.delayed(fetchDuration);
            return 'data';
          },
          nextPageParamBuilder: (pages) {
            return 'data';
          },
          enabled: false,
        ),
        provide: (hookBuilder) => withQueryScope(hookBuilder),
      );

      expect(result.current.state.status, QueryStatus.idle);

      await tester.pump();

      expect(result.current.state.status, QueryStatus.idle);
    },
  );

  testWidgets(
    'does NOT refetch on resumed when enabled is false',
    (tester) async {
      const fetchDuration = Duration(seconds: 3);

      final result = await buildHook(
        (props) => usePagedQuery<String, String, String>(
          'key',
          (key, param) async {
            await Future.delayed(fetchDuration);
            return 'data';
          },
          nextPageParamBuilder: (pages) {
            return 'data';
          },
          enabled: false,
        ),
        provide: (hookBuilder) => withQueryScope(hookBuilder),
      );

      expect(result.current.state.status, QueryStatus.idle);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(fetchDuration);

      expect(result.current.state.status, QueryStatus.idle);
    },
  );

  testWidgets(
    'fetches when enabled is changed from false to true',
    (tester) async {
      const fetchDuration = Duration(seconds: 3);

      final result = await buildHook<PagedQueryResult<String, String>, bool>(
        (enabled) => usePagedQuery<String, String, String>(
          'key',
          (key, param) async {
            await Future.delayed(fetchDuration);
            return 'data';
          },
          nextPageParamBuilder: (pages) {
            return 'data';
          },
          enabled: enabled!,
        ),
        initialProps: false,
        provide: (hookBuilder) => withQueryScope(hookBuilder),
      );

      await result.rebuild(true);

      expect(result.current.state.status, QueryStatus.idle);

      await tester.pump();

      expect(result.current.state.status, QueryStatus.fetching);

      await tester.pump(fetchDuration);

      expect(result.current.state.status, QueryStatus.success);
    },
  );

  group(
    'given initialData is set,',
    () {
      testWidgets(
        'sets data with given initialData',
        (tester) async {
          final initialData = ['data1', 'data2'];
          const fetchDuration = Duration(seconds: 3);

          final result =
              await buildHook<PagedQueryResult<String, String>, bool>(
            (_) => usePagedQuery<String, String, String>(
              'key',
              (key, param) async {
                await Future.delayed(fetchDuration);
                return 'data';
              },
              nextPageParamBuilder: (pages) {
                return 'data';
              },
              initialData: initialData,
            ),
            provide: (hookBuilder) => withQueryScope(hookBuilder),
          );

          expect(result.current.state.status, QueryStatus.success);
          expect(result.current.state.data, initialData);
          expect(result.current.state.dataUpdatedAt, clock.now());

          await tester.binding.delayed(fetchDuration);
        },
      );

      testWidgets(
        'refetches immediately when initialDataUpdatedAt is not set',
        (tester) async {
          final initialData = ['data1', 'data2'];
          final data = 'data';
          const fetchDuration = Duration(seconds: 3);

          final result =
              await buildHook<PagedQueryResult<String, String>, bool>(
            (_) => usePagedQuery<String, String, String>(
              'key',
              (key, param) async {
                await Future.delayed(fetchDuration);
                return data;
              },
              nextPageParamBuilder: (pages) {
                return 'param';
              },
              initialData: initialData,
            ),
            provide: (hookBuilder) => withQueryScope(hookBuilder),
          );

          await tester.pump();

          expect(result.current.state.status, QueryStatus.fetching);
          expect(result.current.state.data, initialData);
          expect(result.current.state.dataUpdatedAt, clock.now());

          await tester.pump(fetchDuration);

          expect(result.current.state.status, QueryStatus.success);
          expect(result.current.state.data, [data]);
          expect(result.current.state.dataUpdatedAt, clock.now());
        },
      );

      testWidgets(
        'does NOT refetch immediately when initialDataUpdatedAt is set and data is not stale',
        (tester) async {
          final initialData = ['data1', 'data2'];
          final initialDataUpdatedAt = clock.ago(minutes: 3);
          final data = 'data';
          const fetchDuration = Duration(seconds: 3);
          const staleDuration = Duration(minutes: 5);

          final result =
              await buildHook<PagedQueryResult<String, String>, bool>(
            (_) => usePagedQuery<String, String, String>(
              'key',
              (key, param) async {
                await Future.delayed(fetchDuration);
                return data;
              },
              nextPageParamBuilder: (pages) {
                return 'param';
              },
              initialData: initialData,
              initialDataUpdatedAt: initialDataUpdatedAt,
              staleDuration: staleDuration,
            ),
            provide: (hookBuilder) => withQueryScope(hookBuilder),
          );

          await tester.pump();

          expect(result.current.state.status, QueryStatus.success);
          expect(result.current.state.data, initialData);
          expect(result.current.state.dataUpdatedAt, initialDataUpdatedAt);
        },
      );

      testWidgets(
        'refetches immediately when initialDataUpdatedAt is set and data is stale',
        (tester) async {
          final initialData = ['data1', 'data2'];
          final initialDataUpdatedAt = clock.ago(minutes: 6);
          final data = 'data';
          const fetchDuration = Duration(seconds: 3);
          const staleDuration = Duration(minutes: 5);

          final result =
              await buildHook<PagedQueryResult<String, String>, bool>(
            (_) => usePagedQuery<String, String, String>(
              'key',
              (key, param) async {
                await Future.delayed(fetchDuration);
                return data;
              },
              nextPageParamBuilder: (pages) {
                return 'param';
              },
              initialData: initialData,
              initialDataUpdatedAt: initialDataUpdatedAt,
              staleDuration: staleDuration,
            ),
            provide: (hookBuilder) => withQueryScope(hookBuilder),
          );

          await tester.pump();

          expect(result.current.state.status, QueryStatus.fetching);
          expect(result.current.state.data, initialData);
          expect(result.current.state.dataUpdatedAt, initialDataUpdatedAt);

          await tester.pump(fetchDuration);

          expect(result.current.state.status, QueryStatus.success);
          expect(result.current.state.data, [data]);
          expect(result.current.state.dataUpdatedAt, clock.now());
        },
      );
    },
  );

  group(
    'given placeholder is set',
    () {
      testWidgets(
        'populates data with placeholder until data is fetched',
        (tester) async {
          final placeholder = ['data1', 'data2'];
          final data = 'data';
          const fetchDuration = Duration(seconds: 3);

          final result =
              await buildHook<PagedQueryResult<String, String>, bool>(
            (_) => usePagedQuery<String, String, String>(
              'key',
              (key, param) async {
                await Future.delayed(fetchDuration);
                return data;
              },
              nextPageParamBuilder: (pages) {
                return 'param';
              },
              placeholder: placeholder,
            ),
            provide: (hookBuilder) => withQueryScope(hookBuilder),
          );

          expect(result.current.state.status, QueryStatus.idle);
          expect(result.current.state.data, placeholder);
          expect(result.current.state.dataUpdatedAt, isNull);

          await tester.pump();

          expect(result.current.state.status, QueryStatus.fetching);
          expect(result.current.state.data, placeholder);
          expect(result.current.state.dataUpdatedAt, isNull);

          await tester.pump(fetchDuration);

          expect(result.current.state.status, QueryStatus.success);
          expect(result.current.state.data, [data]);
          expect(result.current.state.dataUpdatedAt, clock.now());
        },
      );
    },
  );
}
