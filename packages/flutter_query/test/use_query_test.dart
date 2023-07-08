import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_query/flutter_query.dart';
import 'package:flutter_query/src/hooks/use_query.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
  testWidgets(
    'should start fetching and succeed',
    (tester) async {
      final key = 'key';
      final data = 'data';
      const fetchDuration = Duration(seconds: 3);
      late QueryState<String> state;

      await tester.pumpWidget(withQueryClientProvider(
        HookBuilder(
          builder: (context) {
            final result = useQuery<String>(
              key,
              (key) async {
                await Future.delayed(fetchDuration);
                return data;
              },
            );

            state = result.state;

            return Container();
          },
        ),
      ));

      expect(
        state,
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
        state,
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
        state,
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
    'should start fetching and fail',
    (tester) async {
      final key = 'key';
      final error = Exception();
      const fetchDuration = Duration(seconds: 3);
      late QueryState<String> state;

      await tester.pumpWidget(withQueryClientProvider(
        HookBuilder(
          builder: (context) {
            final result = useQuery<String>(
              key,
              (key) async {
                await Future.delayed(fetchDuration);
                throw error;
              },
            );

            state = result.state;

            return Container();
          },
        ),
      ));

      expect(
        state,
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
        state,
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
        state,
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

  testWidgets(
    'should refetch when the data is stale',
    (tester) async {
      final key = 'key';
      final data = 'data';
      const fetchDuration = Duration(seconds: 3);
      const staleDuration = Duration(minutes: 5);
      late DateTime dataUpdatedAt;
      late QueryState<String> state;

      await tester.pumpWidget(withQueryClientProvider(
        Column(
          children: [
            HookBuilder(
              key: Key('hook_builder1'),
              builder: (context) {
                useQuery<String>(
                  key,
                  (key) async {
                    await Future.delayed(fetchDuration);
                    return data;
                  },
                  staleDuration: staleDuration,
                );

                return Container();
              },
            ),
          ],
        ),
      ));

      await tester.pump(fetchDuration);

      dataUpdatedAt = clock.now();

      await tester.pump(staleDuration);

      await tester.pumpWidget(withQueryClientProvider(
        Column(
          children: [
            HookBuilder(
              key: Key('hook_builder1'),
              builder: (context) {
                useQuery<String>(
                  key,
                  (key) async {
                    await Future.delayed(fetchDuration);
                    return data;
                  },
                  staleDuration: staleDuration,
                );

                return Container();
              },
            ),
            HookBuilder(
              key: Key('hook_builder2'),
              builder: (context) {
                final result = useQuery<String>(
                  key,
                  (key) async {
                    await Future.delayed(fetchDuration);
                    return data;
                  },
                  staleDuration: staleDuration,
                  refetchOnInit: RefetchBehavior.stale,
                );

                state = result.state;

                return Container();
              },
            ),
          ],
        ),
      ));

      expect(
        state,
        QueryState<String>(
          status: QueryStatus.success,
          data: data,
          error: null,
          dataUpdatedAt: dataUpdatedAt,
          errorUpdatedAt: null,
          isInvalidated: false,
        ),
      );

      await tester.pump();

      expect(
        state,
        QueryState<String>(
          status: QueryStatus.fetching,
          data: data,
          error: null,
          dataUpdatedAt: dataUpdatedAt,
          errorUpdatedAt: null,
          isInvalidated: false,
        ),
      );

      await tester.pump(fetchDuration);

      expect(
        state,
        QueryState<String>(
          status: QueryStatus.success,
          data: data,
          error: null,
          dataUpdatedAt: dataUpdatedAt = clock.now(),
          errorUpdatedAt: null,
          isInvalidated: false,
        ),
      );
    },
  );
}
