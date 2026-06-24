import 'package:flutter_hooks_test/flutter_hooks_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_query/src/core/core.dart' show QueryClient;
import 'package:flutter_query/src/experiments/mutation_snapshot.dart';
import 'package:flutter_query/src/experiments/use_mutation.dart';
import '../../utils.dart';

void main() {
  late QueryClient client;

  setUp(() {
    client = QueryClient();
  });

  tearDown(() {
    client.clear();
  });

  testWidgets('idle then pending then success', withCleanup((tester) async {
    final hookResult = await buildHook(
      () => useMutation<String, Object, int, void>(
        (variables, context) async {
          await Future.delayed(const Duration(seconds: 5));
          return 'done:$variables';
        },
        client: client,
      ),
    );

    expect(hookResult.current, isA<MutationIdle<String, Object, int>>());

    hookResult.current.mutate(7);
    await tester.pump();

    expect(hookResult.current, isA<MutationPending<String, Object, int>>());
    final pending = hookResult.current as MutationPending<String, Object, int>;
    expect(pending.variables, 7);

    await tester.pump(const Duration(seconds: 5));

    final snapshot = hookResult.current;
    expect(snapshot, isA<MutationSuccess<String, Object, int>>());
    final success = snapshot as MutationSuccess<String, Object, int>;
    expect(success.data, 'done:7');
    expect(success.variables, 7);
  }));

  testWidgets('pending then error', withCleanup((tester) async {
    final error = Exception('nope');
    final hookResult = await buildHook(
      () => useMutation<String, Object, int, void>(
        (variables, context) async {
          await Future.delayed(const Duration(seconds: 5));
          throw error;
        },
        retry: (_, __) => null,
        client: client,
      ),
    );

    hookResult.current.mutate(7);
    await tester.pump();
    expect(hookResult.current, isA<MutationPending<String, Object, int>>());

    await tester.pump(const Duration(seconds: 5));

    final snapshot = hookResult.current;
    expect(snapshot, isA<MutationError<String, Object, int>>());
    final err = snapshot as MutationError<String, Object, int>;
    expect(err.error, same(error));
    expect(err.variables, 7);
    expect(err.dataOrNull, isNull);
  }));
}
