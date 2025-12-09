import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_hooks_test/flutter_hooks_test.dart';
import 'package:flutter_query/src_new/core/core.dart';
import 'package:flutter_query/src_new/hooks/use_query.dart';
import 'package:flutter_query/src_new/widgets/query_client_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../matchers/use_query_result_matcher.dart';

void main() {
  late QueryClient client;

  setUp(() {
    client = QueryClient();
  });

  tearDown(() {
    client.dispose();
  });

  testWidgets('SHOULD find QueryClient provided by QueryClientProvider',
      (tester) async {
    final hookResult = await buildHook(
      () => useQuery(
        queryKey: const ['key'],
        queryFn: () async => 'data',
      ),
      wrapper: (child) => QueryClientProvider(
        client: client,
        child: child,
      ),
    );

    await tester.pumpAndSettle();

    expect(hookResult.current.data, equals('data'));
  });

  testWidgets('SHOULD prioritize queryClient over QueryClientProvider',
      (tester) async {
    final priorQueryClient = QueryClient();

    await buildHook(
      () => useQuery(
        queryKey: const ['key'],
        queryFn: () async => 'data',
        queryClient: priorQueryClient,
      ),
      wrapper: (child) => QueryClientProvider(
        client: client,
        child: child,
      ),
    );

    await tester.pumpAndSettle();

    expect(priorQueryClient.cache.getQuery(const ['key']), isNotNull);
    expect(client.cache.getQuery(const ['key']), isNull);
  });

  testWidgets('SHOULD fetch and succeed', (tester) async {
    const expectedData = 'test data';

    final hookResult = await buildHook(
      () => useQuery(
        queryKey: const ['test'],
        queryFn: () async {
          await Future.delayed(const Duration(milliseconds: 100));
          return expectedData;
        },
        queryClient: client,
      ),
    );

    expect(
      hookResult.current,
      isUseQueryResult(
        status: QueryStatus.pending,
        fetchStatus: FetchStatus.fetching,
        data: null,
        dataUpdatedAt: null,
        error: null,
        errorUpdatedAt: null,
        errorUpdateCount: 0,
        isEnabled: true,
      ),
    );

    await tester.pumpAndSettle();

    expect(
      hookResult.current,
      isUseQueryResult(
        status: QueryStatus.success,
        fetchStatus: FetchStatus.idle,
        data: expectedData,
        dataUpdatedAt: isA<DateTime>(),
        error: null,
        errorUpdatedAt: null,
        errorUpdateCount: 0,
        isEnabled: true,
      ),
    );
  });

  testWidgets('SHOULD fetch and fail', (tester) async {
    final expectedError = Exception();

    final hookResult = await buildHook(
      () => useQuery(
        queryKey: const ['test-error'],
        queryFn: () async {
          await Future.delayed(const Duration(milliseconds: 100));
          throw expectedError;
        },
        queryClient: client,
      ),
    );

    expect(
      hookResult.current,
      isUseQueryResult(
        status: QueryStatus.pending,
        fetchStatus: FetchStatus.fetching,
        data: null,
        dataUpdatedAt: null,
        error: null,
        errorUpdatedAt: null,
        errorUpdateCount: 0,
        isEnabled: true,
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));

    expect(
      hookResult.current,
      isUseQueryResult(
        status: QueryStatus.error,
        fetchStatus: FetchStatus.idle,
        data: null,
        dataUpdatedAt: null,
        error: expectedError,
        errorUpdatedAt: isA<DateTime>(),
        errorUpdateCount: 1,
        isEnabled: true,
      ),
    );
  });

  testWidgets('SHOULD NOT fetch WHEN enabled is false', (tester) async {
    var fetchCount = 0;

    final hookResult = await buildHook(
      () => useQuery<String, Object>(
        queryKey: const ['test-disabled'],
        queryFn: () async {
          fetchCount++;
          return 'data';
        },
        enabled: false,
        queryClient: client,
      ),
    );

    await tester.pumpAndSettle();

    expect(fetchCount, 0);
    expect(
      hookResult.current,
      isUseQueryResult(
        status: QueryStatus.pending,
        fetchStatus: FetchStatus.idle,
        data: null,
        dataUpdatedAt: null,
        error: null,
        errorUpdatedAt: null,
        errorUpdateCount: 0,
        isEnabled: false,
      ),
    );
  });

  testWidgets('SHOULD fetch WHEN enabled changes to true', (tester) async {
    var fetchCount = 0;
    const expectedData = 'data';

    final hookResult = await buildHookWithProps(
      (enabled) => useQuery<String, Object>(
        queryKey: const ['enabled-test'],
        queryFn: () async {
          fetchCount++;
          await Future.delayed(const Duration(milliseconds: 100));
          return expectedData;
        },
        enabled: enabled,
        queryClient: client,
      ),
      initialProps: false,
    );

    expect(fetchCount, 0);
    expect(
      hookResult.current,
      isUseQueryResult(
        status: QueryStatus.pending,
        fetchStatus: FetchStatus.idle,
        data: null,
        dataUpdatedAt: null,
        error: null,
        errorUpdatedAt: null,
        errorUpdateCount: 0,
        isEnabled: false,
      ),
    );

    await hookResult.rebuildWithProps(true);

    expect(fetchCount, 1);
    expect(
      hookResult.current,
      isUseQueryResult(
        status: QueryStatus.pending,
        fetchStatus: FetchStatus.fetching,
        data: null,
        dataUpdatedAt: null,
        error: null,
        errorUpdatedAt: null,
        errorUpdateCount: 0,
        isEnabled: true,
      ),
    );

    await tester.pumpAndSettle();

    expect(fetchCount, 1);
    expect(
      hookResult.current,
      isUseQueryResult(
        status: QueryStatus.success,
        fetchStatus: FetchStatus.idle,
        data: expectedData,
        dataUpdatedAt: isA<DateTime>(),
        error: null,
        errorUpdatedAt: null,
        errorUpdateCount: 0,
        isEnabled: true,
      ),
    );
  });

  testWidgets('SHOULD fetch only once WHEN multiple hooks share same key',
      (tester) async {
    var fetchCount = 0;
    const sharedKey = ["key"];
    const expectedData = 'data';
    late UseQueryResult<String, Object> result1;
    late UseQueryResult<String, Object> result2;

    await tester.pumpWidget(Column(
      children: [
        HookBuilder(
          builder: (context) {
            result1 = useQuery<String, Object>(
              queryKey: sharedKey,
              queryFn: () async {
                fetchCount++;
                await Future.delayed(const Duration(milliseconds: 100));
                return expectedData;
              },
              queryClient: client,
            );
            return Container();
          },
        ),
        HookBuilder(
          builder: (context) {
            result2 = useQuery<String, Object>(
              queryKey: sharedKey,
              queryFn: () async {
                fetchCount++;
                await Future.delayed(const Duration(milliseconds: 100));
                return expectedData;
              },
              queryClient: client,
            );
            return Container();
          },
        ),
      ],
    ));

    expect(fetchCount, 1);
    for (final result in [result1, result2]) {
      expect(
        result,
        isUseQueryResult(
          status: QueryStatus.pending,
          fetchStatus: FetchStatus.fetching,
          data: null,
          dataUpdatedAt: null,
          error: null,
          errorUpdatedAt: null,
          errorUpdateCount: 0,
          isEnabled: true,
        ),
      );
    }

    await tester.pumpAndSettle();

    expect(fetchCount, 1);
    for (final result in [result1, result2]) {
      expect(
        result,
        isUseQueryResult(
          status: QueryStatus.success,
          fetchStatus: FetchStatus.idle,
          data: expectedData,
          dataUpdatedAt: isA<DateTime>(),
          error: null,
          errorUpdatedAt: null,
          errorUpdateCount: 0,
          isEnabled: true,
        ),
      );
    }
  });

  testWidgets('SHOULD fetch again WHEN queryKey changes', (tester) async {
    const key1 = ["key1"];
    const key2 = ["key2"];
    const expectedData1 = 'data1';
    const expectedData2 = 'data2';

    final hookResult = await buildHookWithProps(
      (record) => useQuery<String, Object>(
        queryKey: record.key,
        queryFn: () async {
          await Future.delayed(const Duration(milliseconds: 100));
          return record.data;
        },
        queryClient: client,
      ),
      initialProps: (key: key1, data: expectedData1),
    );

    expect(
      hookResult.current,
      isUseQueryResult(
        status: QueryStatus.pending,
        fetchStatus: FetchStatus.fetching,
        data: null,
        dataUpdatedAt: null,
        error: null,
        errorUpdatedAt: null,
        errorUpdateCount: 0,
        isEnabled: true,
      ),
    );

    await tester.pumpAndSettle();

    expect(
      hookResult.current,
      isUseQueryResult(
        status: QueryStatus.success,
        fetchStatus: FetchStatus.idle,
        data: expectedData1,
        dataUpdatedAt: isA<DateTime>(),
        error: null,
        errorUpdatedAt: null,
        errorUpdateCount: 0,
        isEnabled: true,
      ),
    );

    await hookResult.rebuildWithProps((key: key2, data: expectedData2));

    expect(
      hookResult.current,
      isUseQueryResult(
        status: QueryStatus.pending,
        fetchStatus: FetchStatus.fetching,
        data: null,
        dataUpdatedAt: null,
        error: null,
        errorUpdatedAt: null,
        errorUpdateCount: 0,
        isEnabled: true,
      ),
    );

    await tester.pumpAndSettle();

    expect(
      hookResult.current,
      isUseQueryResult(
        status: QueryStatus.success,
        fetchStatus: FetchStatus.idle,
        data: expectedData2,
        dataUpdatedAt: isA<DateTime>(),
        error: null,
        errorUpdatedAt: null,
        errorUpdateCount: 0,
        isEnabled: true,
      ),
    );
  });

  testWidgets('SHOULD clean up observers on unmount', (tester) async {
    const key = ['key'];

    final hookResult = await buildHook(
      () => useQuery(
        queryKey: key,
        queryFn: () async => 'data',
        queryClient: client,
      ),
    );

    await tester.pumpAndSettle();

    final query = client.cache.getQuery(key)!;

    expect(query.hasObservers, true);

    await hookResult.unmount();

    expect(query.hasObservers, false);
  });

  testWidgets('SHOULD throw WHEN QueryClient is not provided', (tester) async {
    await tester.pumpWidget(HookBuilder(
      builder: (context) {
        useQuery<String, Object>(
          queryKey: const ['test'],
          queryFn: () async => 'data',
        );
        return Container();
      },
    ));

    // Check that a FlutterError was thrown during build
    final exception = tester.takeException();
    expect(exception, isA<FlutterError>());
  });

  testWidgets('SHOULD distinguish between different query keys',
      (tester) async {
    late UseQueryResult<String, Object> result1;
    late UseQueryResult<String, Object> result2;

    await tester.pumpWidget(Column(
      children: [
        HookBuilder(builder: (context) {
          result1 = useQuery<String, Object>(
            queryKey: const ['key1'],
            queryFn: () async => 'data1',
            queryClient: client,
          );
          return Container();
        }),
        HookBuilder(builder: (context) {
          result2 = useQuery<String, Object>(
            queryKey: const ['key2'],
            queryFn: () async => 'data2',
            queryClient: client,
          );
          return Container();
        }),
      ],
    ));

    await tester.pumpAndSettle();

    expect(result1.data, 'data1');
    expect(result2.data, 'data2');
  });
}
