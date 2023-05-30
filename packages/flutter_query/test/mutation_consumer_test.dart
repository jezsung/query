import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_query/flutter_query.dart';
import 'package:flutter_test/flutter_test.dart';

class TestException implements Exception {
  const TestException(this.message);

  final String message;

  @override
  String toString() {
    return message;
  }
}

void main() {
  testWidgets(
    'should start mutating when the mutate is called, and succeed',
    (tester) async {
      const mutateDuration = Duration(seconds: 3);
      final controller = MutationController<String, Never>();
      MutationState<String> listenerState = controller.state;
      final widget = MutationConsumer<String, Never>(
        controller: controller,
        mutator: (param) async {
          await Future.delayed(mutateDuration);
          return 'data';
        },
        listener: (context, state) {
          listenerState = state;
        },
        builder: (context, state, child) {
          return Container(key: ValueKey(state));
        },
      );

      MutationState<String> builderState() {
        final container = tester.widget<Container>(find.byType(Container));
        final key = container.key as ValueKey<MutationState<String>>;
        return key.value;
      }

      await tester.pumpWidget(widget);

      expect(
        listenerState,
        MutationState<String>(
          status: MutationStatus.idle,
          data: null,
          error: null,
          dataUpdatedAt: null,
          errorUpdatedAt: null,
        ),
      );
      expect(
        builderState(),
        MutationState<String>(
          status: MutationStatus.idle,
          data: null,
          error: null,
          dataUpdatedAt: null,
          errorUpdatedAt: null,
        ),
      );

      controller.mutate();
      await tester.pump();

      expect(
        listenerState,
        MutationState<String>(
          status: MutationStatus.mutating,
          data: null,
          error: null,
          dataUpdatedAt: null,
          errorUpdatedAt: null,
        ),
      );
      expect(
        builderState(),
        MutationState<String>(
          status: MutationStatus.mutating,
          data: null,
          error: null,
          dataUpdatedAt: null,
          errorUpdatedAt: null,
        ),
      );

      await tester.pump(mutateDuration);

      expect(
        listenerState,
        MutationState<String>(
          status: MutationStatus.success,
          data: 'data',
          error: null,
          dataUpdatedAt: clock.now(),
          errorUpdatedAt: null,
        ),
      );
      expect(
        builderState(),
        MutationState<String>(
          status: MutationStatus.success,
          data: 'data',
          error: null,
          dataUpdatedAt: clock.now(),
          errorUpdatedAt: null,
        ),
      );

      controller.dispose();
    },
  );

  testWidgets(
    'should start mutating when the mutate is called, and fail',
    (tester) async {
      const mutateDuration = Duration(seconds: 3);
      const error = TestException('error');
      final controller = MutationController<String, Never>();
      MutationState<String> listenerState = controller.state;
      final widget = MutationConsumer<String, Never>(
        controller: controller,
        mutator: (param) async {
          await Future.delayed(mutateDuration);
          throw error;
        },
        listener: (context, state) {
          listenerState = state;
        },
        builder: (context, state, child) {
          return Container(key: ValueKey(state));
        },
      );

      MutationState<String> builderState() {
        final container = tester.widget<Container>(find.byType(Container));
        final key = container.key as ValueKey<MutationState<String>>;
        return key.value;
      }

      await tester.pumpWidget(widget);

      expect(
        listenerState,
        MutationState<String>(
          status: MutationStatus.idle,
          data: null,
          error: null,
          dataUpdatedAt: null,
          errorUpdatedAt: null,
        ),
      );
      expect(
        builderState(),
        MutationState<String>(
          status: MutationStatus.idle,
          data: null,
          error: null,
          dataUpdatedAt: null,
          errorUpdatedAt: null,
        ),
      );

      controller.mutate();
      await tester.pump();

      expect(
        listenerState,
        MutationState<String>(
          status: MutationStatus.mutating,
          data: null,
          error: null,
          dataUpdatedAt: null,
          errorUpdatedAt: null,
        ),
      );
      expect(
        builderState(),
        MutationState<String>(
          status: MutationStatus.mutating,
          data: null,
          error: null,
          dataUpdatedAt: null,
          errorUpdatedAt: null,
        ),
      );

      await tester.pump(mutateDuration);

      expect(
        listenerState,
        MutationState<String>(
          status: MutationStatus.failure,
          data: null,
          error: error,
          dataUpdatedAt: null,
          errorUpdatedAt: clock.now(),
        ),
      );
      expect(
        builderState(),
        MutationState<String>(
          status: MutationStatus.failure,
          data: null,
          error: error,
          dataUpdatedAt: null,
          errorUpdatedAt: clock.now(),
        ),
      );

      controller.dispose();
    },
  );

  testWidgets(
    'should cancel and revert the state to the previous state',
    (tester) async {
      const mutateDuration = Duration(seconds: 3);
      final controller = MutationController<String, Never>();
      MutationState<String> listenerState = controller.state;
      final widget = MutationConsumer<String, Never>(
        controller: controller,
        mutator: (param) async {
          await Future.delayed(mutateDuration);
          throw 'data';
        },
        listener: (context, state) {
          listenerState = state;
        },
        builder: (context, state, child) {
          return Container(key: ValueKey(state));
        },
      );

      MutationState<String> builderState() {
        final container = tester.widget<Container>(find.byType(Container));
        final key = container.key as ValueKey<MutationState<String>>;
        return key.value;
      }

      await tester.pumpWidget(widget);

      expect(
        listenerState,
        MutationState<String>(
          status: MutationStatus.idle,
          data: null,
          error: null,
          dataUpdatedAt: null,
          errorUpdatedAt: null,
        ),
      );
      expect(
        builderState(),
        MutationState<String>(
          status: MutationStatus.idle,
          data: null,
          error: null,
          dataUpdatedAt: null,
          errorUpdatedAt: null,
        ),
      );

      controller.mutate();
      await tester.pump();

      expect(
        listenerState,
        MutationState<String>(
          status: MutationStatus.mutating,
          data: null,
          error: null,
          dataUpdatedAt: null,
          errorUpdatedAt: null,
        ),
      );
      expect(
        builderState(),
        MutationState<String>(
          status: MutationStatus.mutating,
          data: null,
          error: null,
          dataUpdatedAt: null,
          errorUpdatedAt: null,
        ),
      );

      await controller.cancel();
      await tester.pump();

      expect(
        listenerState,
        MutationState<String>(
          status: MutationStatus.idle,
          data: null,
          error: null,
          dataUpdatedAt: null,
          errorUpdatedAt: null,
        ),
      );
      expect(
        builderState(),
        MutationState<String>(
          status: MutationStatus.idle,
          data: null,
          error: null,
          dataUpdatedAt: null,
          errorUpdatedAt: null,
        ),
      );

      controller.dispose();

      await tester.binding.delayed(mutateDuration);
    },
  );
}
