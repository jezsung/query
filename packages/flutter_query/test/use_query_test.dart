import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_query/flutter_query.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hooks_test/flutter_hooks_test.dart';

Widget withQueryScope(Widget widget) {
  return QueryScope(
    key: Key('query_scope'),
    child: widget,
  );
}

void main() {
  testWidgets(
    'should fetch and succeed',
    (tester) async {
      final key = 'key';
      final data = 'data';
      const fetchDuration = Duration(seconds: 3);
      late QueryState<String> state;

      await tester.pumpWidget(withQueryScope(
        HookBuilder(
          builder: (context) {
            final result = useQuery<String>(
              key,
              (key) async {
                await Future.delayed(fetchDuration);
                return data;
              },
            );

            state = result.state;

            return Container();
          },
        ),
      ));

      expect(
        state,
        QueryState<String>(
          status: QueryStatus.idle,
          data: null,
          error: null,
          dataUpdatedAt: null,
          errorUpdatedAt: null,
          isInvalidated: false,
        ),
      );

      await tester.pump();

      expect(
        state,
        QueryState<String>(
          status: QueryStatus.fetching,
          data: null,
          error: null,
          dataUpdatedAt: null,
          errorUpdatedAt: null,
          isInvalidated: false,
        ),
      );

      await tester.pump(fetchDuration);

      expect(
        state,
        QueryState<String>(
          status: QueryStatus.success,
          data: data,
          error: null,
          dataUpdatedAt: clock.now(),
          errorUpdatedAt: null,
          isInvalidated: false,
        ),
      );
    },
  );

  testWidgets(
    'should fetch and fail',
    (tester) async {
      final key = 'key';
      final error = Exception();
      const fetchDuration = Duration(seconds: 3);
      late QueryState<String> state;

      await tester.pumpWidget(withQueryScope(
        HookBuilder(
          builder: (context) {
            final result = useQuery<String>(
              key,
              (key) async {
                await Future.delayed(fetchDuration);
                throw error;
              },
            );

            state = result.state;

            return Container();
          },
        ),
      ));

      expect(
        state,
        QueryState<String>(
          status: QueryStatus.idle,
          data: null,
          error: null,
          dataUpdatedAt: null,
          errorUpdatedAt: null,
          isInvalidated: false,
        ),
      );

      await tester.pump();

      expect(
        state,
        QueryState<String>(
          status: QueryStatus.fetching,
          data: null,
          error: null,
          dataUpdatedAt: null,
          errorUpdatedAt: null,
          isInvalidated: false,
        ),
      );

      await tester.pump(fetchDuration);

      expect(
        state,
        QueryState<String>(
          status: QueryStatus.failure,
          data: null,
          error: error,
          dataUpdatedAt: null,
          errorUpdatedAt: clock.now(),
          isInvalidated: false,
        ),
      );
    },
  );

  testWidgets(
    'should NOT fetch when enabled is false',
    (tester) async {
      final key = 'key';
      final data = 'data';

      late int fetchCount = 0;

      final result = await buildHook(
        (_) => useQuery(
          key,
          (key) async {
            fetchCount++;
            return data;
          },
          enabled: false,
        ),
        provide: (hookBuilder) => withQueryScope(hookBuilder),
      );

      expect(
        result.current.state,
        QueryState<String>(
          status: QueryStatus.idle,
          data: null,
          error: null,
          dataUpdatedAt: null,
          errorUpdatedAt: null,
          isInvalidated: false,
        ),
      );

      await tester.pump();

      expect(
        result.current.state,
        QueryState<String>(
          status: QueryStatus.idle,
          data: null,
          error: null,
          dataUpdatedAt: null,
          errorUpdatedAt: null,
          isInvalidated: false,
        ),
      );

      expect(fetchCount, isZero);
    },
  );

  testWidgets(
    'should fetch when enabled is changed from false to true',
    (tester) async {
      final key = 'key';
      final data = 'data';
      const fetchDuration = Duration(seconds: 3);

      final result = await buildHook<QueryResult<String>, bool>(
        (enabled) => useQuery(
          key,
          (key) async {
            await Future.delayed(fetchDuration);
            return data;
          },
          enabled: enabled!,
        ),
        initialProps: false,
        provide: (hookBuilder) => withQueryScope(hookBuilder),
      );

      expect(
        result.current.state,
        QueryState<String>(
          status: QueryStatus.idle,
          data: null,
          error: null,
          dataUpdatedAt: null,
          errorUpdatedAt: null,
          isInvalidated: false,
        ),
      );

      await tester.pump();

      expect(
        result.current.state,
        QueryState<String>(
          status: QueryStatus.idle,
          data: null,
          error: null,
          dataUpdatedAt: null,
          errorUpdatedAt: null,
          isInvalidated: false,
        ),
      );

      await result.rebuild(true);
      await tester.pump();

      expect(
        result.current.state,
        QueryState<String>(
          status: QueryStatus.fetching,
          data: null,
          error: null,
          dataUpdatedAt: null,
          errorUpdatedAt: null,
          isInvalidated: false,
        ),
      );

      await tester.pump(fetchDuration);

      expect(
        result.current.state,
        QueryState<String>(
          status: QueryStatus.success,
          data: data,
          error: null,
          dataUpdatedAt: clock.now(),
          errorUpdatedAt: null,
          isInvalidated: false,
        ),
      );
    },
  );

  testWidgets(
    'should refetch when enabled is changed from false to true',
    (tester) async {
      final data = 'data';
      const fetchDuration = Duration(seconds: 3);

      late DateTime dataUpdatedAt;
      late int fetchCount = 0;

      final result = await buildHook<QueryResult<String>, bool>(
        (enabled) => useQuery(
          'key',
          (key) async {
            fetchCount++;
            await Future.delayed(fetchDuration);
            return data;
          },
          enabled: enabled!,
        ),
        initialProps: true,
        provide: (hookBuilder) => withQueryScope(hookBuilder),
      );

      await tester.pump(fetchDuration);

      expect(
        result.current.state,
        QueryState<String>(
          status: QueryStatus.success,
          data: data,
          error: null,
          dataUpdatedAt: dataUpdatedAt = clock.now(),
          errorUpdatedAt: null,
          isInvalidated: false,
        ),
      );
      expect(fetchCount, 1);

      await result.rebuild(false);
      await result.rebuild(true);
      await tester.pump();

      expect(
        result.current.state,
        QueryState<String>(
          status: QueryStatus.fetching,
          data: data,
          error: null,
          dataUpdatedAt: dataUpdatedAt,
          errorUpdatedAt: null,
          isInvalidated: false,
        ),
      );

      await tester.pump(fetchDuration);

      expect(
        result.current.state,
        QueryState<String>(
          status: QueryStatus.success,
          data: data,
          error: null,
          dataUpdatedAt: dataUpdatedAt = clock.now(),
          errorUpdatedAt: null,
          isInvalidated: false,
        ),
      );
      expect(fetchCount, 2);
    },
  );

  group(
    'given initialData is set,',
    () {
      testWidgets(
        'should set status to ${QueryStatus.success} and data to initialData',
        (tester) async {
          final initialData = 'initial data';

          final result = await buildHook(
            (_) => useQuery(
              'key',
              (key) async => 'data',
              initialData: initialData,
            ),
            provide: (hookBuilder) => withQueryScope(hookBuilder),
          );

          expect(
            result.current.state,
            QueryState(
              status: QueryStatus.success,
              data: initialData,
              error: null,
              dataUpdatedAt: clock.now(),
              errorUpdatedAt: null,
              isInvalidated: false,
            ),
          );
        },
      );

      testWidgets(
        'should refetch immediately when initialDataUpdatedAt is not set',
        (tester) async {
          final initialData = 'initial data';
          final data = 'data';
          const fetchDuration = Duration(seconds: 3);

          final result = await buildHook(
            (_) => useQuery<String>(
              'key',
              (key) async {
                await Future.delayed(fetchDuration);
                return data;
              },
              initialData: initialData,
            ),
            provide: (hookBuilder) => withQueryScope(hookBuilder),
          );

          expect(
            result.current.state,
            QueryState(
              status: QueryStatus.success,
              data: initialData,
              error: null,
              dataUpdatedAt: clock.now(),
              errorUpdatedAt: null,
              isInvalidated: false,
            ),
          );

          await tester.pump();

          expect(
            result.current.state,
            QueryState(
              status: QueryStatus.fetching,
              data: initialData,
              error: null,
              dataUpdatedAt: clock.now(),
              errorUpdatedAt: null,
              isInvalidated: false,
            ),
          );

          await tester.pump(fetchDuration);

          expect(
            result.current.state,
            QueryState(
              status: QueryStatus.success,
              data: data,
              error: null,
              dataUpdatedAt: clock.now(),
              errorUpdatedAt: null,
              isInvalidated: false,
            ),
          );
        },
      );

      testWidgets(
        'should NOT refetch when initialDataUpdatedAt is set and data is not stale',
        (tester) async {
          final initialData = 'initial data';
          final initialDataUpdatedAt = clock.ago(minutes: 3);
          final data = 'data';
          const fetchDuration = Duration(seconds: 3);
          const staleDuraiton = Duration(minutes: 5);

          final result = await buildHook(
            (_) => useQuery<String>(
              'key',
              (key) async {
                await Future.delayed(fetchDuration);
                return data;
              },
              initialData: initialData,
              initialDataUpdatedAt: initialDataUpdatedAt,
              staleDuration: staleDuraiton,
            ),
            provide: (hookBuilder) => withQueryScope(hookBuilder),
          );

          expect(
            result.current.state,
            QueryState(
              status: QueryStatus.success,
              data: initialData,
              error: null,
              dataUpdatedAt: initialDataUpdatedAt,
              errorUpdatedAt: null,
              isInvalidated: false,
            ),
          );

          await tester.pump();

          expect(
            result.current.state,
            QueryState(
              status: QueryStatus.success,
              data: initialData,
              error: null,
              dataUpdatedAt: initialDataUpdatedAt,
              errorUpdatedAt: null,
              isInvalidated: false,
            ),
          );
        },
      );

      testWidgets(
        'should refetch when initialDataUpdatedAt is set and data is stale',
        (tester) async {
          final initialData = 'initial data';
          final initialDataUpdatedAt = clock.ago(minutes: 3);
          final data = 'data';
          const fetchDuration = Duration(seconds: 3);
          const staleDuraiton = Duration(minutes: 2);

          final result = await buildHook(
            (_) => useQuery<String>(
              'key',
              (key) async {
                await Future.delayed(fetchDuration);
                return data;
              },
              initialData: initialData,
              initialDataUpdatedAt: initialDataUpdatedAt,
              staleDuration: staleDuraiton,
            ),
            provide: (hookBuilder) => withQueryScope(hookBuilder),
          );

          expect(
            result.current.state,
            QueryState(
              status: QueryStatus.success,
              data: initialData,
              error: null,
              dataUpdatedAt: initialDataUpdatedAt,
              errorUpdatedAt: null,
              isInvalidated: false,
            ),
          );

          await tester.pump();

          expect(
            result.current.state,
            QueryState(
              status: QueryStatus.fetching,
              data: initialData,
              error: null,
              dataUpdatedAt: initialDataUpdatedAt,
              errorUpdatedAt: null,
              isInvalidated: false,
            ),
          );

          await tester.pump(fetchDuration);

          expect(
            result.current.state,
            QueryState(
              status: QueryStatus.success,
              data: data,
              error: null,
              dataUpdatedAt: clock.now(),
              errorUpdatedAt: null,
              isInvalidated: false,
            ),
          );
        },
      );
    },
  );

  testWidgets(
    'should populate data with placholder until data is fetched',
    (tester) async {
      final key = 'key';
      final data = 'data';
      final placholder = 'placeholder';
      const fetchDuration = Duration(seconds: 3);

      late QueryState<String> state;

      final hookBuilder = HookBuilder(
        key: Key('hook_builder'),
        builder: (context) {
          final result = useQuery<String>(
            key,
            (key) async {
              await Future.delayed(fetchDuration);
              return data;
            },
            placeholder: placholder,
          );

          state = result.state;

          return Container();
        },
      );

      await tester.pumpWidget(withQueryScope(hookBuilder));

      expect(
        state,
        QueryState<String>(
          status: QueryStatus.idle,
          data: placholder,
          error: null,
          dataUpdatedAt: null,
          errorUpdatedAt: null,
          isInvalidated: false,
        ),
      );

      await tester.pump();

      expect(
        state,
        QueryState<String>(
          status: QueryStatus.fetching,
          data: placholder,
          error: null,
          dataUpdatedAt: null,
          errorUpdatedAt: null,
          isInvalidated: false,
        ),
      );

      await tester.pump(fetchDuration);

      expect(
        state,
        QueryState<String>(
          status: QueryStatus.success,
          data: data,
          error: null,
          dataUpdatedAt: clock.now(),
          errorUpdatedAt: null,
          isInvalidated: false,
        ),
      );
    },
  );

  group(
    'given refetchOnInit is',
    () {
      testWidgets(
        '${RefetchBehavior.never}, it should NOT refetch',
        (tester) async {
          final key = 'key';
          final data1 = 'data1';
          final data2 = 'data2';
          const fetchDuration = Duration(seconds: 3);
          const staleDuration = Duration(minutes: 5);
          late DateTime dataUpdatedAt;
          late QueryState<String> state;

          final hook1 = HookBuilder(
            key: Key('hook_builder1'),
            builder: (context) {
              useQuery<String>(
                key,
                (key) async {
                  await Future.delayed(fetchDuration);
                  return data1;
                },
                staleDuration: staleDuration,
              );
              return Container();
            },
          );
          final hook2 = HookBuilder(
            key: Key('hook_builder2'),
            builder: (context) {
              final result = useQuery<String>(
                key,
                (key) async {
                  await Future.delayed(fetchDuration);
                  return data2;
                },
                staleDuration: staleDuration,
                refetchOnInit: RefetchBehavior.never,
              );

              state = result.state;

              return Container();
            },
          );

          await tester.pumpWidget(withQueryScope(
            Column(
              key: Key('column'),
              children: [hook1],
            ),
          ));

          await tester.pump(fetchDuration);

          dataUpdatedAt = clock.now();

          await tester.pump(staleDuration);

          await tester.pumpWidget(withQueryScope(
            Column(
              key: Key('column'),
              children: [hook1, hook2],
            ),
          ));

          expect(
            state,
            QueryState<String>(
              status: QueryStatus.success,
              data: data1,
              error: null,
              dataUpdatedAt: dataUpdatedAt,
              errorUpdatedAt: null,
              isInvalidated: false,
            ),
          );

          await tester.pump(fetchDuration);

          expect(
            state,
            QueryState<String>(
              status: QueryStatus.success,
              data: data1,
              error: null,
              dataUpdatedAt: dataUpdatedAt,
              errorUpdatedAt: null,
              isInvalidated: false,
            ),
          );
        },
      );

      testWidgets(
        '${RefetchBehavior.stale}, it should refetch when data is stale',
        (tester) async {
          final key = 'key';
          final data1 = 'data1';
          final data2 = 'data2';
          const fetchDuration = Duration(seconds: 3);
          const staleDuration = Duration(minutes: 5);
          late DateTime dataUpdatedAt;
          late QueryState<String> state;

          final hook1 = HookBuilder(
            key: Key('hook_builder1'),
            builder: (context) {
              useQuery<String>(
                key,
                (key) async {
                  await Future.delayed(fetchDuration);
                  return data1;
                },
                staleDuration: staleDuration,
              );

              return Container();
            },
          );
          final hook2 = HookBuilder(
            key: Key('hook_builder2'),
            builder: (context) {
              final result = useQuery<String>(
                key,
                (key) async {
                  await Future.delayed(fetchDuration);
                  return data2;
                },
                staleDuration: staleDuration,
                refetchOnInit: RefetchBehavior.stale,
              );

              state = result.state;

              return Container();
            },
          );

          await tester.pumpWidget(withQueryScope(
            Column(
              key: Key('column'),
              children: [hook1],
            ),
          ));

          await tester.pump(fetchDuration);

          dataUpdatedAt = clock.now();

          await tester.pump(staleDuration);

          await tester.pumpWidget(withQueryScope(
            Column(
              key: Key('column'),
              children: [hook1, hook2],
            ),
          ));

          expect(
            state,
            QueryState<String>(
              status: QueryStatus.success,
              data: data1,
              error: null,
              dataUpdatedAt: dataUpdatedAt,
              errorUpdatedAt: null,
              isInvalidated: false,
            ),
          );

          await tester.pump();

          expect(
            state,
            QueryState<String>(
              status: QueryStatus.fetching,
              data: data1,
              error: null,
              dataUpdatedAt: dataUpdatedAt,
              errorUpdatedAt: null,
              isInvalidated: false,
            ),
          );

          await tester.pump(fetchDuration);

          expect(
            state,
            QueryState<String>(
              status: QueryStatus.success,
              data: data2,
              error: null,
              dataUpdatedAt: dataUpdatedAt = clock.now(),
              errorUpdatedAt: null,
              isInvalidated: false,
            ),
          );
        },
      );

      testWidgets(
        '${RefetchBehavior.always}, it should refetch even when data is not stale',
        (tester) async {
          final key = 'key';
          final data1 = 'data1';
          final data2 = 'data2';
          const fetchDuration = Duration(seconds: 3);
          const staleDuration = Duration(minutes: 5);
          late DateTime dataUpdatedAt;
          late QueryState<String> state;

          final hook1 = HookBuilder(
            key: Key('hook_builder1'),
            builder: (context) {
              useQuery<String>(
                key,
                (key) async {
                  await Future.delayed(fetchDuration);
                  return data1;
                },
                staleDuration: staleDuration,
              );

              return Container();
            },
          );
          final hook2 = HookBuilder(
            key: Key('hook_builder2'),
            builder: (context) {
              final result = useQuery<String>(
                key,
                (key) async {
                  await Future.delayed(fetchDuration);
                  return data2;
                },
                staleDuration: staleDuration,
                refetchOnInit: RefetchBehavior.always,
              );

              state = result.state;

              return Container();
            },
          );

          await tester.pumpWidget(withQueryScope(
            Column(
              key: Key('column'),
              children: [hook1],
            ),
          ));

          await tester.pump(fetchDuration);

          dataUpdatedAt = clock.now();

          await tester.pumpWidget(withQueryScope(
            Column(
              key: Key('column'),
              children: [hook1, hook2],
            ),
          ));

          expect(
            state,
            QueryState<String>(
              status: QueryStatus.success,
              data: data1,
              error: null,
              dataUpdatedAt: dataUpdatedAt,
              errorUpdatedAt: null,
              isInvalidated: false,
            ),
          );

          await tester.pump();

          expect(
            state,
            QueryState<String>(
              status: QueryStatus.fetching,
              data: data1,
              error: null,
              dataUpdatedAt: dataUpdatedAt,
              errorUpdatedAt: null,
              isInvalidated: false,
            ),
          );

          await tester.pump(fetchDuration);

          expect(
            state,
            QueryState<String>(
              status: QueryStatus.success,
              data: data2,
              error: null,
              dataUpdatedAt: dataUpdatedAt = clock.now(),
              errorUpdatedAt: null,
              isInvalidated: false,
            ),
          );
        },
      );
    },
  );

  group(
    'given refetchOnResumed is',
    () {
      testWidgets(
        '${RefetchBehavior.never}, it should NOT refetch',
        (tester) async {
          final key = 'key';
          final data = 'data';
          const fetchDuration = Duration(seconds: 3);
          const staleDuration = Duration(minutes: 5);
          late DateTime dataUpdatedAt;
          late QueryState<String> state;

          final hook = HookBuilder(
            key: Key('hook_builder'),
            builder: (context) {
              final result = useQuery<String>(
                key,
                (key) async {
                  await Future.delayed(fetchDuration);
                  return data;
                },
                staleDuration: staleDuration,
                refetchOnResumed: RefetchBehavior.never,
              );

              state = result.state;

              return Container();
            },
          );

          await tester.pumpWidget(withQueryScope(hook));

          await tester.pump(fetchDuration);

          dataUpdatedAt = clock.now();

          await tester.pump(staleDuration);

          tester.binding
              .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          await tester.pump();

          expect(
            state,
            QueryState<String>(
              status: QueryStatus.success,
              data: data,
              error: null,
              dataUpdatedAt: dataUpdatedAt,
              errorUpdatedAt: null,
              isInvalidated: false,
            ),
          );

          await tester.pump();

          expect(
            state,
            QueryState<String>(
              status: QueryStatus.success,
              data: data,
              error: null,
              dataUpdatedAt: dataUpdatedAt,
              errorUpdatedAt: null,
              isInvalidated: false,
            ),
          );

          await tester.pump(fetchDuration);

          expect(
            state,
            QueryState<String>(
              status: QueryStatus.success,
              data: data,
              error: null,
              dataUpdatedAt: dataUpdatedAt,
              errorUpdatedAt: null,
              isInvalidated: false,
            ),
          );
        },
      );

      testWidgets(
        '${RefetchBehavior.stale}, it should refetch when data is stale',
        (tester) async {
          final key = 'key';
          final data = 'data';
          const fetchDuration = Duration(seconds: 3);
          const staleDuration = Duration(minutes: 5);
          late DateTime dataUpdatedAt;
          late QueryState<String> state;

          final hook = HookBuilder(
            key: Key('hook_builder'),
            builder: (context) {
              final result = useQuery<String>(
                key,
                (key) async {
                  await Future.delayed(fetchDuration);
                  return data;
                },
                staleDuration: staleDuration,
                refetchOnResumed: RefetchBehavior.stale,
              );

              state = result.state;

              return Container();
            },
          );

          await tester.pumpWidget(withQueryScope(hook));

          await tester.pump(fetchDuration);

          dataUpdatedAt = clock.now();

          await tester.pump(staleDuration);

          tester.binding
              .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          await tester.pump();

          expect(
            state,
            QueryState<String>(
              status: QueryStatus.success,
              data: data,
              error: null,
              dataUpdatedAt: dataUpdatedAt,
              errorUpdatedAt: null,
              isInvalidated: false,
            ),
          );

          await tester.pump();

          expect(
            state,
            QueryState<String>(
              status: QueryStatus.fetching,
              data: data,
              error: null,
              dataUpdatedAt: dataUpdatedAt,
              errorUpdatedAt: null,
              isInvalidated: false,
            ),
          );

          await tester.pump(fetchDuration);

          expect(
            state,
            QueryState<String>(
              status: QueryStatus.success,
              data: data,
              error: null,
              dataUpdatedAt: dataUpdatedAt = clock.now(),
              errorUpdatedAt: null,
              isInvalidated: false,
            ),
          );
        },
      );

      testWidgets(
        '${RefetchBehavior.always}, it should refetch even when data is not stale',
        (tester) async {
          final key = 'key';
          final data = 'data';
          const fetchDuration = Duration(seconds: 3);
          const staleDuration = Duration(minutes: 5);
          late DateTime dataUpdatedAt;
          late QueryState<String> state;

          final hook = HookBuilder(
            key: Key('hook_builder'),
            builder: (context) {
              final result = useQuery<String>(
                key,
                (key) async {
                  await Future.delayed(fetchDuration);
                  return data;
                },
                staleDuration: staleDuration,
                refetchOnResumed: RefetchBehavior.always,
              );

              state = result.state;

              return Container();
            },
          );

          await tester.pumpWidget(withQueryScope(hook));

          await tester.pump(fetchDuration);

          dataUpdatedAt = clock.now();

          tester.binding
              .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          await tester.pump();

          expect(
            state,
            QueryState<String>(
              status: QueryStatus.success,
              data: data,
              error: null,
              dataUpdatedAt: dataUpdatedAt,
              errorUpdatedAt: null,
              isInvalidated: false,
            ),
          );

          await tester.pump();

          expect(
            state,
            QueryState<String>(
              status: QueryStatus.fetching,
              data: data,
              error: null,
              dataUpdatedAt: dataUpdatedAt,
              errorUpdatedAt: null,
              isInvalidated: false,
            ),
          );

          await tester.pump(fetchDuration);

          expect(
            state,
            QueryState<String>(
              status: QueryStatus.success,
              data: data,
              error: null,
              dataUpdatedAt: dataUpdatedAt = clock.now(),
              errorUpdatedAt: null,
              isInvalidated: false,
            ),
          );
        },
      );
    },
  );

  testWidgets(
    'should cancel and revert state back when cancel is called manually',
    (tester) async {
      final key = 'key';
      final data = 'data';
      const fetchDuration = Duration(seconds: 3);

      late QueryState<String> state;
      late QueryCancel cancel;

      await tester.pumpWidget(withQueryScope(
        HookBuilder(
          builder: (context) {
            final result = useQuery<String>(
              key,
              (key) async {
                await Future.delayed(fetchDuration);
                return data;
              },
            );

            state = result.state;
            cancel = result.cancel;

            return Container();
          },
        ),
      ));

      expect(
        state,
        QueryState<String>(
          status: QueryStatus.idle,
          data: null,
          error: null,
          dataUpdatedAt: null,
          errorUpdatedAt: null,
          isInvalidated: false,
        ),
      );

      await tester.pump();

      expect(
        state,
        QueryState<String>(
          status: QueryStatus.fetching,
          data: null,
          error: null,
          dataUpdatedAt: null,
          errorUpdatedAt: null,
          isInvalidated: false,
        ),
      );

      await cancel();
      await tester.pump();
      await tester.pump();

      expect(
        state,
        QueryState<String>(
          status: QueryStatus.idle,
          data: null,
          error: null,
          dataUpdatedAt: null,
          errorUpdatedAt: null,
          isInvalidated: false,
        ),
      );

      await tester.binding.delayed(fetchDuration);
    },
  );

  testWidgets(
    'should refetch when refetech is called manually',
    (tester) async {
      final key = 'key';
      final data = 'data';
      const fetchDuration = Duration(seconds: 3);
      late QueryState<String> state;
      late QueryRefetch refetch;

      await tester.pumpWidget(withQueryScope(
        HookBuilder(
          builder: (context) {
            final result = useQuery<String>(
              key,
              (key) async {
                await Future.delayed(fetchDuration);
                return data;
              },
            );

            state = result.state;
            refetch = result.refetch;

            return Container();
          },
        ),
      ));

      await tester.pump(fetchDuration);

      expect(
        state,
        QueryState<String>(
          status: QueryStatus.success,
          data: data,
          error: null,
          dataUpdatedAt: clock.now(),
          errorUpdatedAt: null,
          isInvalidated: false,
        ),
      );

      refetch();

      await tester.pump();

      expect(
        state,
        QueryState<String>(
          status: QueryStatus.success,
          data: data,
          error: null,
          dataUpdatedAt: clock.now(),
          errorUpdatedAt: null,
          isInvalidated: false,
        ),
      );

      await tester.pump();

      expect(
        state,
        QueryState<String>(
          status: QueryStatus.fetching,
          data: data,
          error: null,
          dataUpdatedAt: clock.now(),
          errorUpdatedAt: null,
          isInvalidated: false,
        ),
      );

      await tester.pump(fetchDuration);

      expect(
        state,
        QueryState<String>(
          status: QueryStatus.success,
          data: data,
          error: null,
          dataUpdatedAt: clock.now(),
          errorUpdatedAt: null,
          isInvalidated: false,
        ),
      );
    },
  );

  testWidgets(
    'should refetch and succeed when navigated',
    (tester) async {
      final queryKey = 'key';
      final data1 = 'data1';
      final data2 = 'data2';
      const fetchDuration = Duration(seconds: 3);

      late QueryState<String> state;
      late DateTime dataUpdatedAt;

      final hookBuilder1 = HookBuilder(
        key: Key('hook_builder1'),
        builder: (context) {
          useQuery(
            queryKey,
            (key) async {
              await Future.delayed(fetchDuration);
              return data1;
            },
          );
          return Container();
        },
      );
      final hookBuilder2 = HookBuilder(
        key: Key('hook_builder2'),
        builder: (context) {
          final result = useQuery(
            queryKey,
            (key) async {
              await Future.delayed(fetchDuration);
              return data2;
            },
          );
          state = result.state;
          return Container();
        },
      );
      final widget = MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Column(
                children: [
                  hookBuilder1,
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) {
                            return Scaffold(
                              body: hookBuilder2,
                            );
                          },
                        ),
                      );
                    },
                    child: Text('Navigate'),
                  ),
                ],
              ),
            );
          },
        ),
      );

      Future navigate() async {
        await tester.tap(find.byType(TextButton));
      }

      await tester.pumpWidget(withQueryScope(widget));
      await tester.pump(fetchDuration);
      dataUpdatedAt = clock.now();
      await navigate();
      await tester.pump();

      expect(
        state,
        QueryState<String>(
          status: QueryStatus.success,
          data: data1,
          error: null,
          dataUpdatedAt: dataUpdatedAt,
          errorUpdatedAt: null,
          isInvalidated: false,
        ),
      );

      await tester.pump();

      expect(
        state,
        QueryState<String>(
          status: QueryStatus.fetching,
          data: data1,
          error: null,
          dataUpdatedAt: dataUpdatedAt,
          errorUpdatedAt: null,
          isInvalidated: false,
        ),
      );

      await tester.pump(fetchDuration);

      expect(
        state,
        QueryState<String>(
          status: QueryStatus.success,
          data: data2,
          error: null,
          dataUpdatedAt: dataUpdatedAt = clock.now(),
          errorUpdatedAt: null,
          isInvalidated: false,
        ),
      );
    },
  );

  group(
    'given QueryClient is used,',
    () {
      testWidgets(
        'should refetch when refetch is called',
        (tester) async {
          final key = 'key';
          final data = 'data';
          const fetchDuration = Duration(seconds: 3);

          late QueryClient queryClient;
          late QueryState<String> state;
          late DateTime dataUpdatedAt;

          await tester.pumpWidget(withQueryScope(
            HookBuilder(
              builder: (context) {
                queryClient = useQueryClient();
                final result = useQuery<String>(
                  key,
                  (key) async {
                    await Future.delayed(fetchDuration);
                    return data;
                  },
                );

                state = result.state;

                return Container();
              },
            ),
          ));

          expect(
            state,
            QueryState<String>(
              status: QueryStatus.idle,
              data: null,
              error: null,
              dataUpdatedAt: null,
              errorUpdatedAt: null,
              isInvalidated: false,
            ),
          );

          await tester.pump(fetchDuration);

          dataUpdatedAt = clock.now();

          queryClient.refetch(key);
          await tester.pump();

          expect(
            state,
            QueryState<String>(
              status: QueryStatus.success,
              data: data,
              error: null,
              dataUpdatedAt: dataUpdatedAt,
              errorUpdatedAt: null,
              isInvalidated: false,
            ),
          );

          await tester.pump();

          expect(
            state,
            QueryState<String>(
              status: QueryStatus.fetching,
              data: data,
              error: null,
              dataUpdatedAt: dataUpdatedAt,
              errorUpdatedAt: null,
              isInvalidated: false,
            ),
          );

          await tester.pump(fetchDuration);

          expect(
            state,
            QueryState<String>(
              status: QueryStatus.success,
              data: data,
              error: null,
              dataUpdatedAt: dataUpdatedAt = clock.now(),
              errorUpdatedAt: null,
              isInvalidated: false,
            ),
          );
        },
      );

      testWidgets(
        'should cancel and revert state back when cancel is called',
        (tester) async {
          final key = 'key';
          final data = 'data';
          const fetchDuration = Duration(seconds: 3);

          late QueryClient queryClient;
          late QueryState<String> state;

          await tester.pumpWidget(withQueryScope(
            HookBuilder(
              builder: (context) {
                queryClient = useQueryClient();
                final result = useQuery<String>(
                  key,
                  (key) async {
                    await Future.delayed(fetchDuration);
                    return data;
                  },
                );

                state = result.state;

                return Container();
              },
            ),
          ));

          expect(
            state,
            QueryState<String>(
              status: QueryStatus.idle,
              data: null,
              error: null,
              dataUpdatedAt: null,
              errorUpdatedAt: null,
              isInvalidated: false,
            ),
          );

          await tester.pump();

          expect(
            state,
            QueryState<String>(
              status: QueryStatus.fetching,
              data: null,
              error: null,
              dataUpdatedAt: null,
              errorUpdatedAt: null,
              isInvalidated: false,
            ),
          );

          await queryClient.cancel(key);
          await tester.pump();
          await tester.pump();

          expect(
            state,
            QueryState<String>(
              status: QueryStatus.idle,
              data: null,
              error: null,
              dataUpdatedAt: null,
              errorUpdatedAt: null,
              isInvalidated: false,
            ),
          );

          await tester.binding.delayed(fetchDuration);
        },
      );
    },
  );
}
