import 'dart:math';

import 'package:clock/clock.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_query/flutter_query.dart';
import 'package:flutter_query/src/paged_query/paged_query.dart';
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

class TestException implements Exception {
  const TestException(this.message);

  final String message;

  @override
  String toString() {
    return message;
  }
}

class PagedData extends Equatable {
  const PagedData(
    this.data,
    this.nextCursor,
  );

  final List<String> data;
  final int? nextCursor;

  @override
  List<Object?> get props => [data, nextCursor];
}

class PagedParam extends Equatable {
  const PagedParam(
    this.cursor,
    this.size,
  );

  final int cursor;
  final int size;

  @override
  List<Object?> get props => [cursor, size];
}

void main() {
  late List<String> data;
  late PagedQueryController<PagedData, PagedParam> controller;
  late PagedQueryBuilder<PagedData, PagedParam> widget;

  const fetchDuration = Duration(seconds: 3);
  const pageSize = 10;
  const initialPageParam = PagedParam(0, pageSize);
  final key = Key('paged_query_builder');
  final id = 'id';

  setUp(() {
    data = 'abcdefghijklmnopqrstuvwxyz'.split('');
    controller = PagedQueryController<PagedData, PagedParam>();
    widget = PagedQueryBuilder<PagedData, PagedParam>(
      key: key,
      controller: controller,
      id: id,
      fetcher: (id, param) async {
        await Future.delayed(fetchDuration);

        final cursor = param.cursor;
        final size = param.size;

        final result = data.sublist(cursor, min(cursor + size, data.length));
        final nextCursor =
            result.last != data.last ? data.indexOf(result.last) + 1 : null;

        return PagedData(result, nextCursor);
      },
      initialPageParam: initialPageParam,
      nextPageParamBuilder: (pages) {
        final nextCursor = pages.last.nextCursor;
        return nextCursor != null ? PagedParam(nextCursor, pageSize) : null;
      },
      builder: (context, state, child) {
        return Container(key: ValueKey(state));
      },
    );
  });

  tearDown(() {
    controller.dispose();
  });

  PagedQueryState<PagedData> state(WidgetTester tester) {
    final container = tester.widget<Container>(find.byType(Container));
    final key = container.key as ValueKey<PagedQueryState<PagedData>>;
    return key.value;
  }

  testWidgets(
    'should start fetching by page and succeed',
    (tester) async {
      final initialCursor = initialPageParam.cursor;
      final restItemCount = data.length - initialCursor;

      await tester.pumpWidget(withQueryClientProvider(widget));

      expect(
        state(tester),
        PagedQueryState<PagedData>(
          status: QueryStatus.fetching,
          pages: [],
          error: null,
          dataUpdatedAt: null,
          errorUpdatedAt: null,
          isInvalidated: false,
          isFetchingNextPage: false,
          isFetchingPreviousPage: false,
          hasNextPage: false,
          hasPreviousPage: false,
        ),
      );

      await tester.pump(fetchDuration);

      expect(
        state(tester),
        PagedQueryState<PagedData>(
          status: QueryStatus.success,
          pages: [
            PagedData(
              data.sublist(
                initialCursor,
                min(
                  initialCursor + initialPageParam.size,
                  data.length,
                ),
              ),
              initialCursor + initialPageParam.size < data.length
                  ? initialCursor + initialPageParam.size
                  : null,
            ),
          ],
          error: null,
          dataUpdatedAt: clock.now(),
          errorUpdatedAt: null,
          isInvalidated: false,
          isFetchingNextPage: false,
          isFetchingPreviousPage: false,
          hasNextPage: pageSize < data.length,
          hasPreviousPage: false,
        ),
      );

      for (int i = 0; i < (restItemCount / pageSize).ceil() - 1; i++) {
        final pages = state(tester).pages;
        final isLastPage = i == (restItemCount / pageSize).ceil() - 1 - 1;

        controller.fetchNextPage();
        await tester.pump();

        expect(
          state(tester),
          PagedQueryState<PagedData>(
            status: QueryStatus.fetching,
            pages: pages,
            error: null,
            dataUpdatedAt: clock.now(),
            errorUpdatedAt: null,
            isInvalidated: false,
            isFetchingNextPage: true,
            isFetchingPreviousPage: false,
            hasNextPage: true,
            hasPreviousPage: false,
          ),
        );

        await tester.pump(fetchDuration);

        expect(
          state(tester),
          PagedQueryState<PagedData>(
            status: QueryStatus.success,
            pages: [
              ...pages,
              if (isLastPage)
                PagedData(
                  data.sublist(
                    initialCursor + (i + 1) * pageSize,
                    initialCursor +
                        ((i + 1) * pageSize) +
                        (restItemCount % pageSize),
                  ),
                  null,
                )
              else
                PagedData(
                  data.sublist(
                    initialCursor + (i + 1) * pageSize,
                    initialCursor + ((i + 1) * pageSize) + pageSize,
                  ),
                  initialCursor + ((i + 1) * pageSize) + pageSize,
                ),
            ],
            error: null,
            dataUpdatedAt: clock.now(),
            errorUpdatedAt: null,
            isInvalidated: false,
            isFetchingNextPage: false,
            isFetchingPreviousPage: false,
            hasNextPage: !isLastPage,
            hasPreviousPage: false,
          ),
        );
      }
    },
  );

  testWidgets(
    'should start fetching by page and fail',
    (tester) async {
      final error = TestException('error');
      widget = widget.copyWith(
        fetcher: (id, param) async {
          await Future.delayed(fetchDuration);
          throw error;
        },
      );

      await tester.pumpWidget(withQueryClientProvider(widget));

      expect(
        state(tester),
        PagedQueryState<PagedData>(
          status: QueryStatus.fetching,
          pages: [],
          error: null,
          dataUpdatedAt: null,
          errorUpdatedAt: null,
          isInvalidated: false,
          isFetchingNextPage: false,
          isFetchingPreviousPage: false,
          hasNextPage: false,
          hasPreviousPage: false,
        ),
      );

      await tester.pump(fetchDuration);

      expect(
        state(tester),
        PagedQueryState<PagedData>(
          status: QueryStatus.failure,
          pages: [],
          error: error,
          dataUpdatedAt: null,
          errorUpdatedAt: clock.now(),
          isInvalidated: false,
          isFetchingNextPage: false,
          isFetchingPreviousPage: false,
          hasNextPage: false,
          hasPreviousPage: false,
        ),
      );
    },
  );
}
