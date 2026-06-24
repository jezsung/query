import 'package:flutter_hooks_test/flutter_hooks_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_query/src/core/core.dart' show QueryClient;
import 'package:flutter_query/src/experiments/infinite_query_snapshot.dart';
import 'package:flutter_query/src/experiments/use_infinite_query.dart';
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
      () => useInfiniteQuery<String, Object, int>(
        const ['feed'],
        (context) async {
          await Future.delayed(const Duration(seconds: 5));
          return 'page-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        client: client,
      ),
    );

    expect(
        hookResult.current, isA<InfiniteQueryPending<String, Object, int>>());
    expect(hookResult.current.isLoading, isTrue);

    await tester.pump(const Duration(seconds: 5));

    final snapshot = hookResult.current;
    expect(snapshot, isA<InfiniteQuerySuccess<String, Object, int>>());
    final success = snapshot as InfiniteQuerySuccess<String, Object, int>;
    expect(success.pages, ['page-0']);
    expect(success.pageParams, [0]);
    expect(success.isIdle, isTrue);
  }));

  testWidgets('pending then error', withCleanup((tester) async {
    final error = Exception('nope');
    final hookResult = await buildHook(
      () => useInfiniteQuery<String, Object, int>(
        const ['feed'],
        (context) async {
          await Future.delayed(const Duration(seconds: 5));
          throw error;
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        retry: (_, __) => null,
        client: client,
      ),
    );

    expect(
        hookResult.current, isA<InfiniteQueryPending<String, Object, int>>());

    await tester.pump(const Duration(seconds: 5));

    final snapshot = hookResult.current;
    expect(snapshot, isA<InfiniteQueryError<String, Object, int>>());
    expect((snapshot as InfiniteQueryError<String, Object, int>).error,
        same(error));
    expect(snapshot.dataOrNull, isNull);
    expect(snapshot.isLoadingError, isTrue);
  }));

  testWidgets('SHOULD gate rebuilds with a snapshot-typed shouldRebuild',
      withCleanup((tester) async {
    var builds = 0;
    InfiniteQuerySnapshot<String, Object, int>? seenNext;

    final hookResult = await buildHook(() {
      builds++;
      return useInfiniteQuery<String, Object, int>(
        const ['feed'],
        (context) async {
          await Future.delayed(const Duration(seconds: 5));
          return 'page-${context.pageParam}';
        },
        initialPageParam: 0,
        nextPageParamBuilder: (data) => data.pageParams.last + 1,
        shouldRebuild: (previous, next) {
          seenNext = next;
          return false;
        },
        client: client,
      );
    });

    expect(builds, 1);
    expect(
        hookResult.current, isA<InfiniteQueryPending<String, Object, int>>());

    await tester.pump(const Duration(seconds: 5));

    // Success delivered to the predicate as a snapshot, but suppressed.
    expect(builds, 1);
    expect(
        hookResult.current, isA<InfiniteQueryPending<String, Object, int>>());
    expect(seenNext, isA<InfiniteQuerySuccess<String, Object, int>>());
  }));
}
