import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_query/flutter_query.dart';
import 'package:flutter_query/src/hooks/use_query.dart';
import 'package:flutter_test/flutter_test.dart';

Widget withQueryClientProvider(Widget widget, [QueryClient? client]) {
  if (client != null) {
    return QueryClientProvider.value(
      key: Key('query_client_provider'),
      value: client,
      child: widget,
    );
  } else {
    return QueryClientProvider(
      key: Key('query_client_provider'),
      create: (context) => QueryClient(),
      child: widget,
    );
  }
}

void main() {
  testWidgets(
    'should fetch and succeed',
    (tester) async {
      final key = 'key';
      final data = 'data';
      const fetchDuration = Duration(seconds: 3);
      late QueryState<String> state;

      await tester.pumpWidget(withQueryClientProvider(
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

      await tester.pumpWidget(withQueryClientProvider(
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

          await tester.pumpWidget(withQueryClientProvider(
            Column(
              key: Key('column'),
              children: [hook1],
            ),
          ));

          await tester.pump(fetchDuration);

          dataUpdatedAt = clock.now();

          await tester.pump(staleDuration);

          await tester.pumpWidget(withQueryClientProvider(
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

          await tester.pumpWidget(withQueryClientProvider(
            Column(
              key: Key('column'),
              children: [hook1],
            ),
          ));

          await tester.pump(fetchDuration);

          dataUpdatedAt = clock.now();

          await tester.pump(staleDuration);

          await tester.pumpWidget(withQueryClientProvider(
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

          await tester.pumpWidget(withQueryClientProvider(
            Column(
              key: Key('column'),
              children: [hook1],
            ),
          ));

          await tester.pump(fetchDuration);

          dataUpdatedAt = clock.now();

          await tester.pumpWidget(withQueryClientProvider(
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

          await tester.pumpWidget(withQueryClientProvider(hook));

          await tester.pump(fetchDuration);

          dataUpdatedAt = clock.now();

          await tester.pump(staleDuration);

          tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
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

          await tester.pumpWidget(withQueryClientProvider(hook));

          await tester.pump(fetchDuration);

          dataUpdatedAt = clock.now();

          await tester.pump(staleDuration);

          tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
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

          await tester.pumpWidget(withQueryClientProvider(hook));

          await tester.pump(fetchDuration);

          dataUpdatedAt = clock.now();

          tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
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
    'should refetch when refetech is called manually',
    (tester) async {
      final key = 'key';
      final data = 'data';
      const fetchDuration = Duration(seconds: 3);
      late QueryState<String> state;
      late Refetch refetch;

      await tester.pumpWidget(withQueryClientProvider(
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
}
