import 'package:fluery/fluery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

extension WidgetTesterExtension on WidgetTester {
  Future<void> pumpWithQueryClientProvider(
    Widget? widget, [
    QueryClient? queryClient,
    Duration? duration,
    EnginePhase enginePhase = EnginePhase.sendSemanticsUpdate,
  ]) async {
    await pumpWidget(
      QueryClientProvider(
        client: queryClient,
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return widget ?? Placeholder();
            },
          ),
        ),
      ),
      duration,
      enginePhase,
    );
  }
}

void main() {
  testWidgets(
    'should succeed',
    (tester) async {
      const fetchDuration = Duration(seconds: 3);

      await tester.pumpWithQueryClientProvider(
        QueryBuilder<String>(
          id: 'id',
          fetcher: (id) async {
            await Future.delayed(fetchDuration);
            return 'data';
          },
          builder: (context, state, child) {
            return Column(
              children: [
                Text('status: ${state.status.name}'),
                Text('data: ${state.data}'),
                Text('error: ${state.error}'),
              ],
            );
          },
        ),
      );

      expect(find.text('status: fetching'), findsOneWidget);
      expect(find.text('data: null'), findsOneWidget);
      expect(find.text('error: null'), findsOneWidget);

      await tester.pump(fetchDuration);

      expect(find.text('status: success'), findsOneWidget);
      expect(find.text('data: data'), findsOneWidget);
      expect(find.text('error: null'), findsOneWidget);
    },
  );

  testWidgets(
    'should fail',
    (tester) async {
      const fetchDuration = Duration(seconds: 3);

      await tester.pumpWithQueryClientProvider(
        QueryBuilder<String>(
          id: 'id',
          fetcher: (id) async {
            await Future.delayed(fetchDuration);
            throw 'error';
          },
          builder: (context, state, child) {
            return Column(
              children: [
                Text('status: ${state.status.name}'),
                Text('data: ${state.data}'),
                Text('error: ${state.error}'),
              ],
            );
          },
        ),
      );

      expect(find.text('status: fetching'), findsOneWidget);
      expect(find.text('data: null'), findsOneWidget);
      expect(find.text('error: null'), findsOneWidget);

      await tester.pump(fetchDuration);

      expect(find.text('status: failure'), findsOneWidget);
      expect(find.text('data: null'), findsOneWidget);
      expect(find.text('error: error'), findsOneWidget);
    },
  );

  testWidgets(
    'should start fetching when a cached query becomes stale',
    (tester) async {
      final client = QueryClient()..setQueryData('id', 'cached data');
      const staleDuration = Duration(minutes: 10);
      const fetchDuration = Duration(seconds: 3);
      final widget = QueryBuilder<String>(
        id: 'id',
        fetcher: (id) async {
          await Future.delayed(fetchDuration);
          return 'data';
        },
        staleDuration: staleDuration,
        builder: (context, state, child) {
          return Column(
            children: [
              Text('status: ${state.status.name}'),
              Text('data: ${state.data}'),
              Text('error: ${state.error}'),
            ],
          );
        },
      );

      await tester.pumpWithQueryClientProvider(widget, client);

      // Should show the cached query since the query is still fresh.
      expect(find.text('status: success'), findsOneWidget);
      expect(find.text('data: cached data'), findsOneWidget);
      expect(find.text('error: null'), findsOneWidget);

      await tester.pump(staleDuration);

      // The widget is initialized again.
      await tester.pumpWithQueryClientProvider(null, client);
      await tester.pumpWithQueryClientProvider(widget, client);

      // Should start fetching since now the query is stale.
      expect(find.text('status: fetching'), findsOneWidget);
      expect(find.text('data: cached data'), findsOneWidget);
      expect(find.text('error: null'), findsOneWidget);

      await tester.pump(fetchDuration);

      expect(find.text('status: success'), findsOneWidget);
      expect(find.text('data: data'), findsOneWidget);
      expect(find.text('error: null'), findsOneWidget);
    },
  );

  group(
    'when the "enabled" is false',
    () {
      testWidgets(
        'should not start fetching',
        (tester) async {
          final widget = QueryBuilder<String>(
            id: 'id',
            fetcher: (id) async {
              return 'data';
            },
            enabled: false,
            builder: (context, state, child) {
              return Column(
                children: [
                  Text('status: ${state.status.name}'),
                  Text('data: ${state.data}'),
                  Text('error: ${state.error}'),
                ],
              );
            },
          );

          await tester.pumpWithQueryClientProvider(widget);

          expect(find.text('status: idle'), findsOneWidget);
          expect(find.text('data: null'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);
        },
      );

      testWidgets(
        'should populate the cached query if one exists',
        (tester) async {
          final client = QueryClient()..setQueryData('id', 'cached data');
          final widget = QueryBuilder<String>(
            id: 'id',
            fetcher: (id) async {
              return 'data';
            },
            enabled: false,
            builder: (context, state, child) {
              return Column(
                children: [
                  Text('status: ${state.status.name}'),
                  Text('data: ${state.data}'),
                  Text('error: ${state.error}'),
                ],
              );
            },
          );

          await tester.pumpWithQueryClientProvider(widget, client);

          expect(find.text('status: success'), findsOneWidget);
          expect(find.text('data: cached data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);
        },
      );

      testWidgets(
        'should not refetch on init regardless of the "refetchOnInit" property',
        (tester) async {
          for (final mode in RefetchMode.values) {
            final client = QueryClient()..setQueryData('id', 'cached data');
            final widget = QueryBuilder<String>(
              id: 'id',
              fetcher: (id) async {
                return 'data';
              },
              enabled: false,
              refetchOnInit: mode,
              builder: (context, state, child) {
                return Column(
                  children: [
                    Text('status: ${state.status.name}'),
                    Text('data: ${state.data}'),
                    Text('error: ${state.error}'),
                  ],
                );
              },
            );

            await tester.pumpWithQueryClientProvider(widget, client);

            expect(find.text('status: success'), findsOneWidget);
            expect(find.text('data: cached data'), findsOneWidget);
            expect(find.text('error: null'), findsOneWidget);
          }
        },
      );

      testWidgets(
        'should not refetch on resumed regardless of the "refetchOnResumed" property',
        (tester) async {
          for (final mode in RefetchMode.values) {
            final client = QueryClient()..setQueryData('id', 'cached data');
            final widget = QueryBuilder<String>(
              id: 'id',
              fetcher: (id) async {
                return 'data';
              },
              enabled: false,
              refetchOnInit: RefetchMode.never,
              refetchOnResumed: mode,
              builder: (context, state, child) {
                return Column(
                  children: [
                    Text('status: ${state.status.name}'),
                    Text('data: ${state.data}'),
                    Text('error: ${state.error}'),
                  ],
                );
              },
            );

            await tester.pumpWithQueryClientProvider(widget, client);

            tester.binding
                .handleAppLifecycleStateChanged(AppLifecycleState.resumed);

            expect(find.text('status: success'), findsOneWidget);
            expect(find.text('data: cached data'), findsOneWidget);
            expect(find.text('error: null'), findsOneWidget);
          }
        },
      );

      testWidgets(
        'should not refetch on intervals even if the "refetchIntervalDuration" is set',
        (tester) async {
          final client = QueryClient()..setQueryData('id', 'cached data');
          const refetchIntervalDuration = Duration(seconds: 3);
          final widget = QueryBuilder<String>(
            id: 'id',
            fetcher: (id) async {
              return 'data';
            },
            enabled: false,
            refetchOnInit: RefetchMode.never,
            refetchOnResumed: RefetchMode.never,
            refetchIntervalDuration: refetchIntervalDuration,
            builder: (context, state, child) {
              return Column(
                children: [
                  Text('status: ${state.status.name}'),
                  Text('data: ${state.data}'),
                  Text('error: ${state.error}'),
                ],
              );
            },
          );

          await tester.pumpWithQueryClientProvider(widget, client);

          for (int i = 0; i < 5; i++) {
            expect(find.text('status: success'), findsOneWidget);
            expect(find.text('data: cached data'), findsOneWidget);
            expect(find.text('error: null'), findsOneWidget);

            await tester.pump(refetchIntervalDuration);
          }
        },
      );
    },
  );

  group(
    'when the "enabled" is changed from "false" to "true"',
    () {
      testWidgets(
        'should start fetching',
        (tester) async {
          const fetchDuration = Duration(seconds: 3);
          final widget = QueryBuilder<String>(
            id: 'id',
            fetcher: (id) async {
              await Future.delayed(fetchDuration);
              return 'data';
            },
            enabled: false,
            builder: (context, state, child) {
              return Column(
                children: [
                  Text('status: ${state.status.name}'),
                  Text('data: ${state.data}'),
                  Text('error: ${state.error}'),
                ],
              );
            },
          );

          await tester.pumpWithQueryClientProvider(
            widget.copyWith(enabled: false),
          );
          await tester.pumpWithQueryClientProvider(
            widget.copyWith(enabled: true),
          );

          expect(find.text('status: fetching'), findsOneWidget);
          expect(find.text('data: null'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await tester.pump(fetchDuration);

          expect(find.text('status: success'), findsOneWidget);
          expect(find.text('data: data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);
        },
      );

      testWidgets(
        'should not refetch if the "refetchOnInit" is set to "RefetchMode.never"',
        (tester) async {
          final client = QueryClient()..setQueryData('id', 'cached data');
          const fetchDuration = Duration(seconds: 3);
          final widget = QueryBuilder<String>(
            id: 'id',
            fetcher: (id) async {
              await Future.delayed(fetchDuration);
              return 'data';
            },
            enabled: false,
            refetchOnInit: RefetchMode.never,
            builder: (context, state, child) {
              return Column(
                children: [
                  Text('status: ${state.status.name}'),
                  Text('data: ${state.data}'),
                  Text('error: ${state.error}'),
                ],
              );
            },
          );

          await tester.pumpWithQueryClientProvider(
            widget.copyWith(enabled: false),
            client,
          );
          await tester.pumpWithQueryClientProvider(
            widget.copyWith(enabled: true),
            client,
          );

          expect(find.text('status: success'), findsOneWidget);
          expect(find.text('data: cached data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);
        },
      );

      testWidgets(
        'should refetch if the "refetchOnInit" is set to "RefecthMode.stale" and the data is stale',
        (tester) async {
          final client = QueryClient()..setQueryData('id', 'cached data');
          const staleDuration = Duration(minutes: 10);
          const fetchDuration = Duration(seconds: 3);
          final widget = QueryBuilder<String>(
            id: 'id',
            fetcher: (id) async {
              await Future.delayed(fetchDuration);
              return 'data';
            },
            enabled: false,
            staleDuration: staleDuration,
            refetchOnInit: RefetchMode.stale,
            builder: (context, state, child) {
              return Column(
                children: [
                  Text('status: ${state.status.name}'),
                  Text('data: ${state.data}'),
                  Text('error: ${state.error}'),
                ],
              );
            },
          );

          await tester.pumpWithQueryClientProvider(
            widget.copyWith(enabled: false),
            client,
          );
          await tester.pumpWithQueryClientProvider(
            widget.copyWith(enabled: true),
            client,
          );

          // The data is not stale yet, the query should not be fetching.
          expect(find.text('status: success'), findsOneWidget);
          expect(find.text('data: cached data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await tester.pump(staleDuration);
          await tester.pumpWithQueryClientProvider(
            widget.copyWith(enabled: false),
            client,
          );
          await tester.pumpWithQueryClientProvider(
            widget.copyWith(enabled: true),
            client,
          );

          // The data is stale, the query should be fetching.
          expect(find.text('status: fetching'), findsOneWidget);
          expect(find.text('data: cached data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await tester.pump(fetchDuration);

          expect(find.text('status: success'), findsOneWidget);
          expect(find.text('data: data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);
        },
      );

      testWidgets(
        'should refetch if the "refetchOnInit" is set to "RefecthMode.always"',
        (tester) async {
          final client = QueryClient()..setQueryData('id', 'cached data');
          const fetchDuration = Duration(seconds: 3);
          final widget = QueryBuilder<String>(
            key: ValueKey('key'),
            id: 'id',
            fetcher: (id) async {
              await Future.delayed(fetchDuration);
              return 'data';
            },
            enabled: false,
            refetchOnInit: RefetchMode.always,
            builder: (context, state, child) {
              return Column(
                children: [
                  Text('status: ${state.status.name}'),
                  Text('data: ${state.data}'),
                  Text('error: ${state.error}'),
                ],
              );
            },
          );

          await tester.pumpWithQueryClientProvider(
            widget.copyWith(enabled: false),
            client,
          );
          await tester.pumpWithQueryClientProvider(
            widget.copyWith(enabled: true),
            client,
          );

          expect(find.text('status: fetching'), findsOneWidget);
          expect(find.text('data: cached data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await tester.pump(fetchDuration);

          expect(find.text('status: success'), findsOneWidget);
          expect(find.text('data: data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);
        },
      );
    },
  );

  group(
    'when the "placeholder" is set',
    () {
      testWidgets(
        'should show the "placeholder" if there is no cached data',
        (tester) async {
          const fetchDuration = Duration(seconds: 3);
          final widget = QueryBuilder<String>(
            id: 'id',
            fetcher: (id) async {
              await Future.delayed(fetchDuration);
              return 'data';
            },
            placeholder: 'placeholder data',
            builder: (context, state, child) {
              return Column(
                children: [
                  Text('status: ${state.status.name}'),
                  Text('data: ${state.data}'),
                  Text('error: ${state.error}'),
                ],
              );
            },
          );

          // Tests success case.
          await tester.pumpWithQueryClientProvider(widget);

          expect(find.text('status: fetching'), findsOneWidget);
          expect(find.text('data: placeholder data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await tester.pump(fetchDuration);

          expect(find.text('status: success'), findsOneWidget);
          expect(find.text('data: data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          // Tests failure case.
          await tester.pumpWidget(Placeholder());
          await tester.pumpWithQueryClientProvider(
            widget.copyWith(
              fetcher: (id) async {
                await Future.delayed(fetchDuration);
                throw 'error';
              },
              retryCount: 1,
            ),
          );

          expect(find.text('status: fetching'), findsOneWidget);
          expect(find.text('data: placeholder data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await tester.pump(fetchDuration);

          expect(find.text('status: retrying'), findsOneWidget);
          expect(find.text('data: placeholder data'), findsOneWidget);
          expect(find.text('error: error'), findsOneWidget);

          await tester.pump(fetchDuration);

          expect(find.text('status: failure'), findsOneWidget);
          expect(find.text('data: placeholder data'), findsOneWidget);
          expect(find.text('error: error'), findsOneWidget);
        },
      );
    },
  );

  group(
    'when "retryCount" and "retryDelayDuration" are set',
    () {
      final inputs = [
        {
          'retryCount': 0,
          'retryDelayDuration': Duration.zero,
        },
        {
          'retryCount': 0,
          'retryDelayDuration': const Duration(seconds: 3),
        },
        {
          'retryCount': 1,
          'retryDelayDuration': Duration.zero,
        },
        {
          'retryCount': 1,
          'retryDelayDuration': const Duration(seconds: 3),
        },
        {
          'retryCount': 2,
          'retryDelayDuration': Duration.zero,
        },
        {
          'retryCount': 2,
          'retryDelayDuration': const Duration(seconds: 3),
        },
      ];

      for (final input in inputs) {
        final retryCount = input['retryCount'] as int;
        final retryDelayDuration = input['retryDelayDuration'] as Duration;

        testWidgets(
          'should retry $retryCount times with $retryDelayDuration delay if the initial fetching failed',
          (tester) async {
            const fetchDuration = Duration(seconds: 3);

            await tester.pumpWithQueryClientProvider(
              QueryBuilder<String>(
                id: 'id',
                fetcher: (id) async {
                  await Future.delayed(fetchDuration);
                  throw 'error';
                },
                retryCount: retryCount,
                retryDelayDuration: retryDelayDuration,
                builder: (context, state, child) {
                  return Column(
                    children: [
                      Text('status: ${state.status.name}'),
                      Text('data: ${state.data}'),
                      Text('error: ${state.error}'),
                      Text('retried: ${state.retried}'),
                    ],
                  );
                },
              ),
            );

            expect(find.text('status: fetching'), findsOneWidget);
            expect(find.text('data: null'), findsOneWidget);
            expect(find.text('error: null'), findsOneWidget);
            expect(find.text('retried: 0'), findsOneWidget);

            await tester.pump(fetchDuration);

            for (int i = 0; i < retryCount; i++) {
              expect(find.text('status: retrying'), findsOneWidget);
              expect(find.text('data: null'), findsOneWidget);
              expect(find.text('error: error'), findsOneWidget);
              expect(find.text('retried: $i'), findsOneWidget);

              await tester.pump(fetchDuration);
              await tester.pump(retryDelayDuration);
            }

            expect(find.text('status: failure'), findsOneWidget);
            expect(find.text('data: null'), findsOneWidget);
            expect(find.text('error: error'), findsOneWidget);
            expect(find.text('retried: $retryCount'), findsOneWidget);
          },
        );
      }
    },
  );

  group(
    'when the "refetchOnInit" is set',
    () {
      testWidgets(
        'should not refetch if the "refetchOnInit" is set to "RefetchMode.never"',
        (tester) async {
          final client = QueryClient()..setQueryData('id', 'cached data');
          const fetchDuration = Duration(seconds: 3);
          final widget = QueryBuilder<String>(
            id: 'id',
            fetcher: (id) async {
              await Future.delayed(fetchDuration);
              return 'data';
            },
            refetchOnInit: RefetchMode.never,
            builder: (context, state, child) {
              return Column(
                children: [
                  Text('status: ${state.status.name}'),
                  Text('data: ${state.data}'),
                  Text('error: ${state.error}'),
                ],
              );
            },
          );

          await tester.pumpWithQueryClientProvider(widget, client);

          expect(find.text('status: success'), findsOneWidget);
          expect(find.text('data: cached data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);
        },
      );

      testWidgets(
        'should refetch if the "refetchOnInit" is set to "RefecthMode.stale" and the data is stale',
        (tester) async {
          final client = QueryClient()..setQueryData('id', 'cached data');
          const staleDuration = Duration(minutes: 10);
          const fetchDuration = Duration(seconds: 3);
          final widget = QueryBuilder<String>(
            id: 'id',
            fetcher: (id) async {
              await Future.delayed(fetchDuration);
              return 'data';
            },
            staleDuration: staleDuration,
            refetchOnInit: RefetchMode.stale,
            builder: (context, state, child) {
              return Column(
                children: [
                  Text('status: ${state.status.name}'),
                  Text('data: ${state.data}'),
                  Text('error: ${state.error}'),
                ],
              );
            },
          );

          await tester.pumpWithQueryClientProvider(
            widget,
            client,
          );

          // The data is not stale yet, the query should not be fetching.
          expect(find.text('status: success'), findsOneWidget);
          expect(find.text('data: cached data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await tester.pump(staleDuration);

          await tester.pumpWidget(Placeholder());
          await tester.pumpWithQueryClientProvider(widget, client);

          // The data is stale, the query should be fetching.
          expect(find.text('status: fetching'), findsOneWidget);
          expect(find.text('data: cached data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await tester.pump(fetchDuration);

          expect(find.text('status: success'), findsOneWidget);
          expect(find.text('data: data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);
        },
      );

      testWidgets(
        'should refetch if the "refetchOnInit" is set to "RefecthMode.always"',
        (tester) async {
          final client = QueryClient()..setQueryData('id', 'cached data');
          const staleDuration = Duration(minutes: 10);
          const fetchDuration = Duration(seconds: 3);
          final widget = QueryBuilder<String>(
            id: 'id',
            fetcher: (id) async {
              await Future.delayed(fetchDuration);
              return 'data';
            },
            staleDuration: staleDuration,
            refetchOnInit: RefetchMode.always,
            builder: (context, state, child) {
              return Column(
                children: [
                  Text('status: ${state.status.name}'),
                  Text('data: ${state.data}'),
                  Text('error: ${state.error}'),
                ],
              );
            },
          );

          await tester.pumpWithQueryClientProvider(widget, client);

          // Should fetch even if the data is not stale.
          expect(find.text('status: fetching'), findsOneWidget);
          expect(find.text('data: cached data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await tester.pump(fetchDuration);

          expect(find.text('status: success'), findsOneWidget);
          expect(find.text('data: data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);
        },
      );
    },
  );

  group(
    'when the "refetchOnResumed" is set',
    () {
      testWidgets(
        'should not refetch if the "refetchOnResumed" is set to "RefetchMode.never"',
        (tester) async {
          final client = QueryClient()..setQueryData('id', 'cached data');
          const fetchDuration = Duration(seconds: 3);
          final widget = QueryBuilder<String>(
            id: 'id',
            fetcher: (id) async {
              await Future.delayed(fetchDuration);
              return 'data';
            },
            refetchOnInit: RefetchMode.never,
            refetchOnResumed: RefetchMode.never,
            builder: (context, state, child) {
              return Column(
                children: [
                  Text('status: ${state.status.name}'),
                  Text('data: ${state.data}'),
                  Text('error: ${state.error}'),
                ],
              );
            },
          );

          await tester.pumpWithQueryClientProvider(widget, client);

          tester.binding
              .handleAppLifecycleStateChanged(AppLifecycleState.resumed);

          expect(find.text('status: success'), findsOneWidget);
          expect(find.text('data: cached data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);
        },
      );

      testWidgets(
        'should refetch if the "refetchOnResumed" is set to "RefecthMode.stale" and the data is stale',
        (tester) async {
          final client = QueryClient()..setQueryData('id', 'cached data');
          const staleDuration = Duration(minutes: 10);
          const fetchDuration = Duration(seconds: 3);
          final widget = QueryBuilder<String>(
            id: 'id',
            fetcher: (id) async {
              await Future.delayed(fetchDuration);
              return 'data';
            },
            staleDuration: staleDuration,
            refetchOnInit: RefetchMode.never,
            refetchOnResumed: RefetchMode.stale,
            builder: (context, state, child) {
              return Column(
                children: [
                  Text('status: ${state.status.name}'),
                  Text('data: ${state.data}'),
                  Text('error: ${state.error}'),
                ],
              );
            },
          );

          await tester.pumpWithQueryClientProvider(widget, client);

          tester.binding
              .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          await tester.pump();

          // The data is not stale yet, the query should not be fetching.
          expect(find.text('status: success'), findsOneWidget);
          expect(find.text('data: cached data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await tester.pump(staleDuration);

          tester.binding
              .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          await tester.pump();

          // The data is stale, the query should be fetching.
          expect(find.text('status: fetching'), findsOneWidget);
          expect(find.text('data: cached data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await tester.pump(fetchDuration);

          expect(find.text('status: success'), findsOneWidget);
          expect(find.text('data: data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);
        },
      );

      testWidgets(
        'should refetch if the "refetchOnResumed" is set to "RefecthMode.always"',
        (tester) async {
          final client = QueryClient()..setQueryData('id', 'cached data');
          const staleDuration = Duration(minutes: 10);
          const fetchDuration = Duration(seconds: 3);
          final widget = QueryBuilder<String>(
            id: 'id',
            fetcher: (id) async {
              await Future.delayed(fetchDuration);
              return 'data';
            },
            staleDuration: staleDuration,
            refetchOnInit: RefetchMode.never,
            refetchOnResumed: RefetchMode.always,
            builder: (context, state, child) {
              return Column(
                children: [
                  Text('status: ${state.status.name}'),
                  Text('data: ${state.data}'),
                  Text('error: ${state.error}'),
                ],
              );
            },
          );

          await tester.pumpWithQueryClientProvider(widget, client);

          tester.binding
              .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          await tester.pump();

          // Should fetch even if the data is not stale.
          expect(find.text('status: fetching'), findsOneWidget);
          expect(find.text('data: cached data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await tester.pump(fetchDuration);

          expect(find.text('status: success'), findsOneWidget);
          expect(find.text('data: data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);
        },
      );
    },
  );
}
