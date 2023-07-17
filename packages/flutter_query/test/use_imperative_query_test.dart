import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks_test/flutter_hooks_test.dart';
import 'package:flutter_query/flutter_query.dart';
import 'package:flutter_query/src/hooks/use_imperative_query.dart';
import 'package:flutter_test/flutter_test.dart';

Widget withQueryScope(Widget widget) {
  return QueryScope(
    key: Key('query_scope'),
    child: widget,
  );
}

void main() {
  testWidgets(
    'should fetch and succeed',
    (tester) async {
      const fetchDuration = Duration(seconds: 3);

      final result = await buildHook(
        (_) => useImperativeQuery<String, String>(
          fetcher: (String key) async {
            await Future.delayed(fetchDuration);
            return key;
          },
        ),
        provide: (hookBuilder) => withQueryScope(hookBuilder),
      );

      expect(result.current.state, isNull);

      await act(() => result.current.fetch('first'));

      expect(
        result.current.state,
        QueryState<String>(
          status: QueryStatus.idle,
          data: null,
          error: null,
          dataUpdatedAt: null,
          errorUpdatedAt: null,
          isInvalidated: false,
        ),
      );

      await tester.pump();

      expect(
        result.current.state,
        QueryState<String>(
          status: QueryStatus.fetching,
          data: null,
          error: null,
          dataUpdatedAt: null,
          errorUpdatedAt: null,
          isInvalidated: false,
        ),
      );

      await tester.pump(fetchDuration);

      expect(
        result.current.state,
        QueryState<String>(
          status: QueryStatus.success,
          data: 'first',
          error: null,
          dataUpdatedAt: clock.now(),
          errorUpdatedAt: null,
          isInvalidated: false,
        ),
      );

      await act(() => result.current.fetch('second'));

      expect(
        result.current.state,
        QueryState<String>(
          status: QueryStatus.idle,
          data: null,
          error: null,
          dataUpdatedAt: null,
          errorUpdatedAt: null,
          isInvalidated: false,
        ),
      );

      await tester.pump();

      expect(
        result.current.state,
        QueryState<String>(
          status: QueryStatus.fetching,
          data: null,
          error: null,
          dataUpdatedAt: null,
          errorUpdatedAt: null,
          isInvalidated: false,
        ),
      );

      await tester.pump(fetchDuration);

      expect(
        result.current.state,
        QueryState<String>(
          status: QueryStatus.success,
          data: 'second',
          error: null,
          dataUpdatedAt: clock.now(),
          errorUpdatedAt: null,
          isInvalidated: false,
        ),
      );
    },
  );
}
