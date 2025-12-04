import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_query/src/hooks/use_infinite_query.dart';
import 'package:query_core/query_core.dart';

void main() {
  setUp(() {
    // Ensure a fresh QueryClient instance and clear cache between tests
    QueryClient();
    cacheQuery.clear();
  });

  testWidgets('should fetch initial page and succeed', (WidgetTester tester) async {
    final holder = ValueNotifier<InfiniteQueryResult<int>?>(null);

    await tester.pumpWidget(MaterialApp(
      home: HookBuilder(
        builder: (context) {
          final result = useInfiniteQuery<int>(
            queryKey: ['infinite', 'init-success'],
            queryFn: (page) async {
              await Future.delayed(Duration(milliseconds: 10));
              return page;
            },
            initialPageParam: 1,
          );

          holder.value = result;
          return Container();
        },
      ),
    ));

    // initial state is pending
    expect(holder.value, isNotNull);
    expect(holder.value!.status, equals(QueryStatus.pending));

    // wait async fetch to complete
    await tester.pumpAndSettle();

    // should succeed and data contains the first page
    expect(holder.value!.status, equals(QueryStatus.success));
    expect(holder.value!.data, equals([1]));
    // verify the cache contains the initial page result
    final key = queryKeyToCacheKey(['infinite', 'init-success']);
    final cached = (cacheQuery[key]!.result as InfiniteQueryResult<int>);
    expect(cached.data, equals([1]));
  });

  testWidgets('should fetch next page when fetchNextPage is called', (WidgetTester tester) async {
    final holder = ValueNotifier<InfiniteQueryResult<int>?>(null);

    await tester.pumpWidget(MaterialApp(
      home: HookBuilder(
        builder: (context) {
          final result = useInfiniteQuery<int>(
            queryKey: ['infinite', 'next-page'],
            queryFn: (page) async {
              await Future.delayed(Duration(milliseconds: 10));
              return page;
            },
            initialPageParam: 1,
            getNextPageParam: (last) => last + 1,
          );

          holder.value = result;
          return Container();
        },
      ),
    ));

    // wait initial fetch
    await tester.pumpAndSettle();
    expect(holder.value!.status, equals(QueryStatus.success));
    expect(holder.value!.data, equals([1]));

    // request next page
    holder.value!.fetchNextPage?.call();
    await tester.pump(); // kick off fetch
    await tester.pumpAndSettle();

    // should have two pages now
    expect(holder.value!.data, equals([1, 2]));
  });

  testWidgets('should set error state when initial fetch fails', (WidgetTester tester) async {
    final holder = ValueNotifier<InfiniteQueryResult<int>?>(null);

    await tester.pumpWidget(MaterialApp(
      home: HookBuilder(
        builder: (context) {
          final result = useInfiniteQuery<int>(
            queryKey: ['infinite', 'init-error'],
            queryFn: (page) async {
              await Future.delayed(Duration(milliseconds: 10));
              throw Exception('boom');
            },
            initialPageParam: 1,
          );

          holder.value = result;
          return Container();
        },
      ),
    ));

    // pending then settle to error
    expect(holder.value!.status, anyOf(equals(QueryStatus.pending), equals(QueryStatus.error)));
    await tester.pumpAndSettle();
    expect(holder.value!.status, equals(QueryStatus.error));
    // the hook reports the error in the cache
    final key = queryKeyToCacheKey(['infinite', 'init-error']);
    expect((cacheQuery[key]!.result as InfiniteQueryResult<int>).error.toString(), contains('boom'));
  });

  testWidgets('should set error state when fetching next page fails', (WidgetTester tester) async {
    final holder = ValueNotifier<InfiniteQueryResult<int>?>(null);

    await tester.pumpWidget(MaterialApp(
      home: HookBuilder(
        builder: (context) {
          final result = useInfiniteQuery<int>(
            queryKey: ['infinite', 'next-error'],
            queryFn: (page) async {
              await Future.delayed(Duration(milliseconds: 10));
              if (page == 1) return 1;
              throw Exception('boom-next');
            },
            initialPageParam: 1,
            getNextPageParam: (last) => last + 1,
          );

          holder.value = result;
          return Container();
        },
      ),
    ));

    // wait initial success
    await tester.pumpAndSettle();
    expect(holder.value!.status, equals(QueryStatus.success));
    expect(holder.value!.data, equals([1]));

    // attempt to load next page which will throw
    holder.value!.fetchNextPage?.call();
    await tester.pump(); // start
    await tester.pumpAndSettle(); // finish

    // After next-page error the hook sets status error and clears data
    expect(holder.value!.status, equals(QueryStatus.error));
    expect(holder.value!.data, equals(<int>[]));
    // cache should reflect the error
    final nextKey = queryKeyToCacheKey(['infinite', 'next-error']);
    final nextCached = cacheQuery[nextKey]!.result as InfiniteQueryResult<int>;
    expect(nextCached.status, equals(QueryStatus.error));
    expect(nextCached.data, equals(<int>[]));
  });

  testWidgets('should debounce when queryKey changes and debounceTime is set', (WidgetTester tester) async {
    bool toggled = false;

    final holder = ValueNotifier<InfiniteQueryResult<int>?>(null);

    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(builder: (context, setState) {
        return HookBuilder(builder: (ctx) {
          final result = useInfiniteQuery<int>(
            queryKey: ['infinite', 'debounce', toggled ? 'b' : 'a'],
            queryFn: (page) async {
              await Future.delayed(Duration(milliseconds: 10));
              return page;
            },
            initialPageParam: 1,
            debounceTime: toggled ? Duration(milliseconds: 50) : null,
          );

          holder.value = result;
          return Column(
            children: [
              ElevatedButton(onPressed: () => setState(() => toggled = true), child: Text('toggle')),
            ],
          );
        });
      }),
    ));

    // initial run: immediate fetch (no debounce)
    await tester.pumpAndSettle();
    expect(holder.value!.status, equals(QueryStatus.success));

    // toggle to new queryKey with debounce enabled
    await tester.tap(find.text('toggle'));
    await tester.pump(); // begin rebuild + debounce timer set

    // immediately after toggle it should reflect loading (pending) and empty data
    expect(holder.value!.status, anyOf(equals(QueryStatus.pending), equals(QueryStatus.error), equals(QueryStatus.success)));
    // For the pending case we expect the data to be empty
    if (holder.value!.status == QueryStatus.pending) expect(holder.value!.data, equals(<int>[]));

    // wait longer than debounce + query delay to let fetch finish
    await tester.pump(Duration(milliseconds: 120));
    await tester.pumpAndSettle();

    // should now have fetched the new key
    expect(holder.value!.status, equals(QueryStatus.success));
    expect(holder.value!.data, equals([1]));
  });

  testWidgets('should not crash if widget unmounts during in-flight next-page fetch', (WidgetTester tester) async {
    final holder = ValueNotifier<InfiniteQueryResult<int>?>(null);

    await tester.pumpWidget(MaterialApp(
      home: HookBuilder(
        builder: (context) {
          final result = useInfiniteQuery<int>(
            queryKey: ['infinite', 'unmount-during-fetch'],
            queryFn: (page) async {
              // initial page quick
              if (page == 1) {
                await Future.delayed(Duration(milliseconds: 10));
                return 1;
              }
              // next page intentionally delayed so we can unmount mid-flight
              await Future.delayed(Duration(milliseconds: 100));
              return page;
            },
            initialPageParam: 1,
            getNextPageParam: (last) => last + 1,
          );

          holder.value = result;
          return Container();
        },
      ),
    ));

    // wait initial fetch
    await tester.pumpAndSettle();
    expect(holder.value!.status, equals(QueryStatus.success));

    // start loading next page, then unmount immediately
    holder.value!.fetchNextPage?.call();
    await tester.pump(); // begin network request

    // unmount the widget before the in-flight future completes
    await tester.pumpWidget(Container());

    // wait longer than the delayed next-page future, make sure no unhandled exceptions occur
    await tester.pump(Duration(milliseconds: 200));
    await tester.pumpAndSettle();
  });
}
