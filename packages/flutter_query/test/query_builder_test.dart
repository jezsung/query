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
        state(),
        QueryState<String>(
          status: QueryStatus.success,
          data: 'data',
          error: null,
          dataUpdatedAt: clock.now(),
          errorUpdatedAt: null,
          isInvalidated: false,
        ),
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
        state(),
        QueryState<String>(
          status: QueryStatus.failure,
          data: null,
          error: error,
          dataUpdatedAt: null,
          errorUpdatedAt: clock.now(),
          isInvalidated: false,
        ),
      );
    },
  );

  group(
    'controller',
    () {
      late QueryController<String> controller;

      setUp(() {
        controller = QueryController<String>();
      });

      tearDown(() {
        controller.dispose();
      });

      testWidgets(
        'should refetch',
        (tester) async {
          const fetchDuration = Duration(seconds: 3);
          final data = 'data';
          final widget = QueryBuilder<String>(
            key: Key('query_builder'),
            controller: controller,
            id: 'id',
            fetcher: (id) async {
              await Future.delayed(fetchDuration);
              return data;
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
          await tester.pump(fetchDuration);

          controller.refetch();
          await tester.pump();

          expect(
            state(),
            QueryState<String>(
              status: QueryStatus.fetching,
              data: data,
              error: null,
              dataUpdatedAt: clock.now(),
              errorUpdatedAt: null,
              isInvalidated: false,
            ),
          );

          await tester.pump(fetchDuration);

          expect(
            state(),
            QueryState<String>(
              status: QueryStatus.success,
              data: data,
              error: null,
              dataUpdatedAt: clock.now(),
              errorUpdatedAt: null,
              isInvalidated: false,
            ),
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
            QueryState<String>(
              status: QueryStatus.fetching,
              data: null,
              error: null,
              dataUpdatedAt: null,
              errorUpdatedAt: null,
              isInvalidated: false,
            ),
          );

          await controller.cancel();
          await tester.pump();

          expect(
            state(),
            QueryState<String>(
              status: QueryStatus.idle,
              data: null,
              error: null,
              dataUpdatedAt: null,
              errorUpdatedAt: null,
              isInvalidated: false,
            ),
          );

          await tester.binding.delayed(fetchDuration);
        },
      );

      testWidgets(
        'should set data',
        (tester) async {
          const fetchDuration = Duration(seconds: 3);
          final data = 'data';
          final widget = QueryBuilder<String>(
            key: Key('query_builder'),
            controller: controller,
            id: 'id',
            fetcher: (id) async {
              await Future.delayed(fetchDuration);
              return data;
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
          await tester.pump(fetchDuration);

          final newData = 'new data';
          controller.setData(newData);
          await tester.pump();

          expect(
            state(),
            QueryState<String>(
              status: QueryStatus.success,
              data: newData,
              error: null,
              dataUpdatedAt: clock.now(),
              errorUpdatedAt: null,
              isInvalidated: false,
            ),
          );
        },
      );

      testWidgets(
        'should not set data when the data is older than the existing data',
        (tester) async {
          const fetchDuration = Duration(seconds: 3);
          final data = 'data';
          final widget = QueryBuilder<String>(
            key: Key('query_builder'),
            controller: controller,
            id: 'id',
            fetcher: (id) async {
              await Future.delayed(fetchDuration);
              return data;
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
          await tester.pump(fetchDuration);

          final newData = 'new data';
          controller.setData(newData, clock.ago(minutes: 5));
          await tester.pump();

          expect(
            state(),
            QueryState<String>(
              status: QueryStatus.success,
              data: data,
              error: null,
              dataUpdatedAt: clock.now(),
              errorUpdatedAt: null,
              isInvalidated: false,
            ),
          );
        },
      );

      testWidgets(
        'should synchronize QueryController\'s getters with QueryBuilder\'s properties',
        (tester) async {
          final id = 'id';
          // ignore: prefer_function_declarations_over_variables
          final fetcher = (id) async => 'data';
          final placeholder = 'placeholder';
          final staleDuration = Duration(seconds: 10);
          final cacheDuration = Duration(minutes: 10);

          final widget = QueryBuilder<String>(
            key: Key('query_builder'),
            controller: controller,
            id: id,
            fetcher: fetcher,
            placeholder: placeholder,
            staleDuration: staleDuration,
            cacheDuration: cacheDuration,
            builder: (context, state, child) {
              return Container(key: ValueKey(state));
            },
          );

          await tester.pumpWidget(withQueryClientProvider(widget));

          expect(controller.id, same(id));
          expect(controller.fetcher, same(fetcher));
          expect(controller.placeholder, same(placeholder));
          expect(controller.staleDuration, same(staleDuration));
          expect(controller.cacheDuration, same(cacheDuration));
        },
      );

      testWidgets(
        'should throw errors when the QueryController is not assigned and used',
        (tester) async {
          final widget = QueryBuilder<String>(
            key: Key('query_builder'),
            id: 'id',
            fetcher: (id) async {
              return 'data';
            },
            builder: (context, state, child) {
              return Container(key: ValueKey(state));
            },
          );

          await tester.pumpWidget(withQueryClientProvider(widget));

          expect(controller.refetch(), throwsAssertionError);
          expect(controller.cancel(), throwsAssertionError);
          expect(() => controller.setData('new data'), throwsAssertionError);
        },
      );

      testWidgets(
        'should throw errors when a new QueryController is assigned and the old one is used',
        (tester) async {
          final widget = QueryBuilder<String>(
            key: Key('query_builder'),
            controller: controller,
            id: 'id',
            fetcher: (id) async {
              return 'data';
            },
            builder: (context, state, child) {
              return Container(key: ValueKey(state));
            },
          );

          await tester.pumpWidget(withQueryClientProvider(widget));

          final newController = QueryController<String>();

          await tester.pumpWidget(withQueryClientProvider(
            widget.copyWith(controller: newController),
          ));

          expect(controller.refetch(), throwsAssertionError);
          expect(controller.cancel(), throwsAssertionError);
          expect(() => controller.setData('new data'), throwsAssertionError);
        },
      );

      testWidgets(
        'should refetch when a new QueryController is assigned and used',
        (tester) async {
          const fetchDuration = Duration(seconds: 3);
          final data = 'data';
          final widget = QueryBuilder<String>(
            key: Key('query_builder'),
            controller: controller,
            id: 'id',
            fetcher: (id) async {
              await Future.delayed(fetchDuration);
              return data;
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
          await tester.pump(fetchDuration);

          final newController = QueryController<String>();

          await tester.pumpWidget(withQueryClientProvider(
            widget.copyWith(controller: newController),
          ));

          newController.refetch();
          await tester.pump();

          expect(
            state(),
            QueryState<String>(
              status: QueryStatus.fetching,
              data: data,
              error: null,
              dataUpdatedAt: clock.now(),
              errorUpdatedAt: null,
            ),
          );

          await tester.pump(fetchDuration);

          expect(
            state(),
            QueryState<String>(
              status: QueryStatus.success,
              data: data,
              error: null,
              dataUpdatedAt: clock.now(),
              errorUpdatedAt: null,
            ),
          );
        },
      );
    },
  );
}
