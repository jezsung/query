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
    int? successData;

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
            onSuccess: (d) => successData = d,
            spreadCallBackLocalyOnly: true,
          );

          return Column(
            children: [
              Text(result.status.toString()),
              Text((result.data ?? []).join(','), key: Key('data')),
            ],
          );
        },
      ),
    ));

    // initial state is pending
    expect(find.text('QueryStatus.pending'), findsOneWidget);

    // wait async fetch to complete
    await tester.pumpAndSettle();

    // should succeed and onSuccess called and data contains the first page
    expect(find.text('QueryStatus.success'), findsOneWidget);
    expect(find.byKey(Key('data')), findsOneWidget);
    expect(successData, equals(1));
    expect(find.text('1'), findsWidgets);
  });

  testWidgets('should fetch next page when fetchNextPage is called', (WidgetTester tester) async {
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
            spreadCallBackLocalyOnly: true,
          );

          return Column(
            children: [
              Text(result.status.toString()),
              Text((result.data ?? []).join(','), key: Key('data')),
              ElevatedButton(onPressed: () => result.fetchNextPage?.call(), child: Text('fetchNext')),
            ],
          );
        },
      ),
    ));

    // wait initial fetch
    await tester.pumpAndSettle();
    expect(find.text('QueryStatus.success'), findsOneWidget);
    expect(find.text('1'), findsWidgets);

    // request next page
    await tester.tap(find.text('fetchNext'));
    await tester.pump(); // kick off fetch
    await tester.pumpAndSettle();

    // should have two pages now
    expect(find.byKey(Key('data')), findsOneWidget);
    expect(find.text('1,2'), findsOneWidget);
  });

  testWidgets('should set error state when initial fetch fails', (WidgetTester tester) async {
    dynamic errorCaptured;
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
            onError: (e) => errorCaptured = e,
            spreadCallBackLocalyOnly: true,
          );

          return Column(children: [Text(result.status.toString())]);
        },
      ),
    ));

    // pending then settle to error
    expect(find.text('QueryStatus.pending'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('QueryStatus.error'), findsOneWidget);
    expect(errorCaptured, isNotNull);
  });

  testWidgets('should set error state when fetching next page fails', (WidgetTester tester) async {
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
            spreadCallBackLocalyOnly: true,
          );

          return Column(
            children: [
              Text(result.status.toString()),
              Text((result.data ?? []).join(','), key: Key('data')),
              ElevatedButton(onPressed: () => result.fetchNextPage?.call(), child: Text('fetchNext')),
            ],
          );
        },
      ),
    ));

    // wait initial success
    await tester.pumpAndSettle();
    expect(find.text('QueryStatus.success'), findsOneWidget);
    expect(find.text('1'), findsWidgets);

    // attempt to load next page which will throw
    await tester.tap(find.text('fetchNext'));
    await tester.pump(); // start
    await tester.pumpAndSettle(); // finish

    // On next-page error the hook sets status error and clears data
    expect(find.text('QueryStatus.error'), findsOneWidget);
    final dataTextWidgets = find.byKey(Key('data'));
    if (dataTextWidgets.evaluate().isNotEmpty) {
      expect((dataTextWidgets.evaluate().single.widget as Text).data, equals(''));
    }
  });

  testWidgets('should debounce when queryKey changes and debounceTime is set', (WidgetTester tester) async {
    bool toggled = false;

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
            spreadCallBackLocalyOnly: true,
          );

          return Column(
            children: [
              Text(result.status.toString(), key: Key('status')),
              Text((result.data ?? []).join(','), key: Key('data')),
              ElevatedButton(onPressed: () => setState(() => toggled = true), child: Text('toggle')),
            ],
          );
        });
      }),
    ));

    // initial run: immediate fetch (no debounce)
    await tester.pumpAndSettle();
    expect(find.text('QueryStatus.success'), findsOneWidget);

    // toggle to new queryKey with debounce enabled
    await tester.tap(find.text('toggle'));
    await tester.pump(); // begin rebuild + debounce timer set

    // immediately after toggle it should reflect loading (pending) and empty data
    expect(find.text('QueryStatus.pending'), findsOneWidget);
    expect(find.byKey(Key('data')), findsOneWidget);
    expect((tester.widget<Text>(find.byKey(Key('data'))).data ?? ''), equals(''));

    // wait longer than debounce + query delay to let fetch finish
    await tester.pump(Duration(milliseconds: 120));
    await tester.pumpAndSettle();

    // should now have fetched the new key
    expect(find.text('QueryStatus.success'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
  });
}
