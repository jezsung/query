import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_query/src/hooks/use_query.dart';
import 'package:query_core/query_core.dart';

void main() {
  setUp(() {
    // Ensure a fresh QueryClient instance and clear cache between tests
    QueryClient();
    cacheQuery.clear();
  });

  testWidgets('should fetch and succeed', (WidgetTester tester) async {
    final holder = ValueNotifier<QueryResult<String>?>(null);

    await tester.pumpWidget(MaterialApp(
      home: HookBuilder(builder: (context) {
        final query = useQuery<String>(
          queryKey: ['fetch-success'],
          queryFn: () async {
            await Future.delayed(Duration(milliseconds: 10));
            return 'ok';
          },
        );

        // expose the query to the test
        holder.value = query;

        // return an empty container, we assert on the hook state directly
        return Container();
      }),
    ));

    // initial state read from the hook directly
    expect(holder.value!.status, equals(QueryStatus.pending));

    // let the query start and finish
    await tester.pump();
    await tester.pumpAndSettle();

    // assert the hook result itself
    expect(holder.value!.status, equals(QueryStatus.success));
    expect(holder.value!.data, equals('ok'));

    // The cache should also contain the successful result
    final key = queryKeyToCacheKey(['fetch-success']);
    expect((cacheQuery[key]!.result as QueryResult<String>).data, equals('ok'));
  });

  testWidgets('should fetch and fail', (WidgetTester tester) async {
    final holder = ValueNotifier<QueryResult<String>?>(null);

    await tester.pumpWidget(MaterialApp(
      home: HookBuilder(builder: (context) {
        final result = useQuery<String>(
          queryKey: ['fetch-fail'],
          queryFn: () async {
            await Future.delayed(Duration(milliseconds: 10));
            throw Exception('boom');
          },
        );

        holder.value = result;

        return Container();
      }),
    ));
    // run the build and let the hook run the failing query
    await tester.pump();

    // wait for the hook to update to error status (with a small timeout)
    var tries = 0;
    while ((holder.value == null || holder.value!.status == QueryStatus.pending) && tries < 20) {
      await tester.pump(Duration(milliseconds: 10));
      tries++;
    }

    expect(holder.value, isNotNull);
    expect(holder.value!.status, equals(QueryStatus.error));
    expect(holder.value!.error.toString(), contains('boom'));

    // cache should contain the failing result as well (if the hook updated the cache)
    final cacheKey = queryKeyToCacheKey(['fetch-fail']);
    if (cacheQuery.containsKey(cacheKey)) {
      final cached = cacheQuery[cacheKey]!.result as QueryResult<String>;
      expect(cached.status, equals(QueryStatus.error));
      expect(cached.error.toString(), contains('boom'));
    }
  });

  testWidgets('should not fetch when enabled is false', (WidgetTester tester) async {
    var called = false;

    await tester.pumpWidget(MaterialApp(
      home: HookBuilder(builder: (context) {
        useQuery<String>(
          queryKey: ['disabled'],
          queryFn: () async {
            called = true;
            return 'ok';
          },
          enabled: false,
        );

        return Container();
      }),
    ));

    // give a bit of time
    await tester.pump();

    expect(called, isFalse);
  });

  testWidgets('should fetch when enabled is changed from false to true', (WidgetTester tester) async {
    final holder = ValueNotifier<QueryResult<String>?>(null);
    var called = 0;

    await tester.pumpWidget(MaterialApp(
      home: HookBuilder(builder: (context) {
        final result = useQuery<String>(
          queryKey: ['toggle-enable-key'],
          queryFn: () async {
            called++;
            await Future.delayed(Duration(milliseconds: 5));
            return 'value-$called';
          },
          enabled: false,
        );

        holder.value = result;

        return Container();
      }),
    ));

    // initial build: enabled=false so should NOT call
    await tester.pump();
    expect(called, equals(0));

    // enable the query by rebuilding with enabled = true
    await tester.pumpWidget(MaterialApp(
      home: HookBuilder(builder: (context) {
        final result = useQuery<String>(
          queryKey: ['toggle-enable-key'],
          queryFn: () async {
            called++;
            await Future.delayed(Duration(milliseconds: 5));
            return 'value-$called';
          },
          enabled: true,
        );

        holder.value = result;
        return Container();
      }),
    ));

    // allow async to run
    await tester.pumpAndSettle();

    expect(called, greaterThan(0));
    expect(holder.value!.status, equals(QueryStatus.success));
    expect(holder.value!.data, contains('value-'));
  });

  testWidgets('should refetch when data is stale', (WidgetTester tester) async {
    final key = queryKeyToCacheKey(['stale-key']);
    final holder = ValueNotifier<QueryResult<String>?>(null);

    // populate cache with old timestamp
    cacheQuery[key] = CacheQuery(QueryResult<String>(key, QueryStatus.success, 'old', null),
        DateTime.now().subtract(Duration(milliseconds: 200)));

    // removed external callback; assert on the rendered UI

    await tester.pumpWidget(MaterialApp(
      home: HookBuilder(builder: (context) {
        final result = useQuery<String>(
          queryKey: ['stale-key'],
          queryFn: () async {
            await Future.delayed(Duration(milliseconds: 5));
            return 'fresh';
          },
          staleTime: 100, // ms -> cached entry older than this
        );

        holder.value = result;

        return Container();
      }),
    ));

    // initial state should detect stale and fetch
    await tester.pump();
    await tester.pumpAndSettle();

    expect(holder.value!.data, equals('fresh'));
    // cache should be updated with fresh value
    final cacheKey = queryKeyToCacheKey(['stale-key']);
    expect((cacheQuery[cacheKey]!.result as QueryResult<String>).data, equals('fresh'));
  });

  testWidgets('should not refetch when data is not null and not stale', (WidgetTester tester) async {
    final key = queryKeyToCacheKey(['fresh-key']);

    // populate cache with recent timestamp
    cacheQuery[key] = CacheQuery(QueryResult<String>(key, QueryStatus.success, 'cached', null), DateTime.now());

    var called = false;

    final holder = ValueNotifier<QueryResult<String>?>(null);

    await tester.pumpWidget(MaterialApp(
      home: HookBuilder(builder: (context) {
        final result = useQuery<String>(
          queryKey: ['fresh-key'],
          queryFn: () async {
            called = true;
            return 'should-not-run';
          },
          staleTime: 1000, // large staleTime so the cached is not stale
        );

        holder.value = result;

        return Container();
      }),
    ));

    // initial state should use cached result and NOT call queryFn
    await tester.pump();

    expect(called, isFalse);
    expect(holder.value!.status, equals(QueryStatus.success));
    expect(holder.value!.data, equals('cached'));
  });
}

// No helper widgets — tests inspect the hook result directly via ValueNotifiers.
