import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_query/flutter_query.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:query/query.dart';

Widget withQueryClientProvider(Widget widget, [QueryClient? client]) {
  if (client != null) {
    return QueryClientProvider.value(
      key: Key('query_client_provider'),
      value: client,
      child: widget,
    );
  } else {
    return QueryClientProvider(
      key: Key('query_client_provider'),
      create: (context) => QueryClient(),
      child: widget,
    );
  }
}

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
    'should start fetching and succeed',
    (tester) async {
      const fetchDuration = Duration(seconds: 3);
      final widget = QueryBuilder<String>(
        key: Key('query_builder'),
        id: 'id',
        fetcher: (id) async {
          await Future.delayed(fetchDuration);
          return 'data';
        },
        builder: (context, state, child) {
          return Container(key: ValueKey(state));
        },
      );

      QueryState<String> state() {
        final container = tester.widget<Container>(find.byType(Container));
        final key = container.key as ValueKey<QueryState<String>>;
        return key.value;
      }

      await tester.pumpWidget(withQueryClientProvider(widget));

      expect(
        state(),
        equals(QueryState<String>(
          status: QueryStatus.fetching,
          data: null,
          error: null,
          dataUpdatedAt: null,
          errorUpdatedAt: null,
          isInvalidated: false,
        )),
      );

      await tester.pump(fetchDuration);

      expect(
        state(),
        equals(QueryState<String>(
          status: QueryStatus.success,
          data: 'data',
          error: null,
          dataUpdatedAt: clock.now(),
          errorUpdatedAt: null,
          isInvalidated: false,
        )),
      );
    },
  );

  testWidgets(
    'should start fetching and fail',
    (tester) async {
      const fetchDuration = Duration(seconds: 3);
      const error = TestException('error');
      final widget = QueryBuilder<String>(
        key: Key('query_builder'),
        id: 'id',
        fetcher: (id) async {
          await Future.delayed(fetchDuration);
          throw error;
        },
        builder: (context, state, child) {
          return Container(key: ValueKey(state));
        },
      );

      QueryState<String> state() {
        final container = tester.widget<Container>(find.byType(Container));
        final key = container.key as ValueKey<QueryState<String>>;
        return key.value;
      }

      await tester.pumpWidget(withQueryClientProvider(widget));

      expect(
        state(),
        equals(QueryState<String>(
          status: QueryStatus.fetching,
          data: null,
          error: null,
          dataUpdatedAt: null,
          errorUpdatedAt: null,
          isInvalidated: false,
        )),
      );

      await tester.pump(fetchDuration);

      expect(
        state(),
        equals(QueryState<String>(
          status: QueryStatus.failure,
          data: null,
          error: error,
          dataUpdatedAt: null,
          errorUpdatedAt: clock.now(),
          isInvalidated: false,
        )),
      );
    },
  );

  testWidgets(
    'should cancel and revert the state back',
    (tester) async {
      const fetchDuration = Duration(seconds: 3);
      final controller = QueryController<String>();
      final widget = QueryBuilder<String>(
        key: Key('query_builder'),
        controller: controller,
        id: 'id',
        fetcher: (id) async {
          await Future.delayed(fetchDuration);
          return 'data';
        },
        builder: (context, state, child) {
          return Container(key: ValueKey(state));
        },
      );

      QueryState<String> state() {
        final container = tester.widget<Container>(find.byType(Container));
        final key = container.key as ValueKey<QueryState<String>>;
        return key.value;
      }

      await tester.pumpWidget(withQueryClientProvider(widget));

      expect(
        state(),
        equals(QueryState<String>(
          status: QueryStatus.fetching,
          data: null,
          error: null,
          dataUpdatedAt: null,
          errorUpdatedAt: null,
          isInvalidated: false,
        )),
      );

      await controller.cancel();
      await tester.pump();

      expect(
        state(),
        equals(QueryState<String>(
          status: QueryStatus.idle,
          data: null,
          error: null,
          dataUpdatedAt: null,
          errorUpdatedAt: null,
          isInvalidated: false,
        )),
      );

      await tester.binding.delayed(fetchDuration);
    },
  );
}
