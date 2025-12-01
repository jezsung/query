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
    String? successData;

    await tester.pumpWidget(MaterialApp(
      home: HookBuilder(builder: (context) {
        final result = useQuery<String>(
          queryFn: () async {
            await Future.delayed(Duration(milliseconds: 10));
            return 'ok';
          },
          queryKey: ['fetch-success'],
          onSuccess: (d) => successData = d,
          spreadCallBackLocalyOnly: true,
        );

        return Column(children: [Text(result.status.toString()), Text(result.data ?? '')]);
      }),
    ));

    // initial state is pending
    expect(find.text('QueryStatus.pending'), findsOneWidget);

    // let the query start
    await tester.pump();

    // wait for completion
    await tester.pumpAndSettle();

    expect(find.text('QueryStatus.success'), findsOneWidget);
    expect(find.text('ok'), findsOneWidget);
    expect(successData, equals('ok'));
  });

  testWidgets('should fetch and fail', (WidgetTester tester) async {
    Object? errorObj;

    await tester.pumpWidget(MaterialApp(
      home: HookBuilder(builder: (context) {
        final result = useQuery<String>(
          queryFn: () async {
            await Future.delayed(Duration(milliseconds: 10));
            throw Exception('boom');
          },
          queryKey: ['fetch-fail'],
          onError: (e) => errorObj = e,
          spreadCallBackLocalyOnly: true,
        );

        return Column(children: [Text(result.status.toString()), Text(result.error?.toString() ?? '')]);
      }),
    ));

    expect(find.text('QueryStatus.pending'), findsOneWidget);

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('QueryStatus.error'), findsOneWidget);
    expect(errorObj, isNotNull);
  });

  testWidgets('should not fetch when enabled is false', (WidgetTester tester) async {
    var called = false;

    await tester.pumpWidget(MaterialApp(
      home: HookBuilder(builder: (context) {
        useQuery<String>(
          queryFn: () async {
            called = true;
            return 'ok';
          },
          queryKey: ['disabled'],
          enabled: false,
          spreadCallBackLocalyOnly: true,
        );

        return Container();
      }),
    ));

    // give a bit of time
    await tester.pump();

    expect(called, isFalse);
  });

  testWidgets('should fetch when enabled is changed from false to true', (WidgetTester tester) async {
    String? resultData;
    var called = 0;

    await tester.pumpWidget(MaterialApp(
      home: _ToggleEnableTest(
        queryFn: () async {
          called++;
          await Future.delayed(Duration(milliseconds: 5));
          return 'value-$called';
        },
        onGotResult: (v) => resultData = v,
      ),
    ));

    // initial build: enabled=false so should NOT call
    await tester.pump();
    expect(called, equals(0));

    // tap toggle button to enable
    await tester.tap(find.byKey(Key('toggle')));
    await tester.pump();

    // allow async to run
    await tester.pumpAndSettle();

    expect(called, greaterThan(0));
    expect(resultData, isNotNull);
  });

  testWidgets('should refetch when data is stale', (WidgetTester tester) async {
    final key = queryKeyToCacheKey(['stale-key']);

    // populate cache with old timestamp
    cacheQuery[key] = CacheQuery(QueryResult<String>(key, QueryStatus.success, 'old', null),
        DateTime.now().subtract(Duration(milliseconds: 200)));

    String? data;

    await tester.pumpWidget(MaterialApp(
      home: HookBuilder(builder: (context) {
        final result = useQuery<String>(
          queryFn: () async {
            await Future.delayed(Duration(milliseconds: 5));
            return 'fresh';
          },
          queryKey: ['stale-key'],
          staleTime: 100, // ms -> cached entry older than this
          spreadCallBackLocalyOnly: true,
          onSuccess: (d) => data = d,
        );

        return Column(children: [Text(result.status.toString()), Text(result.data ?? '')]);
      }),
    ));

    // initial state should detect stale and fetch
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('QueryStatus.success'), findsOneWidget);
    expect(find.text('fresh'), findsOneWidget);
    expect(data, equals('fresh'));
  });

  testWidgets('should not refetch when data is not null and not stale', (WidgetTester tester) async {
    final key = queryKeyToCacheKey(['fresh-key']);

    // populate cache with recent timestamp
    cacheQuery[key] = CacheQuery(QueryResult<String>(key, QueryStatus.success, 'cached', null), DateTime.now());

    var called = false;

    await tester.pumpWidget(MaterialApp(
      home: HookBuilder(builder: (context) {
        final result = useQuery<String>(
          queryFn: () async {
            called = true;
            return 'should-not-run';
          },
          queryKey: ['fresh-key'],
          staleTime: 1000, // large staleTime so the cached is not stale
          spreadCallBackLocalyOnly: true,
        );

        return Column(children: [Text(result.status.toString()), Text(result.data ?? '')]);
      }),
    ));

    // initial state should use cached result and NOT call queryFn
    await tester.pump();

    expect(called, isFalse);
    expect(find.text('QueryStatus.success'), findsOneWidget);
    expect(find.text('cached'), findsOneWidget);
  });
}

// Helper widget to toggle enabled
class _ToggleEnableTest extends StatefulWidget {
  final Future<String> Function() queryFn;
  final void Function(String?) onGotResult;

  _ToggleEnableTest({required this.queryFn, required this.onGotResult});

  @override
  State<_ToggleEnableTest> createState() => _ToggleEnableTestState();
}

class _ToggleEnableTestState extends State<_ToggleEnableTest> {
  bool enabled = false;

  @override
  Widget build(BuildContext context) {
    return HookBuilder(builder: (context) {
      final result = useQuery<String>(
        queryFn: () async {
          final value = await widget.queryFn();
          widget.onGotResult(value);
          return value;
        },
        queryKey: ['toggle-enable-key'],
        enabled: enabled,
        spreadCallBackLocalyOnly: true,
      );

      return Column(children: [Text(result.status.toString()), ElevatedButton(onPressed: () => setState(() => enabled = true), key: Key('toggle'), child: Text('toggle'))]);
    });
  }
}
