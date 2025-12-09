import 'package:flutter/widgets.dart';

import 'package:clock/clock.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_query/flutter_query.dart';

Widget withQueryScope(Widget widget) {
  return QueryScope(
    key: Key('query_scope'),
    child: widget,
  );
}

void main() {
  testWidgets(
    'should mutate and succeed when mutate is called',
    (tester) async {
      final data = 'data';
      const mutateDuration = Duration(seconds: 3);

      late MutationState<String> state;
      late Mutate<Never> mutate;

      final hookBuilder = HookBuilder(
        builder: (context) {
          final result = useMutation<String, Never>(
            (param) async {
              await Future.delayed(mutateDuration);
              return data;
            },
          );
          state = result.state;
          mutate = result.mutate;
          return Container();
        },
      );

      await tester.pumpWidget(withQueryScope(hookBuilder));

      expect(
        state,
        MutationState<String>(
          status: MutationStatus.idle,
          data: null,
          error: null,
          dataUpdatedAt: null,
          errorUpdatedAt: null,
        ),
      );

      mutate();
      await tester.pump();
      await tester.pump();

      expect(
        state,
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
        state,
        MutationState<String>(
          status: MutationStatus.success,
          data: data,
          error: null,
          dataUpdatedAt: clock.now(),
          errorUpdatedAt: null,
        ),
      );
    },
  );

  testWidgets(
    'should cancel and revert state back when cancel is called',
    (tester) async {
      final data = 'data';
      const mutateDuration = Duration(seconds: 3);

      late MutationState<String> state;
      late Mutate<Never> mutate;
      late MutationCancel cancel;

      final hookBuilder = HookBuilder(
        builder: (context) {
          final result = useMutation<String, Never>(
            (param) async {
              await Future.delayed(mutateDuration);
              return data;
            },
          );
          state = result.state;
          mutate = result.mutate;
          cancel = result.cancel;
          return Container();
        },
      );

      await tester.pumpWidget(withQueryScope(hookBuilder));

      expect(
        state,
        MutationState<String>(
          status: MutationStatus.idle,
          data: null,
          error: null,
          dataUpdatedAt: null,
          errorUpdatedAt: null,
        ),
      );

      mutate();
      await tester.pump();
      await tester.pump();

      expect(
        state,
        MutationState<String>(
          status: MutationStatus.mutating,
          data: null,
          error: null,
          dataUpdatedAt: null,
          errorUpdatedAt: null,
        ),
      );

      await cancel();
      await tester.pump();
      await tester.pump();

      expect(
        state,
        MutationState<String>(
          status: MutationStatus.idle,
          data: null,
          error: null,
          dataUpdatedAt: null,
          errorUpdatedAt: null,
        ),
      );

      await tester.binding.delayed(mutateDuration);
    },
  );
}
