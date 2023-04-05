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
            switch (state.status) {
              case QueryStatus.idle:
                return const Text('idle');
              case QueryStatus.fetching:
                return const Text('fetching');
              case QueryStatus.retrying:
                return const Text('retrying');
              case QueryStatus.success:
                return const Text('success');
              case QueryStatus.failure:
                return const Text('failure');
            }
          },
        ),
      );

      expect(find.text('fetching'), findsOneWidget);
    },
  );
}
