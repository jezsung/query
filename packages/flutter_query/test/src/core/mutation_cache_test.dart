import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_query/src/core/core.dart';

void main() {
  late QueryClient client;
  late MutationCache cache;

  setUp(() {
    client = QueryClient();
    cache = client.mutationCache;
  });

  tearDown(() {
    client.clear();
  });

  MutationOptions<String, Object, String, void> createOptions({
    List<Object?>? mutationKey,
  }) {
    return MutationOptions<String, Object, String, void>(
      mutationFn: (variables, context) async => 'result: $variables',
      mutationKey: mutationKey,
    );
  }

  group('build', () {
    test(
        'SHOULD create new mutation'
        '', () {
      final mutation = cache.build(createOptions());

      expect(mutation, isA<Mutation>());
    });

    test(
        'SHOULD add mutation to cache'
        '', () {
      final mutation = cache.build(createOptions());

      expect(cache.getAll(), contains(mutation));
    });

    test(
        'SHOULD assign unique mutationId to each mutation'
        '', () {
      final mutation1 = cache.build(createOptions());
      final mutation2 = cache.build(createOptions());
      final mutation3 = cache.build(createOptions());

      expect(mutation1.mutationId, isNot(equals(mutation2.mutationId)));
      expect(mutation2.mutationId, isNot(equals(mutation3.mutationId)));
      expect(mutation3.mutationId, isNot(equals(mutation1.mutationId)));
    });

    test(
        'SHOULD create different mutations for same key (no deduplication)'
        '', () {
      final mutation1 = cache.build(createOptions(mutationKey: const ['key']));
      final mutation2 = cache.build(createOptions(mutationKey: const ['key']));

      expect(mutation1, isNot(same(mutation2)));
      expect(cache.getAll(), hasLength(2));
    });
  });

  group('add', () {
    test(
        'SHOULD add mutation to cache'
        '', () {
      final mutation = cache.build(createOptions());
      cache.remove(mutation);
      expect(cache.getAll(), isEmpty);

      cache.add(mutation);

      expect(cache.getAll(), contains(mutation));
    });

    test(
        'SHOULD NOT add duplicate mutation instances'
        '', () {
      final mutation = cache.build(createOptions());

      cache.add(mutation);
      cache.add(mutation);

      expect(cache.getAll(), hasLength(1));
    });
  });

  group('remove', () {
    test(
        'SHOULD remove mutation from cache'
        '', () {
      final mutation = cache.build(createOptions());
      expect(cache.getAll(), contains(mutation));

      cache.remove(mutation);

      expect(cache.getAll(), isEmpty);
    });

    // Note: dispose() is called but we can't easily verify it without
    // adding an isDisposed getter. The important behavior is that remove()
    // calls dispose() which cancels any pending GC timers.

    test(
        'SHOULD NOT throw '
        'WHEN removing already removed mutation', () {
      final mutation = cache.build(createOptions());
      cache.remove(mutation);

      // Should not throw when removing already removed mutation
      expect(() => cache.remove(mutation), returnsNormally);
    });
  });

  group('getAll', () {
    test(
        'SHOULD return empty list '
        'WHEN cache is empty', () {
      final mutations = cache.getAll();

      expect(mutations, isEmpty);
    });

    test(
        'SHOULD return all mutations in cache'
        '', () {
      cache.build(createOptions(mutationKey: const ['key1']));
      cache.build(createOptions(mutationKey: const ['key2']));
      cache.build(createOptions(mutationKey: const ['key3']));

      final mutations = cache.getAll();

      expect(mutations, hasLength(3));
    });

    test(
        'SHOULD return copy of mutations list'
        '', () {
      cache.build(createOptions());

      final mutations1 = cache.getAll();
      final mutations2 = cache.getAll();

      expect(mutations1, isNot(same(mutations2)));
      expect(mutations1.length, equals(mutations2.length));

      var i = 0;
      while (i < mutations1.length && i < mutations2.length) {
        final mut1 = mutations1[i];
        final mut2 = mutations2[i];
        i++;
        expect(mut1, same(mut2));
      }
    });
  });

  group('clear', () {
    test(
        'SHOULD remove all mutations from cache'
        '', () {
      cache.build(createOptions(mutationKey: const ['key1']));
      cache.build(createOptions(mutationKey: const ['key2']));
      cache.build(createOptions(mutationKey: const ['key3']));

      cache.clear();

      expect(cache.getAll(), isEmpty);
    });

    // Note: dispose() is called on all mutations but we can't easily verify
    // it without adding an isDisposed getter. The important behavior is that
    // clear() calls dispose() on each mutation which cancels any pending GC timers.
  });

  group('find', () {
    setUp(() {
      cache.build(createOptions(mutationKey: const ['users']));
      cache.build(createOptions(mutationKey: const ['users', '1']));
      cache.build(createOptions(mutationKey: const ['users', '2']));
      cache.build(createOptions(mutationKey: const ['posts']));
      cache.build(createOptions(mutationKey: const ['posts', '1']));
    });

    test(
        'SHOULD find mutation by exact key match (default)'
        '', () {
      final mutation = cache.find(mutationKey: const ['users', '1']);

      expect(mutation, isNotNull);
      expect(mutation!.options.mutationKey, equals(const ['users', '1']));
    });

    test(
        'SHOULD return null '
        'WHEN exact match is not found', () {
      final mutation = cache.find(mutationKey: const ['users', '3']);

      expect(mutation, isNull);
    });

    test(
        'SHOULD find mutation by prefix match '
        'WHEN exact is false', () {
      final mutation = cache.find(
        mutationKey: const ['users'],
        exact: false,
      );

      expect(mutation, isNotNull);
      expect(mutation!.options.mutationKey![0], equals('users'));
    });

    test(
        'SHOULD find mutation using predicate'
        '', () {
      final mutation = cache.find(
        predicate: (m) =>
            m.options.mutationKey != null && m.options.mutationKey!.length == 2,
      );

      expect(mutation, isNotNull);
      expect(mutation!.options.mutationKey!.length, equals(2));
    });

    test(
        'SHOULD find mutation by status filter'
        '', () {
      // All mutations start with idle status
      final idleMutation = cache.find(status: MutationStatus.idle);
      final pendingMutation = cache.find(status: MutationStatus.pending);

      expect(idleMutation, isNotNull);
      expect(pendingMutation, isNull);
    });

    test(
        'SHOULD combine mutationKey and predicate filters'
        '', () {
      final mutation = cache.find(
        mutationKey: const ['users'],
        exact: false,
        predicate: (m) =>
            m.options.mutationKey != null && m.options.mutationKey!.length == 2,
      );

      expect(mutation, isNotNull);
      expect(mutation!.options.mutationKey![0], equals('users'));
      expect(mutation.options.mutationKey!.length, equals(2));
    });

    test(
        'SHOULD return null '
        'WHEN no filters match', () {
      final mutation = cache.find(
        mutationKey: const ['comments'],
      );

      expect(mutation, isNull);
    });
  });

  group('findAll', () {
    setUp(() {
      cache.build(createOptions(mutationKey: const ['users']));
      cache.build(createOptions(mutationKey: const ['users', '1']));
      cache.build(createOptions(mutationKey: const ['users', '2']));
      cache.build(createOptions(mutationKey: const ['posts']));
      cache.build(createOptions(mutationKey: const ['posts', '1']));
    });

    test(
        'SHOULD return all mutations '
        'WHEN no filters provided', () {
      final mutations = cache.findAll();

      expect(mutations, hasLength(5));
    });

    test(
        'SHOULD find all mutations by exact key match'
        '', () {
      final mutations = cache.findAll(
        mutationKey: const ['users', '1'],
        exact: true,
      );

      expect(mutations, hasLength(1));
      expect(mutations[0].options.mutationKey, equals(const ['users', '1']));
    });

    test(
        'SHOULD return empty list '
        'WHEN exact match is not found', () {
      final mutations = cache.findAll(
        mutationKey: const ['users', '3'],
        exact: true,
      );

      expect(mutations, isEmpty);
    });

    test(
        'SHOULD find all mutations by prefix match'
        '', () {
      final mutations = cache.findAll(
        mutationKey: const ['users'],
        exact: false,
      );

      expect(mutations, hasLength(3));
      for (final mutation in mutations) {
        expect(mutation.options.mutationKey![0], equals('users'));
      }
    });

    test(
        'SHOULD return empty list '
        'WHEN prefix match not found', () {
      final mutations = cache.findAll(
        mutationKey: const ['comments'],
        exact: false,
      );

      expect(mutations, isEmpty);
    });

    test(
        'SHOULD find all mutations using predicate'
        '', () {
      final mutations = cache.findAll(
        predicate: (m) =>
            m.options.mutationKey != null && m.options.mutationKey!.length == 2,
      );

      expect(mutations, hasLength(3));
      for (final mutation in mutations) {
        expect(mutation.options.mutationKey!.length, equals(2));
      }
    });

    test(
        'SHOULD return empty list '
        'WHEN predicate matches nothing', () {
      final mutations = cache.findAll(
        predicate: (m) =>
            m.options.mutationKey != null && m.options.mutationKey!.length == 5,
      );

      expect(mutations, isEmpty);
    });

    test(
        'SHOULD find all mutations by status filter'
        '', () {
      // All mutations start with idle status
      final idleMutations = cache.findAll(status: MutationStatus.idle);
      final pendingMutations = cache.findAll(status: MutationStatus.pending);

      expect(idleMutations, hasLength(5));
      expect(pendingMutations, isEmpty);
    });

    test(
        'SHOULD combine mutationKey, predicate and status filters'
        '', () {
      final mutations = cache.findAll(
        mutationKey: const ['users'],
        exact: false,
        predicate: (m) =>
            m.options.mutationKey != null && m.options.mutationKey!.length == 2,
        status: MutationStatus.idle,
      );

      expect(mutations, hasLength(2));
      for (final mutation in mutations) {
        expect(mutation.options.mutationKey![0], equals('users'));
        expect(mutation.options.mutationKey!.length, equals(2));
        expect(mutation.state.status, equals(MutationStatus.idle));
      }
    });

    test(
        'SHOULD return empty list '
        'WHEN combined filters match nothing', () {
      final mutations = cache.findAll(
        mutationKey: const ['users'],
        exact: false,
        status: MutationStatus.success,
      );

      expect(mutations, isEmpty);
    });
  });
}
