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

      await tester.pump(const Duration(seconds: 3));

      expect(find.text('status: success'), findsOneWidget);
      expect(find.text('data: data'), findsOneWidget);
      expect(find.text('error: null'), findsOneWidget);
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

      await tester.pump(const Duration(seconds: 4));

      expect(find.text('status: failure'), findsOneWidget);
      expect(find.text('data: null'), findsOneWidget);
      expect(find.text('error: error'), findsOneWidget);
    },
  );
}
