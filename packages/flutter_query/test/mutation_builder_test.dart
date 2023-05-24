import 'dart:math';

import 'package:flutter_query/flutter_query.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'should succeed',
    (tester) async {
      const mutateDuration = Duration(seconds: 3);
      final controller = MutationController<String, Never>();
      final widget = MutationBuilder<String, Never>(
        controller: controller,
        mutator: (args) async {
          await Future.delayed(mutateDuration);
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

      await tester.pumpWidget(widget);

      expect(find.text('status: idle'), findsOneWidget);
      expect(find.text('data: null'), findsOneWidget);
      expect(find.text('error: null'), findsOneWidget);

      controller.mutate();
      await tester.pump();

      expect(find.text('status: mutating'), findsOneWidget);
      expect(find.text('data: null'), findsOneWidget);
      expect(find.text('error: null'), findsOneWidget);

      await tester.pump(mutateDuration);

      expect(find.text('status: success'), findsOneWidget);
      expect(find.text('data: data'), findsOneWidget);
      expect(find.text('error: null'), findsOneWidget);

      controller.dispose();
    },
  );

  testWidgets(
    'should fail',
    (tester) async {
      const mutateDuration = Duration(seconds: 3);
      final controller = MutationController<String, Never>();
      final widget = MutationBuilder<String, Never>(
        controller: controller,
        mutator: (args) async {
          await Future.delayed(mutateDuration);
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

      await tester.pumpWidget(widget);

      expect(find.text('status: idle'), findsOneWidget);
      expect(find.text('data: null'), findsOneWidget);
      expect(find.text('error: null'), findsOneWidget);

      controller.mutate();
      await tester.pump();

      expect(find.text('status: mutating'), findsOneWidget);
      expect(find.text('data: null'), findsOneWidget);
      expect(find.text('error: null'), findsOneWidget);

      await tester.pump(mutateDuration);

      expect(find.text('status: failure'), findsOneWidget);
      expect(find.text('data: null'), findsOneWidget);
      expect(find.text('error: error'), findsOneWidget);

      controller.dispose();
    },
  );

  testWidgets(
    'should cancel',
    (tester) async {
      const mutateDuration = Duration(seconds: 3);
      final controller = MutationController<String, Never>();
      final widget = MutationBuilder<String, Never>(
        controller: controller,
        mutator: (args) async {
          await Future.delayed(mutateDuration);
          throw TestException('error');
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

      await tester.pumpWidget(widget);

      expect(find.text('status: idle'), findsOneWidget);
      expect(find.text('data: null'), findsOneWidget);
      expect(find.text('error: null'), findsOneWidget);

      controller.mutate();
      await tester.pump();

      expect(find.text('status: mutating'), findsOneWidget);
      expect(find.text('data: null'), findsOneWidget);
      expect(find.text('error: null'), findsOneWidget);

      controller.cancel();
      await tester.pump(Duration(seconds: 1));

      expect(find.text('status: idle'), findsOneWidget);
      expect(find.text('data: null'), findsOneWidget);
      expect(find.text('error: null'), findsOneWidget);

      controller.dispose();
    },
  );

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
        const mutateDuration = Duration(seconds: 3);
        final controller = MutationController<String, Never>();
        final widget = MutationBuilder<String, Never>(
          controller: controller,
          mutator: (args) async {
            await Future.delayed(mutateDuration);
            throw TestException('error');
          },
          retryMaxAttempts: retryMaxAttempts,
          retryMaxDelay: const Duration(days: 9999),
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

        await tester.pumpWidget(widget);

        controller.mutate();
        await tester.pump();

        expect(find.text('status: mutating'), findsOneWidget);
        expect(find.text('data: null'), findsOneWidget);
        expect(find.text('error: null'), findsOneWidget);

        await tester.pump(mutateDuration);

        for (int i = 1; i <= retryMaxAttempts; i++) {
          expect(find.text('status: retrying'), findsOneWidget);
          expect(find.text('data: null'), findsOneWidget);
          expect(find.text('error: error'), findsOneWidget);

          await tester.pump(mutateDuration);
          await tester.pump(retryDelayFactor * pow(2, i));
        }

        expect(find.text('status: failure'), findsOneWidget);
        expect(find.text('data: null'), findsOneWidget);
        expect(find.text('error: error'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'should change controller\'s getters when the properties of the widget change',
    (tester) async {
      final controller = MutationController<String, Never>();
      final widget = MutationBuilder<String, Never>(
        controller: controller,
        mutator: (args) async {
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

      await tester.pumpWidget(widget.copyWith(
        retryMaxAttempts: 4,
        retryMaxDelay: const Duration(minutes: 1),
        retryDelayFactor: const Duration(milliseconds: 300),
        retryRandomizationFactor: 0.5,
      ));

      expect(controller.retryMaxAttempts, 4);
      expect(controller.retryMaxDelay, const Duration(minutes: 1));
      expect(controller.retryDelayFactor, const Duration(milliseconds: 300));
      expect(controller.retryRandomizationFactor, 0.5);

      await tester.pumpWidget(widget.copyWith(
        retryMaxAttempts: 5,
        retryMaxDelay: const Duration(minutes: 2),
        retryDelayFactor: const Duration(milliseconds: 600),
        retryRandomizationFactor: 0.75,
      ));

      expect(controller.retryMaxAttempts, 5);
      expect(controller.retryMaxDelay, const Duration(minutes: 2));
      expect(controller.retryDelayFactor, const Duration(milliseconds: 600));
      expect(controller.retryRandomizationFactor, 0.75);

      controller.dispose();
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
