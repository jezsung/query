import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_query/flutter_query.dart';

/// A test helper that wraps a test body in [fakeAsync] for time manipulation.
void Function() withFakeAsync(void Function(FakeAsync fakeTime) testBody) {
  return () => fakeAsync(testBody);
}

/// Creates an abortable query function for testing.
///
/// This simulates a real network request that respects the abort signal.
/// Uses [Future.any] to race between delay and abort signal.
///
/// The [fn] callback is invoked after the duration elapses. It can return
/// a value or throw an error to test failure cases.
Future<T> Function(QueryContext) abortableQueryFn<T>(
  Duration duration,
  T Function() fn,
) {
  return (context) async {
    await Future.any([
      Future.delayed(duration),
      context.signal.whenAbort,
    ]);
    context.signal.throwIfAborted();
    return fn();
  };
}

void main() {
  late QueryClient client;

  setUp(() {
    client = QueryClient();
  });

  tearDown(() {
    client.dispose();
  });

  Query<String, Object> createQuery({
    List<Object?> queryKey = const ['test'],
  }) {
    return Query<String, Object>(
      client,
      QueryOptions(
        queryKey,
        (context) async => 'data',
      ),
    );
  }

  group('fetch', () {
    group('cancelRefetch', () {
      test(
          'SHOULD return same Future (deduplication) '
          'WHEN cancelRefetch == false', withFakeAsync((async) {
        var invocations = 0;

        final query = Query<String, Object>(
          client,
          QueryOptions(
            const ['key'],
            (context) async {
              final id = ++invocations;
              await Future.any([
                Future.delayed(const Duration(seconds: 1)),
                context.signal.whenAbort,
              ]);
              context.signal.throwIfAborted();
              return 'data-$id';
            },
          ),
        );

        // Establish initial data so cancelRefetch can work
        query.fetch();
        async.elapse(const Duration(seconds: 1));
        expect(invocations, 1);
        expect(query.state.data, 'data-1');

        String? result1;
        String? result2;

        // Start fetch A
        query.fetch().then((d) => result1 = d);

        // Call with cancelRefetch: false - should return SAME future (no new invocation)
        query.fetch(cancelRefetch: false).then((d) => result2 = d);

        async.elapse(const Duration(seconds: 1));

        // Only ONE additional invocation (deduplication - same fetch shared)
        expect(invocations, 2);
        expect(result1, 'data-2');
        expect(result2, 'data-2');
      }));

      test(
          'SHOULD piggyback cancelled fetch Future onto new fetch result '
          'WHEN cancelRefetch == true', withFakeAsync((async) {
        var invocations = 0;

        final query = Query<String, Object>(
          client,
          QueryOptions(
            const ['key'],
            (context) async {
              final id = ++invocations;
              await Future.any([
                Future.delayed(const Duration(seconds: 1)),
                context.signal.whenAbort,
              ]);
              context.signal.throwIfAborted();
              return 'data-$id';
            },
          ),
        );

        // Establish initial data so cancelRefetch can work
        query.fetch();
        async.elapse(const Duration(seconds: 1));
        expect(invocations, 1);
        expect(query.state.data, 'data-1');

        String? result1;
        String? result2;

        // Start fetch A
        query.fetch().then((d) => result1 = d);

        // Call with cancelRefetch: true - cancels A, starts NEW fetch B
        query.fetch(cancelRefetch: true).then((d) => result2 = d);

        async.elapse(const Duration(seconds: 1));

        // TWO additional invocations (A was started then cancelled, B completed)
        expect(invocations, 3);
        // Both get result from fetch B (A was cancelled, result1 piggybacked onto B)
        expect(result1, 'data-3');
        expect(result2, 'data-3');
      }));
    });
  });

  group('QueryMatches.matches', () {
    test(
        'SHOULD match '
        'WHEN no filters provided', () {
      final query = createQuery();

      expect(query.matches(), isTrue);
    });

    test(
        'SHOULD match exact key '
        'WHEN exact == true AND key matches', () {
      final query = createQuery(queryKey: const ['users', '1']);

      expect(
        query.matches(exact: true, queryKey: const ['users', '1']),
        isTrue,
      );
    });

    test(
        'SHOULD NOT match '
        'WHEN exact == true AND key differs', () {
      final query = createQuery(queryKey: const ['users', '1']);

      expect(
        query.matches(exact: true, queryKey: const ['users', '2']),
        isFalse,
      );
    });

    test('SHOULD match partial key', () {
      final query = createQuery(queryKey: const ['users', '1', 'profile']);

      expect(
        query.matches(queryKey: const ['users', '1']),
        isTrue,
      );
    });

    test(
        'SHOULD NOT match partial key '
        'WHEN filter is longer than key', () {
      final query = createQuery(queryKey: const ['users']);

      expect(
        query.matches(exact: false, queryKey: const ['users', '1']),
        isFalse,
      );
    });

    test('SHOULD match predicate', () {
      final query = createQuery(queryKey: const ['users']);

      expect(
        query.matches(predicate: (q) => q.queryKey.first == 'users'),
        isTrue,
      );
    });

    test('SHOULD NOT match predicate', () {
      final query = createQuery(queryKey: const ['posts']);

      expect(
        query.matches(predicate: (q) => q.queryKey.first == 'users'),
        isFalse,
      );
    });

    test(
        'SHOULD match type == all '
        'WHEN query has no observers', () {
      final query = createQuery();

      expect(
        query.matches(type: QueryTypeFilter.all),
        isTrue,
      );
    });

    test(
        'SHOULD match type == inactive '
        'WHEN query has no observers', () {
      final query = createQuery();

      expect(
        query.matches(type: QueryTypeFilter.inactive),
        isTrue,
      );
    });

    test(
        'SHOULD NOT match type == active '
        'WHEN query has no observers', () {
      final query = createQuery();

      expect(
        query.matches(type: QueryTypeFilter.active),
        isFalse,
      );
    });

    test(
        'SHOULD match type == active '
        'WHEN query has enabled observer', () {
      final query = createQuery();
      final observer = QueryObserver<String, Object>(
        client,
        QueryOptions(const ['test'], (context) async => 'data'),
      );
      query.addObserver(observer);

      expect(
        query.matches(type: QueryTypeFilter.active),
        isTrue,
      );
    });

    test(
        'SHOULD NOT match type == inactive '
        'WHEN query has enabled observer', () {
      final query = createQuery();
      final observer = QueryObserver<String, Object>(
        client,
        QueryOptions(const ['test'], (context) async => 'data'),
      );
      query.addObserver(observer);

      expect(
        query.matches(type: QueryTypeFilter.inactive),
        isFalse,
      );
    });

    test(
        'SHOULD match type == inactive '
        'WHEN query has disabled observer', () {
      final query = createQuery();
      final observer = QueryObserver<String, Object>(
        client,
        QueryOptions(
          const ['test'],
          (context) async => 'data',
          enabled: false,
        ),
      );
      query.addObserver(observer);

      expect(
        query.matches(type: QueryTypeFilter.inactive),
        isTrue,
      );
    });

    test('SHOULD require ALL filters to match (AND logic)', () {
      final query = createQuery(queryKey: const ['users', '1']);

      // All match
      expect(
        query.matches(
          queryKey: const ['users'],
          exact: false,
          type: QueryTypeFilter.all,
          predicate: (q) => true,
        ),
        isTrue,
      );

      // One doesn't match (predicate fails)
      expect(
        query.matches(
          queryKey: const ['users'],
          exact: false,
          type: QueryTypeFilter.all,
          predicate: (q) => false,
        ),
        isFalse,
      );
    });
  });
}
