import 'dart:math';

import 'package:clock/clock.dart';
import 'package:fluery/fluery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget withQueryClientProvider(Widget? widget, [QueryClient? client]) {
  if (client != null) {
    return QueryClientProvider.value(
      key: Key('query_client_provider'),
      value: client,
      child: widget ?? const Placeholder(),
    );
  } else {
    return QueryClientProvider(
      key: Key('query_client_provider'),
      create: (context) => QueryClient(),
      child: widget ?? const Placeholder(),
    );
  }
}

void main() {
  testWidgets(
    'should succeed',
    (tester) async {
      const fetchDuration = Duration(seconds: 3);
      final widget = QueryBuilder(
        id: 'id',
        fetcher: (id) async {
          await Future.delayed(fetchDuration);
          return 'data';
        },
        builder: (context, state, child) {
          return Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              children: [
                Text('status: ${state.status.name}'),
                Text('data: ${state.data}'),
                Text('error: ${state.error}'),
              ],
            ),
          );
        },
      );

      await tester.pumpWidget(withQueryClientProvider(widget));

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
      final widget = QueryBuilder<String>(
        id: 'id',
        fetcher: (id) async {
          await Future.delayed(fetchDuration);
          throw TestException('error');
        },
        retryMaxAttempts: 0,
        builder: (context, state, child) {
          return Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              children: [
                Text('status: ${state.status.name}'),
                Text('data: ${state.data}'),
                Text('error: ${state.error}'),
              ],
            ),
          );
        },
      );

      await tester.pumpWidget(withQueryClientProvider(widget));

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
      const staleDuration = Duration(minutes: 10);
      const fetchDuration = Duration(seconds: 3);
      final client = QueryClient()..setQueryData('id', 'cached data');
      final widget = QueryBuilder<String>(
        key: Key('query_builder'),
        id: 'id',
        fetcher: (id) async {
          await Future.delayed(fetchDuration);
          return 'data';
        },
        staleDuration: staleDuration,
        builder: (context, state, child) {
          return Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              children: [
                Text('status: ${state.status.name}'),
                Text('data: ${state.data}'),
                Text('error: ${state.error}'),
              ],
            ),
          );
        },
      );

      await tester.pumpWidget(withQueryClientProvider(widget, client));

      // Should show the cached query since the query is still fresh.
      expect(find.text('status: success'), findsOneWidget);
      expect(find.text('data: cached data'), findsOneWidget);
      expect(find.text('error: null'), findsOneWidget);

      await tester.pump(staleDuration);

      // The widget is initialized again.
      await tester.pumpWidget(withQueryClientProvider(null, client));
      await tester.pumpWidget(withQueryClientProvider(widget, client));

      // Should start fetching since now the query is stale.
      expect(find.text('status: fetching'), findsOneWidget);
      expect(find.text('data: cached data'), findsOneWidget);
      expect(find.text('error: null'), findsOneWidget);

      await tester.pump(fetchDuration);

      expect(find.text('status: success'), findsOneWidget);
      expect(find.text('data: data'), findsOneWidget);
      expect(find.text('error: null'), findsOneWidget);

      await client.close();
    },
  );

  group(
    'when the "id" is changed',
    () {
      testWidgets(
        'should fetch if a cached query with the new "id" does not exist',
        (tester) async {
          const fetchDuration = Duration(seconds: 3);
          final widget = QueryBuilder<String>(
            key: Key('query_builder'),
            id: 'id1',
            fetcher: (id) async {
              await Future.delayed(fetchDuration);
              return 'data1';
            },
            builder: (context, state, child) {
              return Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  children: [
                    Text('status: ${state.status.name}'),
                    Text('data: ${state.data}'),
                    Text('error: ${state.error}'),
                  ],
                ),
              );
            },
          );

          await tester.pumpWidget(withQueryClientProvider(
            widget.copyWith(
              id: 'id1',
              fetcher: (id) async {
                await Future.delayed(fetchDuration);
                return 'data1';
              },
            ),
          ));

          expect(find.text('status: fetching'), findsOneWidget);
          expect(find.text('data: null'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await tester.pump(fetchDuration);

          expect(find.text('status: success'), findsOneWidget);
          expect(find.text('data: data1'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await tester.pumpWidget(withQueryClientProvider(
            widget.copyWith(
              id: 'id2',
              fetcher: (id) async {
                await Future.delayed(fetchDuration);
                return 'data2';
              },
            ),
          ));

          expect(find.text('status: fetching'), findsOneWidget);
          expect(find.text('data: null'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await tester.pump(fetchDuration);

          expect(find.text('status: success'), findsOneWidget);
          expect(find.text('data: data2'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);
        },
      );

      testWidgets(
        'should not refetch if a cached query with the new "id" exists and the "refetchOnInit" is set to "RefetchMode.never"',
        (tester) async {
          const fetchDuration = Duration(seconds: 3);
          final client = QueryClient()..setQueryData('id2', 'cached data2');
          final widget = QueryBuilder<String>(
            id: 'id1',
            fetcher: (id) async {
              await Future.delayed(fetchDuration);
              return 'data1';
            },
            refetchOnInit: RefetchMode.never,
            builder: (context, state, child) {
              return Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  children: [
                    Text('status: ${state.status.name}'),
                    Text('data: ${state.data}'),
                    Text('error: ${state.error}'),
                  ],
                ),
              );
            },
          );

          await tester.pumpWidget(withQueryClientProvider(
            widget.copyWith(
              id: 'id1',
              fetcher: (id) async {
                await Future.delayed(fetchDuration);
                return 'data1';
              },
            ),
            client,
          ));

          expect(find.text('status: fetching'), findsOneWidget);
          expect(find.text('data: null'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await tester.pump(fetchDuration);

          expect(find.text('status: success'), findsOneWidget);
          expect(find.text('data: data1'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await tester.pumpWidget(withQueryClientProvider(
            widget.copyWith(
              id: 'id2',
              fetcher: (id) async {
                await Future.delayed(fetchDuration);
                return 'data2';
              },
            ),
            client,
          ));

          expect(find.text('status: success'), findsOneWidget);
          expect(find.text('data: cached data2'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await client.close();
        },
      );

      testWidgets(
        'should refetch if a stale cached query with the new "id" exists and the "refetchOnInit" is set to "RefetchMode.stale"',
        (tester) async {
          const staleDuration = Duration(minutes: 10);
          const fetchDuration = Duration(seconds: 3);
          final client = QueryClient()..setQueryData('id2', 'cached data2');
          final widget = QueryBuilder<String>(
            id: 'id1',
            fetcher: (id) async {
              await Future.delayed(fetchDuration);
              return 'data1';
            },
            staleDuration: staleDuration,
            refetchOnInit: RefetchMode.stale,
            builder: (context, state, child) {
              return Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  children: [
                    Text('status: ${state.status.name}'),
                    Text('data: ${state.data}'),
                    Text('error: ${state.error}'),
                  ],
                ),
              );
            },
          );

          await tester.pumpWidget(withQueryClientProvider(
            widget.copyWith(
              id: 'id1',
              fetcher: (id) async {
                await Future.delayed(fetchDuration);
                return 'data1';
              },
            ),
            client,
          ));

          expect(find.text('status: fetching'), findsOneWidget);
          expect(find.text('data: null'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await tester.pump(fetchDuration);

          expect(find.text('status: success'), findsOneWidget);
          expect(find.text('data: data1'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await tester.pumpWidget(withQueryClientProvider(
            widget.copyWith(
              id: 'id2',
              fetcher: (id) async {
                await Future.delayed(fetchDuration);
                return 'data2';
              },
            ),
            client,
          ));

          // The data is not stale yet, it should not refetch.
          expect(find.text('status: success'), findsOneWidget);
          expect(find.text('data: cached data2'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await tester.pump(staleDuration);

          await tester.pumpWidget(withQueryClientProvider(
            widget.copyWith(
              id: 'id1',
              fetcher: (id) async {
                await Future.delayed(fetchDuration);
                return 'data1';
              },
            ),
            client,
          ));
          await tester.pumpWidget(withQueryClientProvider(
            widget.copyWith(
              id: 'id2',
              fetcher: (id) async {
                await Future.delayed(fetchDuration);
                return 'data2';
              },
            ),
            client,
          ));

          expect(find.text('status: fetching'), findsOneWidget);
          expect(find.text('data: cached data2'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await tester.pump(fetchDuration);

          expect(find.text('status: success'), findsOneWidget);
          expect(find.text('data: data2'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await client.close();
        },
      );

      testWidgets(
        'should refetch if a cached query with the new "id" exists and the "refetchOnInit" is set to "RefetchMode.always"',
        (tester) async {
          const fetchDuration = Duration(seconds: 3);
          final client = QueryClient()..setQueryData('id2', 'cached data2');
          final widget = QueryBuilder<String>(
            id: 'id1',
            fetcher: (id) async {
              await Future.delayed(fetchDuration);
              return 'data1';
            },
            refetchOnInit: RefetchMode.always,
            builder: (context, state, child) {
              return Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  children: [
                    Text('status: ${state.status.name}'),
                    Text('data: ${state.data}'),
                    Text('error: ${state.error}'),
                  ],
                ),
              );
            },
          );

          await tester.pumpWidget(withQueryClientProvider(
            widget.copyWith(
              id: 'id1',
              fetcher: (id) async {
                await Future.delayed(fetchDuration);
                return 'data1';
              },
            ),
            client,
          ));

          expect(find.text('status: fetching'), findsOneWidget);
          expect(find.text('data: null'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await tester.pump(fetchDuration);

          expect(find.text('status: success'), findsOneWidget);
          expect(find.text('data: data1'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await tester.pumpWidget(withQueryClientProvider(
            widget.copyWith(
              id: 'id2',
              fetcher: (id) async {
                await Future.delayed(fetchDuration);
                return 'data2';
              },
            ),
            client,
          ));

          expect(find.text('status: fetching'), findsOneWidget);
          expect(find.text('data: cached data2'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await tester.pump(fetchDuration);

          expect(find.text('status: success'), findsOneWidget);
          expect(find.text('data: data2'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await client.close();
        },
      );
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
              return Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  children: [
                    Text('status: ${state.status.name}'),
                    Text('data: ${state.data}'),
                    Text('error: ${state.error}'),
                  ],
                ),
              );
            },
          );

          await tester.pumpWidget(withQueryClientProvider(widget));

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
              return Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  children: [
                    Text('status: ${state.status.name}'),
                    Text('data: ${state.data}'),
                    Text('error: ${state.error}'),
                  ],
                ),
              );
            },
          );

          await tester.pumpWidget(withQueryClientProvider(widget, client));

          expect(find.text('status: success'), findsOneWidget);
          expect(find.text('data: cached data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await client.close();
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
                return Directionality(
                  textDirection: TextDirection.ltr,
                  child: Column(
                    children: [
                      Text('status: ${state.status.name}'),
                      Text('data: ${state.data}'),
                      Text('error: ${state.error}'),
                    ],
                  ),
                );
              },
            );

            await tester.pumpWidget(withQueryClientProvider(widget, client));

            expect(find.text('status: success'), findsOneWidget);
            expect(find.text('data: cached data'), findsOneWidget);
            expect(find.text('error: null'), findsOneWidget);

            await client.close();
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
                return Directionality(
                  textDirection: TextDirection.ltr,
                  child: Column(
                    children: [
                      Text('status: ${state.status.name}'),
                      Text('data: ${state.data}'),
                      Text('error: ${state.error}'),
                    ],
                  ),
                );
              },
            );

            await tester.pumpWidget(withQueryClientProvider(widget, client));

            tester.binding
                .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
            await tester.pump();

            expect(find.text('status: success'), findsOneWidget);
            expect(find.text('data: cached data'), findsOneWidget);
            expect(find.text('error: null'), findsOneWidget);

            await client.close();
          }
        },
      );

      testWidgets(
        'should not refetch on intervals even if the "refetchIntervalDuration" is set',
        (tester) async {
          const refetchIntervalDuration = Duration(seconds: 3);
          final client = QueryClient()..setQueryData('id', 'cached data');
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
              return Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  children: [
                    Text('status: ${state.status.name}'),
                    Text('data: ${state.data}'),
                    Text('error: ${state.error}'),
                  ],
                ),
              );
            },
          );

          await tester.pumpWidget(withQueryClientProvider(widget, client));

          for (int i = 0; i < 5; i++) {
            expect(find.text('status: success'), findsOneWidget);
            expect(find.text('data: cached data'), findsOneWidget);
            expect(find.text('error: null'), findsOneWidget);

            await tester.pump(refetchIntervalDuration);
          }

          await client.close();
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
              return Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  children: [
                    Text('status: ${state.status.name}'),
                    Text('data: ${state.data}'),
                    Text('error: ${state.error}'),
                  ],
                ),
              );
            },
          );

          await tester.pumpWidget(withQueryClientProvider(
            widget.copyWith(enabled: false),
          ));
          await tester.pumpWidget(withQueryClientProvider(
            widget.copyWith(enabled: true),
          ));

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
          const fetchDuration = Duration(seconds: 3);
          final client = QueryClient()..setQueryData('id', 'cached data');
          final widget = QueryBuilder<String>(
            id: 'id',
            fetcher: (id) async {
              await Future.delayed(fetchDuration);
              return 'data';
            },
            enabled: false,
            refetchOnInit: RefetchMode.never,
            builder: (context, state, child) {
              return Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  children: [
                    Text('status: ${state.status.name}'),
                    Text('data: ${state.data}'),
                    Text('error: ${state.error}'),
                  ],
                ),
              );
            },
          );

          await tester.pumpWidget(withQueryClientProvider(
            widget.copyWith(enabled: false),
            client,
          ));
          await tester.pumpWidget(withQueryClientProvider(
            widget.copyWith(enabled: true),
            client,
          ));

          expect(find.text('status: success'), findsOneWidget);
          expect(find.text('data: cached data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await client.close();
        },
      );

      testWidgets(
        'should refetch if the "refetchOnInit" is set to "RefecthMode.stale" and the data is stale',
        (tester) async {
          const fetchDuration = Duration(seconds: 3);
          const staleDuration = Duration(minutes: 10);
          final client = QueryClient()..setQueryData('id', 'cached data');
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
              return Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  children: [
                    Text('status: ${state.status.name}'),
                    Text('data: ${state.data}'),
                    Text('error: ${state.error}'),
                  ],
                ),
              );
            },
          );

          await tester.pumpWidget(withQueryClientProvider(
            widget.copyWith(enabled: false),
            client,
          ));
          await tester.pumpWidget(withQueryClientProvider(
            widget.copyWith(enabled: true),
            client,
          ));

          // The data is not stale yet, the query should not be fetching.
          expect(find.text('status: success'), findsOneWidget);
          expect(find.text('data: cached data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await tester.pump(staleDuration);
          await tester.pumpWidget(withQueryClientProvider(
            widget.copyWith(enabled: false),
            client,
          ));
          await tester.pumpWidget(withQueryClientProvider(
            widget.copyWith(enabled: true),
            client,
          ));

          // The data is stale, the query should be fetching.
          expect(find.text('status: fetching'), findsOneWidget);
          expect(find.text('data: cached data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await tester.pump(fetchDuration);

          expect(find.text('status: success'), findsOneWidget);
          expect(find.text('data: data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await client.close();
        },
      );

      testWidgets(
        'should refetch if the "refetchOnInit" is set to "RefecthMode.always"',
        (tester) async {
          const fetchDuration = Duration(seconds: 3);
          final client = QueryClient()..setQueryData('id', 'cached data');
          final widget = QueryBuilder<String>(
            key: Key('query_builder'),
            id: 'id',
            fetcher: (id) async {
              await Future.delayed(fetchDuration);
              return 'data';
            },
            enabled: false,
            refetchOnInit: RefetchMode.always,
            builder: (context, state, child) {
              return Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  children: [
                    Text('status: ${state.status.name}'),
                    Text('data: ${state.data}'),
                    Text('error: ${state.error}'),
                  ],
                ),
              );
            },
          );

          await tester.pumpWidget(withQueryClientProvider(
            widget.copyWith(enabled: false),
            client,
          ));
          await tester.pumpWidget(withQueryClientProvider(
            widget.copyWith(enabled: true),
            client,
          ));

          expect(find.text('status: fetching'), findsOneWidget);
          expect(find.text('data: cached data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await tester.pump(fetchDuration);

          expect(find.text('status: success'), findsOneWidget);
          expect(find.text('data: data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await client.close();
        },
      );
    },
  );

  group(
    'when the "initialData" is set',
    () {
      testWidgets(
        'should set the "initialData" if the query has no data',
        (tester) async {
          const fetchDuration = Duration(seconds: 3);
          final widget = QueryBuilder<String>(
            id: 'id',
            fetcher: (id) async {
              await Future.delayed(fetchDuration);
              return 'data';
            },
            initialData: 'initial data',
            builder: (context, state, child) {
              return Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  children: [
                    Text('status: ${state.status.name}'),
                    Text('data: ${state.data}'),
                    Text('error: ${state.error}'),
                  ],
                ),
              );
            },
          );

          await tester.pumpWidget(withQueryClientProvider(widget));

          expect(find.text('status: fetching'), findsOneWidget);
          expect(find.text('data: initial data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await tester.pump(fetchDuration);

          expect(find.text('status: success'), findsOneWidget);
          expect(find.text('data: data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);
        },
      );

      testWidgets(
        'should not set the "initialData" if the query alreay has data',
        (tester) async {
          const fetchDuration = Duration(seconds: 3);
          final client = QueryClient()..setQueryData('id', 'cached data');
          final widget = QueryBuilder<String>(
            id: 'id',
            fetcher: (id) async {
              await Future.delayed(fetchDuration);
              return 'data';
            },
            initialData: 'initial data',
            builder: (context, state, child) {
              return Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  children: [
                    Text('status: ${state.status.name}'),
                    Text('data: ${state.data}'),
                    Text('error: ${state.error}'),
                  ],
                ),
              );
            },
          );

          await tester.pumpWidget(withQueryClientProvider(widget, client));

          expect(find.text('status: fetching'), findsOneWidget);
          expect(find.text('data: cached data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await tester.pump(fetchDuration);

          expect(find.text('status: success'), findsOneWidget);
          expect(find.text('data: data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await client.close();
        },
      );

      testWidgets(
        'should set the "initialData" if the "initialData" is fresher than the cached one',
        (tester) async {
          const fetchDuration = Duration(seconds: 3);
          final client = QueryClient()
            ..setQueryData(
              'id',
              'cached data',
              clock.ago(minutes: 5),
            );
          final widget = QueryBuilder<String>(
            id: 'id',
            fetcher: (id) async {
              await Future.delayed(fetchDuration);
              return 'data';
            },
            initialData: 'initial data',
            initialDataUpdatedAt: clock.ago(minutes: 2),
            builder: (context, state, child) {
              return Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  children: [
                    Text('status: ${state.status.name}'),
                    Text('data: ${state.data}'),
                    Text('error: ${state.error}'),
                  ],
                ),
              );
            },
          );

          await tester.pumpWidget(withQueryClientProvider(widget, client));

          expect(find.text('status: fetching'), findsOneWidget);
          expect(find.text('data: initial data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await tester.pump(fetchDuration);

          expect(find.text('status: success'), findsOneWidget);
          expect(find.text('data: data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await client.close();
        },
      );
    },
  );

  group(
    'when the "cacheDuration" is set',
    () {
      testWidgets(
        'should schedule garbage collection if there is no "QueryBuilder"',
        (tester) async {
          const cacheDuration = Duration(minutes: 5);
          final client = QueryClient();
          final widget = QueryBuilder(
            id: 'id',
            fetcher: (id) async {
              return 'data';
            },
            cacheDuration: cacheDuration,
            builder: (context, state, child) {
              return Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  children: [
                    Text('status: ${state.status.name}'),
                    Text('data: ${state.data}'),
                    Text('error: ${state.error}'),
                  ],
                ),
              );
            },
          );

          await tester.pumpWidget(withQueryClientProvider(widget, client));

          expect(client.cache.exist('id'), isTrue);

          await tester.pumpWidget(withQueryClientProvider(null, client));

          expect(client.cache.exist('id'), isTrue);

          await tester.pump(cacheDuration);

          expect(client.cache.exist('id'), isFalse);

          await client.close();
        },
      );

      testWidgets(
        'should cancel the garbage collection if a "QueryBuilder" reappears',
        (tester) async {
          const cacheDuration = Duration(minutes: 5);
          final client = QueryClient();
          final widget = QueryBuilder(
            id: 'id',
            fetcher: (id) async {
              return 'data';
            },
            cacheDuration: cacheDuration,
            builder: (context, state, child) {
              return Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  children: [
                    Text('status: ${state.status.name}'),
                    Text('data: ${state.data}'),
                    Text('error: ${state.error}'),
                  ],
                ),
              );
            },
          );

          await tester.pumpWidget(withQueryClientProvider(widget, client));

          expect(client.cache.exist('id'), isTrue);

          await tester.pumpWidget(withQueryClientProvider(null, client));

          expect(client.cache.exist('id'), isTrue);

          await tester.pumpWidget(withQueryClientProvider(widget, client));

          expect(client.cache.exist('id'), isTrue);

          await tester.pump(cacheDuration);

          expect(client.cache.exist('id'), isTrue);

          await client.close();
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
              return Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  children: [
                    Text('status: ${state.status.name}'),
                    Text('data: ${state.data}'),
                    Text('error: ${state.error}'),
                  ],
                ),
              );
            },
          );

          // Tests success case.
          await tester.pumpWidget(withQueryClientProvider(widget));

          expect(find.text('status: fetching'), findsOneWidget);
          expect(find.text('data: placeholder data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await tester.pump(fetchDuration);

          expect(find.text('status: success'), findsOneWidget);
          expect(find.text('data: data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          // Tests failure case.
          await tester.pumpWidget(const Placeholder());
          await tester.pumpWidget(withQueryClientProvider(
            widget.copyWith(
              fetcher: (id) async {
                await Future.delayed(fetchDuration);
                throw TestException('error');
              },
              retryMaxAttempts: 1,
            ),
          ));

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
    'when the retry properties are set',
    () {
      final inputs = [
        {
          'retryMaxAttempts': 0,
          'retryDelayFactor': Duration.zero,
        },
        {
          'retryMaxAttempts': 0,
          'retryDelayFactor': const Duration(milliseconds: 200),
        },
        {
          'retryMaxAttempts': 1,
          'retryDelayFactor': Duration.zero,
        },
        {
          'retryMaxAttempts': 1,
          'retryDelayFactor': const Duration(milliseconds: 200),
        },
        {
          'retryMaxAttempts': 2,
          'retryDelayFactor': Duration.zero,
        },
        {
          'retryMaxAttempts': 2,
          'retryDelayFactor': const Duration(seconds: 3),
        },
      ];

      for (final input in inputs) {
        final retryMaxAttempts = input['retryMaxAttempts'] as int;
        final retryDelayFactor = input['retryDelayFactor'] as Duration;

        testWidgets(
          'should retry $retryMaxAttempts times with the $retryDelayFactor delay factor',
          (tester) async {
            const fetchDuration = Duration(seconds: 3);
            final widget = QueryBuilder<String>(
              id: 'id',
              fetcher: (id) async {
                await Future.delayed(fetchDuration);
                throw TestException('error');
              },
              retryMaxAttempts: retryMaxAttempts,
              retryDelayFactor: retryDelayFactor,
              retryRandomizationFactor: 0.0,
              builder: (context, state, child) {
                return Directionality(
                  textDirection: TextDirection.ltr,
                  child: Column(
                    children: [
                      Text('status: ${state.status.name}'),
                      Text('data: ${state.data}'),
                      Text('error: ${state.error}'),
                    ],
                  ),
                );
              },
            );

            await tester.pumpWidget(withQueryClientProvider(widget));

            expect(find.text('status: fetching'), findsOneWidget);
            expect(find.text('data: null'), findsOneWidget);
            expect(find.text('error: null'), findsOneWidget);

            await tester.pump(fetchDuration);

            for (int i = 1; i <= retryMaxAttempts; i++) {
              expect(find.text('status: retrying'), findsOneWidget);
              expect(find.text('data: null'), findsOneWidget);
              expect(find.text('error: error'), findsOneWidget);

              await tester.pump(fetchDuration);
              await tester.pump(retryDelayFactor * pow(2, i));
            }

            expect(find.text('status: failure'), findsOneWidget);
            expect(find.text('data: null'), findsOneWidget);
            expect(find.text('error: error'), findsOneWidget);
          },
        );
      }

      testWidgets(
        'should not retry if the "retryWhen" returns "false"',
        (tester) async {
          const fetchDuration = Duration(seconds: 3);
          final widget = QueryBuilder<String>(
            id: 'id',
            fetcher: (id) async {
              await Future.delayed(fetchDuration);
              throw TestException('error');
            },
            retryWhen: (e) => false,
            retryMaxAttempts: 3,
            builder: (context, state, child) {
              return Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  children: [
                    Text('status: ${state.status.name}'),
                    Text('data: ${state.data}'),
                    Text('error: ${state.error}'),
                  ],
                ),
              );
            },
          );

          await tester.pumpWidget(withQueryClientProvider(widget));

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
        'should retry once if the "retryWhen" returns "false" after the first retry',
        (tester) async {
          int attempts = 0;
          const fetchDuration = Duration(seconds: 3);
          final widget = QueryBuilder<String>(
            id: 'id',
            fetcher: (id) async {
              await Future.delayed(fetchDuration);
              attempts++;
              if (attempts == 1) {
                throw TestException('error1');
              } else {
                throw TestException('error');
              }
            },
            retryWhen: (e) {
              if (e is TestException) {
                return e.message == 'error1';
              } else {
                return false;
              }
            },
            retryMaxAttempts: 3,
            builder: (context, state, child) {
              return Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  children: [
                    Text('status: ${state.status.name}'),
                    Text('data: ${state.data}'),
                    Text('error: ${state.error}'),
                  ],
                ),
              );
            },
          );

          await tester.pumpWidget(withQueryClientProvider(widget));

          expect(find.text('status: fetching'), findsOneWidget);
          expect(find.text('data: null'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await tester.pump(fetchDuration);

          expect(find.text('status: retrying'), findsOneWidget);
          expect(find.text('data: null'), findsOneWidget);
          expect(find.text('error: error1'), findsOneWidget);

          await tester.pump(fetchDuration);

          expect(find.text('status: failure'), findsOneWidget);
          expect(find.text('data: null'), findsOneWidget);
          expect(find.text('error: error'), findsOneWidget);
        },
      );
    },
  );

  group(
    'when the "refetchOnInit" is set',
    () {
      testWidgets(
        'should not refetch if the "refetchOnInit" is set to "RefetchMode.never"',
        (tester) async {
          const fetchDuration = Duration(seconds: 3);
          final client = QueryClient()..setQueryData('id', 'cached data');
          final widget = QueryBuilder<String>(
            id: 'id',
            fetcher: (id) async {
              await Future.delayed(fetchDuration);
              return 'data';
            },
            refetchOnInit: RefetchMode.never,
            builder: (context, state, child) {
              return Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  children: [
                    Text('status: ${state.status.name}'),
                    Text('data: ${state.data}'),
                    Text('error: ${state.error}'),
                  ],
                ),
              );
            },
          );

          await tester.pumpWidget(withQueryClientProvider(widget, client));

          expect(find.text('status: success'), findsOneWidget);
          expect(find.text('data: cached data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await client.close();
        },
      );

      testWidgets(
        'should refetch if the "refetchOnInit" is set to "RefecthMode.stale" and the data is stale',
        (tester) async {
          const fetchDuration = Duration(seconds: 3);
          const staleDuration = Duration(minutes: 10);
          final client = QueryClient()..setQueryData('id', 'cached data');
          final widget = QueryBuilder<String>(
            id: 'id',
            fetcher: (id) async {
              await Future.delayed(fetchDuration);
              return 'data';
            },
            staleDuration: staleDuration,
            refetchOnInit: RefetchMode.stale,
            builder: (context, state, child) {
              return Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  children: [
                    Text('status: ${state.status.name}'),
                    Text('data: ${state.data}'),
                    Text('error: ${state.error}'),
                  ],
                ),
              );
            },
          );

          await tester.pumpWidget(withQueryClientProvider(widget, client));

          // The data is not stale yet, the query should not be fetching.
          expect(find.text('status: success'), findsOneWidget);
          expect(find.text('data: cached data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await tester.pump(staleDuration);

          await tester.pumpWidget(withQueryClientProvider(null, client));
          await tester.pumpWidget(withQueryClientProvider(widget, client));

          // The data is stale, the query should be fetching.
          expect(find.text('status: fetching'), findsOneWidget);
          expect(find.text('data: cached data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await tester.pump(fetchDuration);

          expect(find.text('status: success'), findsOneWidget);
          expect(find.text('data: data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await client.close();
        },
      );

      testWidgets(
        'should refetch if the "refetchOnInit" is set to "RefecthMode.always"',
        (tester) async {
          const fetchDuration = Duration(seconds: 3);
          const staleDuration = Duration(minutes: 10);
          final client = QueryClient()..setQueryData('id', 'cached data');
          final widget = QueryBuilder<String>(
            id: 'id',
            fetcher: (id) async {
              await Future.delayed(fetchDuration);
              return 'data';
            },
            staleDuration: staleDuration,
            refetchOnInit: RefetchMode.always,
            builder: (context, state, child) {
              return Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  children: [
                    Text('status: ${state.status.name}'),
                    Text('data: ${state.data}'),
                    Text('error: ${state.error}'),
                  ],
                ),
              );
            },
          );

          await tester.pumpWidget(withQueryClientProvider(widget, client));

          // Should fetch even if the data is not stale.
          expect(find.text('status: fetching'), findsOneWidget);
          expect(find.text('data: cached data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await tester.pump(fetchDuration);

          expect(find.text('status: success'), findsOneWidget);
          expect(find.text('data: data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await client.close();
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
          const fetchDuration = Duration(seconds: 3);
          final client = QueryClient()..setQueryData('id', 'cached data');
          final widget = QueryBuilder<String>(
            id: 'id',
            fetcher: (id) async {
              await Future.delayed(fetchDuration);
              return 'data';
            },
            refetchOnInit: RefetchMode.never,
            refetchOnResumed: RefetchMode.never,
            builder: (context, state, child) {
              return Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  children: [
                    Text('status: ${state.status.name}'),
                    Text('data: ${state.data}'),
                    Text('error: ${state.error}'),
                  ],
                ),
              );
            },
          );

          await tester.pumpWidget(withQueryClientProvider(widget, client));

          tester.binding
              .handleAppLifecycleStateChanged(AppLifecycleState.resumed);

          expect(find.text('status: success'), findsOneWidget);
          expect(find.text('data: cached data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await client.close();
        },
      );

      testWidgets(
        'should refetch if the "refetchOnResumed" is set to "RefecthMode.stale" and the data is stale',
        (tester) async {
          const fetchDuration = Duration(seconds: 3);
          const staleDuration = Duration(minutes: 10);
          final client = QueryClient()..setQueryData('id', 'cached data');
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
              return Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  children: [
                    Text('status: ${state.status.name}'),
                    Text('data: ${state.data}'),
                    Text('error: ${state.error}'),
                  ],
                ),
              );
            },
          );

          await tester.pumpWidget(withQueryClientProvider(widget, client));

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

          await client.close();
        },
      );

      testWidgets(
        'should refetch if the "refetchOnResumed" is set to "RefecthMode.always"',
        (tester) async {
          const fetchDuration = Duration(seconds: 3);
          const staleDuration = Duration(minutes: 10);
          final client = QueryClient()..setQueryData('id', 'cached data');
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
              return Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  children: [
                    Text('status: ${state.status.name}'),
                    Text('data: ${state.data}'),
                    Text('error: ${state.error}'),
                  ],
                ),
              );
            },
          );

          await tester.pumpWidget(withQueryClientProvider(widget, client));

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

          await client.close();
        },
      );
    },
  );

  group(
    'when the "refetchIntervalDuration" is set',
    () {
      testWidgets(
        'should refetch on intervals',
        (tester) async {
          const fetchDuration = Duration(seconds: 3);
          const refetchIntervalDuration = Duration(seconds: 10);
          final widget = QueryBuilder(
            id: 'id',
            fetcher: (id) async {
              await Future.delayed(fetchDuration);
              return 'data';
            },
            refetchIntervalDuration: refetchIntervalDuration,
            builder: (context, state, child) {
              return Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  children: [
                    Text('status: ${state.status.name}'),
                    Text('data: ${state.data}'),
                    Text('error: ${state.error}'),
                  ],
                ),
              );
            },
          );

          await tester.pumpWidget(withQueryClientProvider(widget));

          expect(find.text('status: fetching'), findsOneWidget);
          expect(find.text('data: null'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await tester.pump(fetchDuration);

          expect(find.text('status: success'), findsOneWidget);
          expect(find.text('data: data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          for (int i = 0; i < 10; i++) {
            await tester.pump(refetchIntervalDuration);

            expect(find.text('status: fetching'), findsOneWidget);
            expect(find.text('data: data'), findsOneWidget);
            expect(find.text('error: null'), findsOneWidget);

            await tester.pump(fetchDuration);

            expect(find.text('status: success'), findsOneWidget);
            expect(find.text('data: data'), findsOneWidget);
            expect(find.text('error: null'), findsOneWidget);
          }
        },
      );

      testWidgets(
        'should reschedule refetch when the "refetchIntervalDuration" is changed',
        (tester) async {
          const fetchDuration = Duration(seconds: 3);
          const refetchIntervalDuration1 = Duration(seconds: 7);
          const refetchIntervalDuration2 = Duration(seconds: 17);
          final widget = QueryBuilder(
            id: 'id',
            fetcher: (id) async {
              await Future.delayed(fetchDuration);
              return 'data';
            },
            builder: (context, state, child) {
              return Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  children: [
                    Text('status: ${state.status.name}'),
                    Text('data: ${state.data}'),
                    Text('error: ${state.error}'),
                  ],
                ),
              );
            },
          );

          await tester.pumpWidget(withQueryClientProvider(
            widget.copyWith(refetchIntervalDuration: refetchIntervalDuration1),
          ));

          expect(find.text('status: fetching'), findsOneWidget);
          expect(find.text('data: null'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await tester.pump(fetchDuration);

          expect(find.text('status: success'), findsOneWidget);
          expect(find.text('data: data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          for (int i = 0; i < 10; i++) {
            await tester.pump(refetchIntervalDuration1);

            expect(find.text('status: fetching'), findsOneWidget);
            expect(find.text('data: data'), findsOneWidget);
            expect(find.text('error: null'), findsOneWidget);

            await tester.pump(fetchDuration);

            expect(find.text('status: success'), findsOneWidget);
            expect(find.text('data: data'), findsOneWidget);
            expect(find.text('error: null'), findsOneWidget);
          }

          await tester.pump(const Duration(seconds: 5));

          await tester.pumpWidget(withQueryClientProvider(
            widget.copyWith(refetchIntervalDuration: refetchIntervalDuration2),
          ));

          expect(find.text('status: success'), findsOneWidget);
          expect(find.text('data: data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await tester.pump(const Duration(seconds: 12));

          expect(find.text('status: fetching'), findsOneWidget);
          expect(find.text('data: data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await tester.pump(fetchDuration);

          expect(find.text('status: success'), findsOneWidget);
          expect(find.text('data: data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          for (int i = 0; i < 10; i++) {
            await tester.pump(refetchIntervalDuration2);

            expect(find.text('status: fetching'), findsOneWidget);
            expect(find.text('data: data'), findsOneWidget);
            expect(find.text('error: null'), findsOneWidget);

            await tester.pump(fetchDuration);

            expect(find.text('status: success'), findsOneWidget);
            expect(find.text('data: data'), findsOneWidget);
            expect(find.text('error: null'), findsOneWidget);
          }

          await tester.pump(const Duration(seconds: 12));

          expect(find.text('status: success'), findsOneWidget);
          expect(find.text('data: data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await tester.pumpWidget(withQueryClientProvider(
            widget.copyWith(refetchIntervalDuration: refetchIntervalDuration1),
          ));

          expect(find.text('status: fetching'), findsOneWidget);
          expect(find.text('data: data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await tester.pump(fetchDuration);

          expect(find.text('status: success'), findsOneWidget);
          expect(find.text('data: data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          for (int i = 0; i < 10; i++) {
            await tester.pump(refetchIntervalDuration1);

            expect(find.text('status: fetching'), findsOneWidget);
            expect(find.text('data: data'), findsOneWidget);
            expect(find.text('error: null'), findsOneWidget);

            await tester.pump(fetchDuration);

            expect(find.text('status: success'), findsOneWidget);
            expect(find.text('data: data'), findsOneWidget);
            expect(find.text('error: null'), findsOneWidget);
          }
        },
      );

      testWidgets(
        'should refetch on the shortest intervals if there are two instances with the "refetchIntervalDuration" is set',
        (tester) async {
          const fetchDuration = Duration(seconds: 3);
          const shortestRefetchIntervalDuration = Duration(seconds: 7);
          const longestRefetchIntervalDuration = Duration(seconds: 17);
          final widget = QueryBuilder<String>(
            id: 'id',
            fetcher: (id) async {
              await Future.delayed(fetchDuration);
              return 'data';
            },
            builder: (context, state, child) {
              return Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  children: [
                    Text('status: ${state.status.name}'),
                    Text('data: ${state.data}'),
                    Text('error: ${state.error}'),
                  ],
                ),
              );
            },
          );

          await tester.pumpWidget(withQueryClientProvider(
            Column(
              children: [
                widget.copyWith(
                  refetchIntervalDuration: shortestRefetchIntervalDuration,
                ),
                widget.copyWith(
                  refetchIntervalDuration: longestRefetchIntervalDuration,
                ),
              ],
            ),
          ));

          expect(find.text('status: fetching'), findsNWidgets(2));
          expect(find.text('data: null'), findsNWidgets(2));
          expect(find.text('error: null'), findsNWidgets(2));

          await tester.pump(fetchDuration);

          expect(find.text('status: success'), findsNWidgets(2));
          expect(find.text('data: data'), findsNWidgets(2));
          expect(find.text('error: null'), findsNWidgets(2));

          for (int i = 0; i < 10; i++) {
            await tester.pump(shortestRefetchIntervalDuration);

            expect(find.text('status: fetching'), findsNWidgets(2));
            expect(find.text('data: data'), findsNWidgets(2));
            expect(find.text('error: null'), findsNWidgets(2));

            await tester.pump(fetchDuration);

            expect(find.text('status: success'), findsNWidgets(2));
            expect(find.text('data: data'), findsNWidgets(2));
            expect(find.text('error: null'), findsNWidgets(2));
          }
        },
      );

      testWidgets(
        'should use the other "refetchIntervalDuration" when the shortest one is removed',
        (tester) async {
          const fetchDuration = Duration(seconds: 3);
          const shortestRefetchIntervalDuration = Duration(seconds: 7);
          const longestRefetchIntervalDuration = Duration(seconds: 17);
          final widget = QueryBuilder(
            id: 'id',
            fetcher: (id) async {
              await Future.delayed(fetchDuration);
              return 'data';
            },
            builder: (context, state, child) {
              return Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  children: [
                    Text('status: ${state.status.name}'),
                    Text('data: ${state.data}'),
                    Text('error: ${state.error}'),
                  ],
                ),
              );
            },
          );

          await tester.pumpWidget(withQueryClientProvider(
            Column(
              children: [
                widget.copyWith(
                  refetchIntervalDuration: shortestRefetchIntervalDuration,
                ),
                widget.copyWith(
                  refetchIntervalDuration: longestRefetchIntervalDuration,
                ),
              ],
            ),
          ));

          expect(find.text('status: fetching'), findsNWidgets(2));
          expect(find.text('data: null'), findsNWidgets(2));
          expect(find.text('error: null'), findsNWidgets(2));

          await tester.pump(fetchDuration);

          expect(find.text('status: success'), findsNWidgets(2));
          expect(find.text('data: data'), findsNWidgets(2));
          expect(find.text('error: null'), findsNWidgets(2));

          for (int i = 0; i < 10; i++) {
            await tester.pump(shortestRefetchIntervalDuration);

            expect(find.text('status: fetching'), findsNWidgets(2));
            expect(find.text('data: data'), findsNWidgets(2));
            expect(find.text('error: null'), findsNWidgets(2));

            await tester.pump(fetchDuration);

            expect(find.text('status: success'), findsNWidgets(2));
            expect(find.text('data: data'), findsNWidgets(2));
            expect(find.text('error: null'), findsNWidgets(2));
          }

          await tester.pumpWidget(withQueryClientProvider(
            Column(
              children: [
                widget.copyWith(
                  refetchIntervalDuration: longestRefetchIntervalDuration,
                ),
              ],
            ),
          ));

          for (int i = 0; i < 10; i++) {
            await tester.pump(longestRefetchIntervalDuration);

            expect(find.text('status: fetching'), findsOneWidget);
            expect(find.text('data: data'), findsOneWidget);
            expect(find.text('error: null'), findsOneWidget);

            await tester.pump(fetchDuration);

            expect(find.text('status: success'), findsOneWidget);
            expect(find.text('data: data'), findsOneWidget);
            expect(find.text('error: null'), findsOneWidget);
          }
        },
      );

      testWidgets(
        'should fetch even if the "refetchOnInit" is set to "RefetchMode.never"',
        (tester) async {
          const fetchDuration = Duration(seconds: 3);
          const refetchIntervalDuration = Duration(seconds: 10);
          final widget = QueryBuilder<String>(
            id: 'id',
            fetcher: (id) async {
              await Future.delayed(fetchDuration);
              return 'data';
            },
            refetchOnInit: RefetchMode.never,
            refetchIntervalDuration: refetchIntervalDuration,
            builder: (context, state, child) {
              return Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  children: [
                    Text('status: ${state.status.name}'),
                    Text('data: ${state.data}'),
                    Text('error: ${state.error}'),
                  ],
                ),
              );
            },
          );

          await tester.pumpWidget(withQueryClientProvider(widget));

          expect(find.text('status: fetching'), findsOneWidget);
          expect(find.text('data: null'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await tester.pump(fetchDuration);

          expect(find.text('status: success'), findsOneWidget);
          expect(find.text('data: data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          for (int i = 0; i < 10; i++) {
            await tester.pump(refetchIntervalDuration);

            expect(find.text('status: fetching'), findsOneWidget);
            expect(find.text('data: data'), findsOneWidget);
            expect(find.text('error: null'), findsOneWidget);

            await tester.pump(fetchDuration);

            expect(find.text('status: success'), findsOneWidget);
            expect(find.text('data: data'), findsOneWidget);
            expect(find.text('error: null'), findsOneWidget);
          }
        },
      );
    },
  );

  group(
    'when there are multiple instances of the "QueryBuilder"',
    () {
      testWidgets(
        'should be synchronized',
        (tester) async {
          int fetchCount = 0;
          const fetchDuration = Duration(seconds: 3);
          final baseInstance = QueryBuilder<String>(
            id: 'id',
            fetcher: (id) async {
              fetchCount++;
              await Future.delayed(fetchDuration);
              return 'data';
            },
            builder: (context, state, child) {
              return Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  children: [
                    Text('status: ${state.status.name}'),
                    Text('data: ${state.data}'),
                    Text('error: ${state.error}'),
                  ],
                ),
              );
            },
          );
          final instance1 = baseInstance.copyWith(key: Key('key1'));
          final instance2 = baseInstance.copyWith(key: Key('key2'));
          final instance3 = baseInstance.copyWith(key: Key('key3'));

          await tester.pumpWidget(withQueryClientProvider(
            Column(
              children: [
                instance1,
                instance2,
              ],
            ),
          ));

          expect(find.text('status: fetching'), findsNWidgets(2));
          expect(find.text('data: null'), findsNWidgets(2));
          expect(find.text('error: null'), findsNWidgets(2));

          await tester.pump(fetchDuration);

          expect(find.text('status: success'), findsNWidgets(2));
          expect(find.text('data: data'), findsNWidgets(2));
          expect(find.text('error: null'), findsNWidgets(2));

          expect(fetchCount, 1);

          await tester.pumpWidget(withQueryClientProvider(
            Column(
              children: [
                instance1,
                instance2,
                instance3,
              ],
            ),
          ));

          expect(find.text('status: fetching'), findsNWidgets(3));
          expect(find.text('data: data'), findsNWidgets(3));
          expect(find.text('error: null'), findsNWidgets(3));

          await tester.pump(fetchDuration);

          expect(find.text('status: success'), findsNWidgets(3));
          expect(find.text('data: data'), findsNWidgets(3));
          expect(find.text('error: null'), findsNWidgets(3));

          expect(fetchCount, 2);
        },
      );
    },
  );

  group(
    'when a query is canceled',
    () {
      testWidgets(
        'should cancel fetching',
        (tester) async {
          const fetchDuration = Duration(seconds: 3);
          final client = QueryClient();
          final widget = QueryBuilder<String>(
            id: 'id',
            fetcher: (id) async {
              await Future.delayed(fetchDuration);
              return 'data';
            },
            builder: (context, state, child) {
              return Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  children: [
                    Text('status: ${state.status.name}'),
                    Text('data: ${state.data}'),
                    Text('error: ${state.error}'),
                  ],
                ),
              );
            },
          );

          await tester.pumpWidget(withQueryClientProvider(widget, client));

          expect(find.text('status: fetching'), findsOneWidget);
          expect(find.text('data: null'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await client.cancelQuery<String>('id');
          await tester.pump();

          expect(find.text('status: canceled'), findsOneWidget);
          expect(find.text('data: null'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await tester.pump(fetchDuration);

          expect(find.text('status: canceled'), findsOneWidget);
          expect(find.text('data: null'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await client.close();
        },
      );

      testWidgets(
        'should cancel retrying',
        (tester) async {
          int fetchCount = 0;
          const fetchDuration = Duration(seconds: 3);
          final client = QueryClient();
          final widget = QueryBuilder<String>(
            id: 'id',
            fetcher: (id) async {
              await Future.delayed(fetchDuration);
              fetchCount++;
              throw TestException('error');
            },
            retryMaxAttempts: 3,
            retryRandomizationFactor: 0.0,
            builder: (context, state, child) {
              return Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  children: [
                    Text('status: ${state.status.name}'),
                    Text('data: ${state.data}'),
                    Text('error: ${state.error}'),
                  ],
                ),
              );
            },
          );

          await tester.pumpWidget(withQueryClientProvider(widget, client));

          expect(find.text('status: fetching'), findsOneWidget);
          expect(find.text('data: null'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await tester.pump(fetchDuration);

          expect(find.text('status: retrying'), findsOneWidget);
          expect(find.text('data: null'), findsOneWidget);
          expect(find.text('error: error'), findsOneWidget);
          expect(fetchCount, 1);

          await client.cancelQuery<String>('id');
          await tester.pump();

          expect(find.text('status: canceled'), findsOneWidget);
          expect(find.text('data: null'), findsOneWidget);
          expect(find.text('error: error'), findsOneWidget);
          expect(fetchCount, 1);

          await tester.pump(fetchDuration);

          expect(find.text('status: canceled'), findsOneWidget);
          expect(find.text('data: null'), findsOneWidget);
          expect(find.text('error: error'), findsOneWidget);

          // Last retry is expected to be finished even after it has been canceled.
          expect(fetchCount, 2);

          await tester.pump(fetchDuration);

          // No more retry should occur.
          expect(fetchCount, 2);

          await client.close();
        },
      );

      testWidgets(
        'should populate the data if the "cancel" function is called with the "data"',
        (tester) async {
          const fetchDuration = Duration(seconds: 3);
          final client = QueryClient();
          final widget = QueryBuilder<String>(
            id: 'id',
            fetcher: (id) async {
              await Future.delayed(fetchDuration);
              return 'data';
            },
            builder: (context, state, child) {
              return Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  children: [
                    Text('status: ${state.status.name}'),
                    Text('data: ${state.data}'),
                    Text('error: ${state.error}'),
                  ],
                ),
              );
            },
          );

          await tester.pumpWidget(withQueryClientProvider(widget, client));

          expect(find.text('status: fetching'), findsOneWidget);
          expect(find.text('data: null'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await client.cancelQuery('id', data: 'canceled data');
          await tester.pump();

          expect(find.text('status: canceled'), findsOneWidget);
          expect(find.text('data: canceled data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await tester.pump(fetchDuration);

          expect(find.text('status: canceled'), findsOneWidget);
          expect(find.text('data: canceled data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await client.close();
        },
      );

      testWidgets(
        'should populate the error if the "cancel" function is called with the "error"',
        (tester) async {
          const fetchDuration = Duration(seconds: 3);
          final client = QueryClient();
          final widget = QueryBuilder<String>(
            id: 'id',
            fetcher: (id) async {
              await Future.delayed(fetchDuration);
              return 'data';
            },
            builder: (context, state, child) {
              return Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  children: [
                    Text('status: ${state.status.name}'),
                    Text('data: ${state.data}'),
                    Text('error: ${state.error}'),
                  ],
                ),
              );
            },
          );

          await tester.pumpWidget(withQueryClientProvider(widget, client));

          expect(find.text('status: fetching'), findsOneWidget);
          expect(find.text('data: null'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await client.cancelQuery(
            'id',
            error: TestException('canceled error'),
          );
          await tester.pump();

          expect(find.text('status: canceled'), findsOneWidget);
          expect(find.text('data: null'), findsOneWidget);
          expect(find.text('error: canceled error'), findsOneWidget);

          await tester.pump(fetchDuration);

          expect(find.text('status: canceled'), findsOneWidget);
          expect(find.text('data: null'), findsOneWidget);
          expect(find.text('error: canceled error'), findsOneWidget);

          await client.close();
        },
      );
    },
  );

  group(
    'when the "buildWhen" is set',
    () {
      testWidgets(
        'should not rebuild the widget if the "buildWhen" returns "false"',
        (tester) async {
          const fetchDuration = Duration(seconds: 3);
          final widget = QueryBuilder<String>(
            id: 'id',
            fetcher: (id) async {
              await Future.delayed(fetchDuration);
              return 'data';
            },
            buildWhen: (prev, curr) {
              return false;
            },
            builder: (context, state, child) {
              return Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  children: [
                    Text('status: ${state.status.name}'),
                    Text('data: ${state.data}'),
                    Text('error: ${state.error}'),
                  ],
                ),
              );
            },
          );

          await tester.pumpWidget(withQueryClientProvider(widget));

          expect(find.text('status: fetching'), findsOneWidget);
          expect(find.text('data: null'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await tester.pump(fetchDuration);

          expect(find.text('status: fetching'), findsOneWidget);
          expect(find.text('data: null'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);
        },
      );

      testWidgets(
        'should only rebuild the widget if the "buildWhen" returns "true"',
        (tester) async {
          const fetchDuration = Duration(seconds: 3);
          final client = QueryClient();
          final widget = QueryBuilder<String>(
            id: 'id',
            fetcher: (id) async {
              await Future.delayed(fetchDuration);
              return 'data';
            },
            buildWhen: (prev, curr) {
              return prev.status.isFetching && curr.hasData;
            },
            builder: (context, state, child) {
              return Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  children: [
                    Text('status: ${state.status.name}'),
                    Text('data: ${state.data}'),
                    Text('error: ${state.error}'),
                  ],
                ),
              );
            },
          );

          await tester.pumpWidget(withQueryClientProvider(widget));

          expect(find.text('status: fetching'), findsOneWidget);
          expect(find.text('data: null'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await tester.pump(fetchDuration);

          expect(find.text('status: success'), findsOneWidget);
          expect(find.text('data: data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          client.refetch('id');
          await tester.pump();

          expect(find.text('status: success'), findsOneWidget);
          expect(find.text('data: data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await tester.pump(fetchDuration);

          expect(find.text('status: success'), findsOneWidget);
          expect(find.text('data: data'), findsOneWidget);
          expect(find.text('error: null'), findsOneWidget);

          await client.close();
        },
      );
    },
  );
}

class TestException implements Exception {
  TestException(this.message);

  final String message;

  @override
  String toString() {
    return message;
  }
}
