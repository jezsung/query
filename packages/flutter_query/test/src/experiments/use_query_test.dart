import 'package:flutter_hooks_test/flutter_hooks_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_query/src/core/core.dart' show QueryClient;
import 'package:flutter_query/src/experiments/query_snapshot.dart';
import 'package:flutter_query/src/experiments/use_query.dart';
import '../../utils.dart';

void main() {
  late QueryClient client;

  setUp(() {
    client = QueryClient();
  });

  tearDown(() {
    client.clear();
  });

  testWidgets('pending then success', withCleanup((tester) async {
    final hookResult = await buildHook(
      () => useQuery<String, Object>(
        const ['greeting'],
        (context) async {
          await Future.delayed(const Duration(seconds: 5));
          return 'hello';
        },
        client: client,
      ),
    );

    expect(hookResult.current, isA<QueryPending<String, Object>>());
    expect(hookResult.current.isLoading, isTrue);

    await tester.pump(const Duration(seconds: 5));

    final snapshot = hookResult.current;
    expect(snapshot, isA<QuerySuccess<String, Object>>());
    final String value = (snapshot as QuerySuccess<String, Object>).data;
    expect(value, 'hello');
    expect(snapshot.isIdle, isTrue);
  }));

  testWidgets('pending then error', withCleanup((tester) async {
    final error = Exception('nope');
    final hookResult = await buildHook(
      () => useQuery<String, Object>(
        const ['key'],
        (context) async {
          await Future.delayed(const Duration(seconds: 5));
          throw error;
        },
        retry: (_, __) => null,
        client: client,
      ),
    );

    expect(hookResult.current, isA<QueryPending<String, Object>>());

    await tester.pump(const Duration(seconds: 5));

    final snapshot = hookResult.current;
    expect(snapshot, isA<QueryError<String, Object>>());
    expect((snapshot as QueryError<String, Object>).error, same(error));
    expect(snapshot.data, isNull);
    expect(snapshot.isLoadingError, isTrue);
  }));
}
