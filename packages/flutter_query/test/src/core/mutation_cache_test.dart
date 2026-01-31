import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_query/src/core/core.dart';
import '../../utils.dart';

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

  group('Method: getAll', () {
    test(
        'SHOULD return empty list '
        'WHEN cache is empty', () {
      final mutations = cache.getAll();

      expect(mutations, isEmpty);
    });

    test(
        'SHOULD return all mutations in cache'
        '', () {
      final mutation1 = Mutation<String, Object, String, void>.cached(
        client,
        mutationKey: const ['key', 1],
      );
      final mutation2 = Mutation<String, Object, String, void>.cached(
        client,
        mutationKey: const ['key', 2],
      );
      final mutation3 = Mutation<String, Object, String, void>.cached(
        client,
        mutationKey: const ['key', 3],
      );

      final mutations = cache.getAll();

      expect(mutations, hasLength(3));
      expect(mutations, contains(mutation1));
      expect(mutations, contains(mutation2));
      expect(mutations, contains(mutation3));
    });

    test(
        'SHOULD return copy of mutations list'
        '', () {
      Mutation<String, Object, String, void>.cached(client);
      Mutation<String, Object, String, void>.cached(client);
      Mutation<String, Object, String, void>.cached(client);

      final mutations1 = cache.getAll();
      final mutations2 = cache.getAll();

      expect(mutations1, isNot(same(mutations2)));
      expect(mutations1.length, equals(mutations2.length));

      for (var i = 0; i < mutations1.length; i++) {
        expect(mutations1[i], same(mutations2[i]));
      }
    });
  });

  group('Method: add', () {
    test(
        'SHOULD add mutation to cache'
        '', () {
      final mutation = Mutation<String, Object, String, void>(client);

      expect(cache.getAll(), isEmpty);

      cache.add(mutation);

      expect(cache.getAll(), contains(mutation));
    });

    test(
        'SHOULD NOT add duplicate mutations'
        '', () {
      final mutation = Mutation<String, Object, String, void>(client);

      cache.add(mutation);
      cache.add(mutation);

      expect(cache.getAll(), hasLength(1));
    });
  });

  group('Method: remove', () {
    test(
        'SHOULD remove mutation from cache'
        '', () {
      final mutation = Mutation<String, Object, String, void>.cached(client);

      expect(cache.getAll(), contains(mutation));

      cache.remove(mutation);

      expect(cache.getAll(), isEmpty);
    });

    test(
        'SHOULD NOT throw '
        'WHEN removing already removed mutation', () {
      final mutation = Mutation<String, Object, String, void>.cached(client);

      cache.remove(mutation);

      expect(
        () => cache.remove(mutation),
        returnsNormally,
      );
    });
  });

  group('Method: clear', () {
    test(
        'SHOULD remove all mutations from cache'
        '', () {
      Mutation<String, Object, String, void>.cached(client);
      Mutation<String, Object, String, void>.cached(client);
      Mutation<String, Object, String, void>.cached(client);

      expect(cache.getAll(), hasLength(3));

      cache.clear();

      expect(cache.getAll(), isEmpty);
    });
  });

  group('Method: find', () {
    setUp(() {
      Mutation<String, Object, String, void>.cached(
        client,
        mutationKey: const ['users'],
      );
      Mutation<String, Object, String, void>.cached(
        client,
        mutationKey: const ['users', '1'],
      );
      Mutation<String, Object, String, void>.cached(
        client,
        mutationKey: const ['users', '2'],
      );
      Mutation<String, Object, String, void>.cached(
        client,
        mutationKey: const ['posts'],
      );
      Mutation<String, Object, String, void>.cached(
        client,
        mutationKey: const ['posts', '1'],
      );
    });

    tearDown(() {
      client.clear();
    });

    test(
        'SHOULD find mutation by exact key match'
        '', () {
      final mutation = cache.find(mutationKey: const ['users', '1']);

      expect(mutation, isNotNull);
      expect(mutation!.mutationKey, equals(const ['users', '1']));
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
      expect(mutation!.mutationKey![0], equals('users'));
    });

    test(
        'SHOULD find mutation using predicate'
        '', () {
      final mutation = cache.find(
        predicate: (key, state) => key != null && key.length == 2,
      );

      expect(mutation, isNotNull);
      expect(mutation!.mutationKey!.length, equals(2));
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
        predicate: (key, state) => key != null && key.length == 2,
      );

      expect(mutation, isNotNull);
      expect(mutation!.mutationKey![0], equals('users'));
      expect(mutation.mutationKey!.length, equals(2));
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

  group('Method: findAll', () {
    setUp(() {
      Mutation<String, Object, String, void>.cached(
        client,
        mutationKey: const ['users'],
      );
      Mutation<String, Object, String, void>.cached(
        client,
        mutationKey: const ['users', '1'],
      );
      Mutation<String, Object, String, void>.cached(
        client,
        mutationKey: const ['users', '2'],
      );
      Mutation<String, Object, String, void>.cached(
        client,
        mutationKey: const ['posts'],
      );
      Mutation<String, Object, String, void>.cached(
        client,
        mutationKey: const ['posts', '1'],
      );
    });

    tearDown(() {
      client.clear();
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
      expect(mutations[0].mutationKey, equals(const ['users', '1']));
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
        expect(mutation.mutationKey![0], equals('users'));
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
        predicate: (key, state) => key != null && key.length == 2,
      );

      expect(mutations, hasLength(3));
      for (final mutation in mutations) {
        expect(mutation.mutationKey!.length, equals(2));
      }
    });

    test(
        'SHOULD return empty list '
        'WHEN predicate matches nothing', () {
      final mutations = cache.findAll(
        predicate: (key, state) => key != null && key.length == 5,
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
        predicate: (key, state) => key != null && key.length == 2,
        status: MutationStatus.idle,
      );

      expect(mutations, hasLength(2));
      for (final mutation in mutations) {
        expect(mutation.mutationKey![0], equals('users'));
        expect(mutation.mutationKey!.length, equals(2));
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

  group('Method: subscribe', () {
    test(
        'SHOULD receive MutationAddedEvent '
        'WHEN mutation is added', () {
      final events = <MutationCacheEvent>[];
      cache.subscribe(events.add);

      final mutation1 = Mutation<String, Object, String, void>(client);
      final mutation2 = Mutation<String, Object, String, void>(client);
      final mutation3 = Mutation<String, Object, String, void>(client);
      cache
        ..add(mutation1)
        ..add(mutation2)
        ..add(mutation3);

      expect(events, hasLength(3));
      expect(events, everyElement(isA<MutationAddedEvent>()));
      expect(
        events.map((e) => (e as MutationAddedEvent).mutation),
        orderedEquals([same(mutation1), same(mutation2), same(mutation3)]),
      );
    });

    test(
        'SHOULD receive MutationRemovedEvent '
        'WHEN mutation is removed via remove()', () {
      final mutation = Mutation<String, Object, String, void>.cached(client);
      final events = <MutationCacheEvent>[];

      cache.subscribe(events.add);
      cache.remove(mutation);

      expect(events, hasLength(1));
      expect(events[0], isA<MutationRemovedEvent>());
      expect((events[0] as MutationRemovedEvent).mutation, same(mutation));
    });

    test(
        'SHOULD receive MutationRemovedEvent '
        'WHEN mutation is removed via clear()', () {
      final mutation1 = Mutation<String, Object, String, void>.cached(client);
      final mutation2 = Mutation<String, Object, String, void>.cached(client);
      final mutation3 = Mutation<String, Object, String, void>.cached(client);
      final events = <MutationCacheEvent>[];

      cache.subscribe(events.add);
      cache.clear();

      expect(events, hasLength(3));
      expect(events, everyElement(isA<MutationRemovedEvent>()));
      expect(
        events.map((e) => (e as MutationRemovedEvent).mutation),
        containsAll([mutation1, mutation2, mutation3]),
      );
    });

    test(
        'SHOULD NOT receive MutationRemovedEvent '
        'WHEN removing non-existent mutation', () {
      final mutation = Mutation<String, Object, String, void>(client);
      final events = <MutationCacheEvent>[];

      cache.subscribe(events.add);
      cache.remove(mutation);

      expect(events, isEmpty);
    });

    test(
        'SHOULD NOT receive MutationRemovedEvent '
        'WHEN clear() called on empty cache', () {
      final events = <MutationCacheEvent>[];

      cache.subscribe(events.add);
      cache.clear();

      expect(events, isEmpty);
    });

    test(
        'SHOULD receive MutationUpdatedEvent '
        'WHEN mutation state changes via execute()', withFakeAsync((async) {
      final mutation = Mutation<String, Object, String, void>.cached(client);
      final events = <MutationCacheEvent>[];

      cache.subscribe(events.add);
      mutation.execute(
        'variables',
        (variables, context) async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data';
        },
      );

      var event = events[0] as MutationUpdatedEvent;
      expect(event.mutation, same(mutation));
      expect(event.mutation.state.status, MutationStatus.pending);

      async.elapse(const Duration(seconds: 1));

      event = events[1] as MutationUpdatedEvent;
      expect(event.mutation, same(mutation));
      expect(event.mutation.state.status, MutationStatus.success);
      expect(event.mutation.state.data, 'data');
    }));

    test(
        'SHOULD return unsubscribe function that removes listener'
        '', () {
      final events = <MutationCacheEvent>[];
      final unsubscribe = cache.subscribe(events.add);

      Mutation<String, Object, String, void>.cached(client);
      expect(events, hasLength(1));

      unsubscribe();

      Mutation<String, Object, String, void>.cached(client);
      expect(events, hasLength(1)); // No new events
    });

    test(
        'SHOULD support multiple listeners'
        '', () {
      final events1 = <MutationCacheEvent>[];
      final events2 = <MutationCacheEvent>[];
      final events3 = <MutationCacheEvent>[];

      cache.subscribe(events1.add);
      cache.subscribe(events2.add);
      cache.subscribe(events3.add);
      Mutation<String, Object, String, void>.cached(client);

      expect(events1, hasLength(1));
      expect(events2, hasLength(1));
      expect(events3, hasLength(1));
      expect(events1[0], same(events2[0]));
      expect(events2[0], same(events3[0]));
      expect(events3[0], same(events1[0]));
    });
  });
}
