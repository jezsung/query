import 'package:flutter_hooks_test/flutter_hooks_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_query/src/core/core.dart';
import 'package:flutter_query/src/hooks/hooks.dart';
import 'package:flutter_query/src/widgets/widgets.dart';
import '../../utils.dart';

void main() {
  late QueryClient client;

  setUp(() {
    client = QueryClient();
  });

  tearDown(() {
    client.clear();
  });

  testWidgets('SHOULD fetch and succeed from supplied options',
      withCleanup((tester) async {
    final data = Object();

    final hookResult = await buildHook(
      () => useQueryOptions(
        QueryOptions(
          const ['key'],
          (context) async {
            await Future.delayed(const Duration(seconds: 5));
            return data;
          },
        ),
        client: client,
      ),
    );

    expect(hookResult.current.status, QueryStatus.pending);
    expect(hookResult.current.data, null);

    await tester.pump(const Duration(seconds: 5));

    expect(hookResult.current.status, QueryStatus.success);
    expect(hookResult.current.data, same(data));
  }));

  testWidgets('SHOULD surface errors from supplied options',
      withCleanup((tester) async {
    final error = Exception();

    final hookResult = await buildHook(
      () => useQueryOptions<String, Object>(
        QueryOptions(
          const ['key'],
          (context) async {
            await Future.delayed(const Duration(seconds: 5));
            throw error;
          },
          retry: (_, __) => null,
        ),
        client: client,
      ),
    );

    await tester.pump(const Duration(seconds: 5));

    expect(hookResult.current.status, QueryStatus.error);
    expect(hookResult.current.error, same(error));
  }));

  testWidgets('SHOULD react to a changed query key across rebuilds',
      withCleanup((tester) async {
    final hookResult = await buildHookWithProps(
      (key) => useQueryOptions(
        QueryOptions(
          ['key', key],
          (context) async => 'data-$key',
        ),
        client: client,
      ),
      initialProps: 1,
    );

    await tester.pumpAndSettle();
    expect(hookResult.current.data, 'data-1');

    await hookResult.rebuildWithProps(2);
    await tester.pumpAndSettle();
    expect(hookResult.current.data, 'data-2');
  }));

  testWidgets('SHOULD prioritize explicit client over provider',
      withCleanup((tester) async {
    final prioritizedQueryClient = QueryClient();

    final hookResult = await buildHook(
      () => useQueryOptions(
        QueryOptions(
          const ['key'],
          (context) async => 'data',
        ),
        client: prioritizedQueryClient,
      ),
      wrapper: (child) => QueryClientProvider.value(
        client,
        child: child,
      ),
    );

    await tester.pumpAndSettle();

    expect(prioritizedQueryClient.cache.get(const ['key']), isNotNull);
    expect(client.cache.get(const ['key']), isNull);

    await hookResult.unmount();
    prioritizedQueryClient.clear();
  }));
}
