import 'dart:math';

import 'package:fluery/fluery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'should succeed',
    (tester) async {
      final controller = MutationController<String, Never>();

      MutationState state = controller.value;

      const mutateDuration = Duration(seconds: 3);

      final widget = MutationListener<String, Never>(
        controller: controller,
        mutator: (args) async {
          await Future.delayed(mutateDuration);
          return 'data';
        },
        listener: (context, s) {
          state = s;
        },
        child: const Placeholder(),
      );

      await tester.pumpWidget(widget);

      expect(state.status, MutationStatus.idle);
      expect(state.data, isNull);
      expect(state.error, isNull);

      controller.mutate();
      await tester.pump();

      expect(state.status, MutationStatus.mutating);
      expect(state.data, isNull);
      expect(state.error, isNull);

      await tester.pump(mutateDuration);

      expect(state.status, MutationStatus.success);
      expect(state.data, 'data');
      expect(state.error, isNull);

      controller.dispose();
    },
  );

  testWidgets(
    'should fail',
    (tester) async {
      final controller = MutationController<String, Never>();

      MutationState state = controller.value;

      const mutateDuration = Duration(seconds: 3);
      final error = TestException('error');

      final widget = MutationListener<String, Never>(
        controller: controller,
        mutator: (args) async {
          await Future.delayed(mutateDuration);
          throw error;
        },
        retryMaxAttempts: 0,
        listener: (context, s) {
          state = s;
        },
        child: const Placeholder(),
      );

      await tester.pumpWidget(widget);

      expect(state.status, MutationStatus.idle);
      expect(state.data, isNull);
      expect(state.error, isNull);

      controller.mutate();
      await tester.pump();

      expect(state.status, MutationStatus.mutating);
      expect(state.data, isNull);
      expect(state.error, isNull);

      await tester.pump(mutateDuration);

      expect(state.status, MutationStatus.failure);
      expect(state.data, isNull);
      expect(state.error, same(error));

      controller.dispose();
    },
  );

  testWidgets(
    'should cancel',
    (tester) async {
      final controller = MutationController<String, Never>();

      MutationState state = controller.value;

      const mutateDuration = Duration(seconds: 3);

      final widget = MutationListener<String, Never>(
        controller: controller,
        mutator: (args) async {
          await Future.delayed(mutateDuration);
          return 'data';
        },
        listener: (context, s) {
          state = s;
        },
        child: const Placeholder(),
      );

      await tester.pumpWidget(widget);

      expect(state.status, MutationStatus.idle);
      expect(state.data, isNull);
      expect(state.error, isNull);

      controller.mutate();
      await tester.pump();

      expect(state.status, MutationStatus.mutating);
      expect(state.data, isNull);
      expect(state.error, isNull);

      controller.cancel();
      await tester.pump(Duration(seconds: 1));

      expect(state.status, MutationStatus.canceled);
      expect(state.data, isNull);
      expect(state.error, isNull);

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
        final controller = MutationController<String, Never>();

        MutationState state = controller.value;

        const mutateDuration = Duration(seconds: 3);

        int errorCount = 0;

        final widget = MutationListener<String, Never>(
          controller: controller,
          mutator: (args) async {
            await Future.delayed(mutateDuration);
            throw TestException('error${++errorCount}');
          },
          retryMaxAttempts: retryMaxAttempts,
          retryMaxDelay: const Duration(days: 9999),
          retryDelayFactor: retryDelayFactor,
          listener: (context, s) {
            state = s;
          },
          child: const Placeholder(),
        );

        await tester.pumpWidget(widget);

        controller.mutate();
        await tester.pump();

        expect(state.status, MutationStatus.mutating);
        expect(state.data, isNull);
        expect(state.error, isNull);

        await tester.pump(mutateDuration);

        for (int i = 1; i <= retryMaxAttempts; i++) {
          expect(state.status, MutationStatus.retrying);
          expect(state.data, isNull);
          expect(state.error, isA<TestException>());
          expect((state.error as TestException).message, 'error$errorCount');

          await tester.pump(mutateDuration);
          await tester.pump(retryDelayFactor * pow(2, i));
        }

        expect(state.status, MutationStatus.failure);
        expect(state.data, isNull);
        expect(state.error, isA<TestException>());
        expect((state.error as TestException).message, 'error$errorCount');
      },
    );
  }

  testWidgets(
    'should change controller\'s getters when the properties of the widget change',
    (tester) async {
      final controller = MutationController<String, Never>();

      MutationState state = controller.value;

      final widget = MutationListener<String, Never>(
        controller: controller,
        mutator: (args) async {
          return 'data';
        },
        listener: (context, s) {
          state = s;
        },
        child: const Placeholder(),
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
