import 'package:fluery/fluery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

extension WidgetTesterExtension on WidgetTester {
  Future<void> pumpWithQueryClientProvider(
    Widget widget, [
    Duration? duration,
    EnginePhase enginePhase = EnginePhase.sendSemanticsUpdate,
  ]) async {
    await pumpWidget(
      QueryClientProvider(
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return widget;
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
    'should start with a fetching status',
    (tester) async {
      await tester.pumpWithQueryClientProvider(
        QueryBuilder<String>(
          id: 'id',
          fetcher: (id) async {
            await Future.delayed(const Duration(seconds: 3));
            return 'data';
          },
          builder: (context, state, child) {
            return Text(state.status.name);
          },
        ),
      );

      expect(find.text('fetching'), findsOneWidget);
    },
  );

  testWidgets(
    'should end with a success status',
    (tester) async {
      await tester.pumpWithQueryClientProvider(
        QueryBuilder<String>(
          id: 'id',
          fetcher: (id) async {
            await Future.delayed(const Duration(seconds: 3));
            return 'data';
          },
          builder: (context, state, child) {
            return Text(state.status.name);
          },
        ),
      );

      await tester.pump(const Duration(seconds: 3));

      expect(find.text('success'), findsOneWidget);
    },
  );

  testWidgets(
    'should end with a failure status',
    (tester) async {
      await tester.pumpWithQueryClientProvider(
        QueryBuilder<String>(
          id: 'id',
          fetcher: (id) async {
            await Future.delayed(const Duration(seconds: 3));
            throw 'error';
          },
          builder: (context, state, child) {
            return Text(state.status.name);
          },
        ),
      );

      await tester.pump(const Duration(seconds: 3));

      expect(find.text('failure'), findsOneWidget);
    },
  );

  testWidgets(
    'should show placeholder data when it has no previous data and it is fetching',
    (tester) async {
      await tester.pumpWithQueryClientProvider(
        QueryBuilder<String>(
          id: 'id',
          fetcher: (id) async {
            await Future.delayed(const Duration(seconds: 3));
            return 'data';
          },
          placeholderData: 'placeholder data',
          builder: (context, state, child) {
            return Column(
              children: [
                Text('status: ${state.status.name}'),
                Text('data: ${state.data}'),
              ],
            );
          },
        ),
      );

      expect(find.text('status: fetching'), findsOneWidget);
      expect(find.text('data: placeholder data'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));

      expect(find.text('status: success'), findsOneWidget);
      expect(find.text('data: data'), findsOneWidget);
    },
  );

  group(
    'when enabled is false',
    () {
      testWidgets(
        'should start with an idle status if there is no cached query',
        (tester) async {
          await tester.pumpWithQueryClientProvider(
            QueryBuilder<String>(
              id: 'id',
              fetcher: (id) async {
                await Future.delayed(const Duration(seconds: 3));
                return 'data';
              },
              enabled: false,
              builder: (context, state, child) {
                return Text(state.status.name);
              },
            ),
          );

          expect(find.text('idle'), findsOneWidget);
        },
      );

      testWidgets(
        'should not start fetching even if there is no cached query',
        (tester) async {
          int fetchCallCount = 0;

          await tester.pumpWithQueryClientProvider(
            QueryBuilder<String>(
              id: 'id',
              fetcher: (id) async {
                fetchCallCount++;
                await Future.delayed(const Duration(seconds: 3));
                return 'data';
              },
              enabled: false,
              builder: (context, state, child) {
                return Text(state.status.name);
              },
            ),
          );

          await tester.pump(const Duration(seconds: 3));

          expect(find.text('idle'), findsOneWidget);
          expect(fetchCallCount, isZero);
        },
      );

      testWidgets(
        'should populate a cached query if one exists',
        (tester) async {},
      );

      testWidgets(
        'should not refetch on init regardless of the "refetchOnInit" property',
        (tester) async {},
      );

      testWidgets(
        'should not refetch on resumed regardless of the "refetchOnResumed" property',
        (tester) async {},
      );

      testWidgets(
        'should not refetch on intervals even if the "refetchIntervalDuration" is set',
        (tester) async {},
      );
    },
  );

  group(
    'when "initialData" is set',
    () {
      group(
        'and "initialDataUpdatedAt" is not set',
        () {
          testWidgets(
            'should start with a fetching status and the "initialData" if there is no cached data',
            (tester) async {},
          );

          testWidgets(
            'should start fetching immediately and resolve',
            (tester) async {},
          );

          testWidgets(
            'should ignore the "initialData" if a cached query already exists',
            (tester) async {},
          );
        },
      );

      group(
        'and "initialDataUpdatedAt" is set',
        () {
          testWidgets(
            'should start with a success status and the "initialData" if the "initialData" is up to date based on the "intialDataUpdatedAt" and "staleDuration"',
            (tester) async {},
          );

          testWidgets(
            'should not start fetching if the "initialData" is up to date',
            (tester) async {},
          );
        },
      );
    },
  );
}
