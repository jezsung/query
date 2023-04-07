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
          enabled: true,
          initialData: null,
          initialDataUpdatedAt: null,
          placeholderData: null,
          staleDuration: Duration.zero,
          retryCount: 0,
          retryDelayDuration: Duration.zero,
          refetchOnInit: RefetchMode.stale,
          refetchOnResumed: RefetchMode.stale,
          refetchIntervalDuration: null,
          builder: (context, state, child) {
            return Text(state.status.name);
          },
          child: null,
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
          enabled: true,
          initialData: null,
          initialDataUpdatedAt: null,
          placeholderData: null,
          staleDuration: Duration.zero,
          retryCount: 0,
          retryDelayDuration: Duration.zero,
          refetchOnInit: RefetchMode.stale,
          refetchOnResumed: RefetchMode.stale,
          refetchIntervalDuration: null,
          builder: (context, state, child) {
            return Text(state.status.name);
          },
          child: null,
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
          enabled: true,
          initialData: null,
          initialDataUpdatedAt: null,
          placeholderData: null,
          staleDuration: Duration.zero,
          retryCount: 0,
          retryDelayDuration: Duration.zero,
          refetchOnInit: RefetchMode.stale,
          refetchOnResumed: RefetchMode.stale,
          refetchIntervalDuration: null,
          builder: (context, state, child) {
            return Text(state.status.name);
          },
          child: null,
        ),
      );

      await tester.pump(const Duration(seconds: 3));

      expect(find.text('failure'), findsOneWidget);
    },
  );

  testWidgets(
    'should start with a success status and populated data when the initial data is provided',
    (tester) async {
      await tester.pumpWithQueryClientProvider(
        QueryBuilder<String>(
          id: 'id',
          fetcher: (id) async {
            await Future.delayed(const Duration(seconds: 3));
            return 'data';
          },
          enabled: true,
          initialData: 'initial data',
          initialDataUpdatedAt: null,
          placeholderData: null,
          staleDuration: Duration.zero,
          retryCount: 0,
          retryDelayDuration: Duration.zero,
          refetchOnInit: RefetchMode.stale,
          refetchOnResumed: RefetchMode.stale,
          refetchIntervalDuration: null,
          builder: (context, state, child) {
            return Column(
              children: [
                Text('status: ${state.status.name}'),
                Text('data: ${state.data}'),
              ],
            );
          },
          child: null,
        ),
      );

      expect(find.text('status: success'), findsOneWidget);
      expect(find.text('data: initial data'), findsOneWidget);
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
          enabled: true,
          initialData: null,
          initialDataUpdatedAt: null,
          placeholderData: 'placeholder data',
          staleDuration: Duration.zero,
          retryCount: 0,
          retryDelayDuration: Duration.zero,
          refetchOnInit: RefetchMode.stale,
          refetchOnResumed: RefetchMode.stale,
          refetchIntervalDuration: null,
          builder: (context, state, child) {
            return Column(
              children: [
                Text('status: ${state.status.name}'),
                Text('data: ${state.data}'),
              ],
            );
          },
          child: null,
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
              initialData: null,
              initialDataUpdatedAt: null,
              placeholderData: null,
              staleDuration: Duration.zero,
              retryCount: 0,
              retryDelayDuration: Duration.zero,
              refetchOnInit: RefetchMode.stale,
              refetchOnResumed: RefetchMode.stale,
              refetchIntervalDuration: null,
              builder: (context, state, child) {
                return Text(state.status.name);
              },
              child: null,
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
              initialData: null,
              initialDataUpdatedAt: null,
              placeholderData: null,
              staleDuration: Duration.zero,
              retryCount: 0,
              retryDelayDuration: Duration.zero,
              refetchOnInit: RefetchMode.stale,
              refetchOnResumed: RefetchMode.stale,
              refetchIntervalDuration: null,
              builder: (context, state, child) {
                return Text(state.status.name);
              },
              child: null,
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
}
