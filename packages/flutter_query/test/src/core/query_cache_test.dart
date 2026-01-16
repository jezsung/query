import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_query/src/core/core.dart';

void main() {
  late QueryClient client;
  late QueryCache cache;

  setUp(() {
    client = QueryClient();
    cache = client.cache;
  });

  tearDown(() {
    client.clear();
  });

  group('build', () {
    test('SHOULD create and cache new query', () {
      final query = cache.build(QueryOptions(
        const ['key1'],
        (context) async => 'data',
      ));

      expect(query, isA<Query>());
      expect(query.key.parts, equals(const ['key1']));
    });

    test('SHOULD return same query for same key', () {
      final query1 = cache.build(QueryOptions(
        const ['key1'],
        (context) async => 'data1',
      ));
      final query2 = cache.build(QueryOptions(
        const ['key1'],
        (context) async => 'data2',
      ));

      expect(query1, same(query2));
    });

    test('SHOULD create different queries for different keys', () {
      final query1 = cache.build(QueryOptions(
        const ['key1'],
        (context) async => 'data1',
      ));
      final query2 = cache.build(QueryOptions(
        const ['key2'],
        (context) async => 'data2',
      ));

      expect(query1, isNot(same(query2)));
    });
  });

  group('get', () {
    test('SHOULD return null WHEN query does not exist', () {
      final query = cache.get(const ['nonexistent']);
      expect(query, isNull);
    });

    test('SHOULD return query WHEN it exists', () {
      cache.build(QueryOptions(
        const ['key1'],
        (context) async => 'data',
      ));

      final query = cache.get(const ['key1']);
      expect(query, isNotNull);
      expect(query!.key.parts, equals(const ['key1']));
    });
  });

  group('getAll', () {
    test('SHOULD return empty list WHEN cache is empty', () {
      final queries = cache.getAll();

      expect(queries, isEmpty);
    });

    test('SHOULD return all queries in cache', () {
      cache.build(QueryOptions(
        const ['key1'],
        (context) async => 'data1',
      ));
      cache.build(QueryOptions(
        const ['key2'],
        (context) async => 'data2',
      ));
      cache.build(QueryOptions(
        const ['key3'],
        (context) async => 'data3',
      ));

      final queries = cache.getAll();

      expect(queries, hasLength(3));
    });

    test('SHOULD return copy of the queries list', () {
      cache.build(QueryOptions(
        const ['key1'],
        (context) async => 'data1',
      ));

      final queries1 = cache.getAll();
      final queries2 = cache.getAll();

      expect(queries1, isNot(same(queries2)));
      expect(queries1.length, equals(queries2.length));
    });

    test('SHOULD return same queries in list', () {
      cache.build(QueryOptions(
        const ['key1'],
        (context) async => 'data1',
      ));
      cache.build(QueryOptions(
        const ['key2'],
        (context) async => 'data2',
      ));

      final queries1 = cache.getAll();
      final queries2 = cache.getAll();

      expect(queries1.length, equals(queries2.length));
      for (var i = 0; i < queries1.length; i++) {
        expect(queries1[i], same(queries2[i]));
      }
    });
  });

  group('remove', () {
    test('SHOULD remove query from cache', () {
      final query = cache.build(QueryOptions(
        const ['key1'],
        (context) async => 'data',
      ));

      cache.remove(query);

      expect(cache.get(const ['key1']), isNull);
    });

    // test('SHOULD dispose query WHEN removed', () {
    //   final query = cache.build(QueryOptions(
    //     const ['key1'],
    //     (context) async => 'data',
    //   ));

    //   expect(query.isClosed, false);

    //   cache.remove(query);

    //   expect(query.isClosed, true);
    // });

    test('SHOULD NOT remove different query with same key', () {
      final query1 = cache.build(QueryOptions(
        const ['key1'],
        (context) async => 'data1',
      ));

      // Manually create a different query instance (not in cache)
      final query2 = Query(
        client,
        QueryOptions(
          const ['key1'],
          (context) async => 'data2',
        ),
      );

      // Try to remove query2 (which is not the one in cache)
      cache.remove(query2);

      // query1 should still be in cache since it's a different instance
      expect(cache.get(const ['key1']), same(query1));
    });
  });

  group('removeByKey', () {
    test('SHOULD remove query from cache', () {
      cache.build(QueryOptions(
        const ['key1'],
        (context) async => 'data',
      ));

      cache.removeByKey(const ['key1']);

      expect(cache.get(const ['key1']), isNull);
    });

    // test('SHOULD dispose query WHEN removed', () {
    //   final query = cache.build(QueryOptions(
    //     const ['key1'],
    //     (context) async => 'data',
    //   ));

    //   expect(query.isClosed, false);

    //   cache.removeByKey(const ['key1']);

    //   expect(query.isClosed, true);
    // });
  });

  group('clear', () {
    test('SHOULD remove all queries from cache', () {
      cache.build(QueryOptions(
        const ['key1'],
        (context) async => 'data1',
      ));
      cache.build(QueryOptions(
        const ['key2'],
        (context) async => 'data2',
      ));
      cache.build(QueryOptions(
        const ['key3'],
        (context) async => 'data3',
      ));

      cache.clear();

      expect(cache.getAll(), isEmpty);
      expect(cache.get(const ['key1']), isNull);
      expect(cache.get(const ['key2']), isNull);
      expect(cache.get(const ['key3']), isNull);
    });

    // test('SHOULD dispose all queries', () {
    //   final query1 = cache.build(QueryOptions(
    //     const ['key1'],
    //     (context) async => 'data1',
    //   ));
    //   final query2 = cache.build(QueryOptions(
    //     const ['key2'],
    //     (context) async => 'data2',
    //   ));

    //   expect(query1.isClosed, isFalse);
    //   expect(query2.isClosed, isFalse);

    //   cache.clear();

    //   expect(cache.getAll(), isEmpty);
    //   expect(query1.isClosed, isTrue);
    //   expect(query2.isClosed, isTrue);
    // });
  });

  group('find', () {
    setUp(() {
      cache.build(QueryOptions(
        const ['users'],
        (context) async => 'users data',
      ));
      cache.build(QueryOptions(
        const ['users', '1'],
        (context) async => 'user 1 data',
      ));
      cache.build(QueryOptions(
        const ['users', '2'],
        (context) async => 'user 2 data',
      ));
      cache.build(QueryOptions(
        const ['posts'],
        (context) async => 'posts data',
      ));
      cache.build(QueryOptions(
        const ['posts', '1'],
        (context) async => 'post 1 data',
      ));
    });

    tearDown(() {
      cache.clear();
    });

    test('SHOULD find query by exact key match', () {
      final query = cache.find(
        const ['users', '1'],
        exact: true,
      );

      expect(query, isNotNull);
      expect(query!.key.parts, equals(const ['users', '1']));
    });

    test('SHOULD return null WHEN exact match not found', () {
      final query = cache.find(
        const ['users', '3'],
        exact: true,
      );

      expect(query, isNull);
    });

    test('SHOULD find query by prefix match', () {
      final query = cache.find(
        const ['users'],
        exact: false,
      );

      expect(query, isNotNull);
      expect(query!.key[0], equals('users'));
    });

    test('SHOULD return null WHEN prefix match not found', () {
      final query = cache.find(
        const ['comments'],
        exact: false,
      );

      expect(query, isNull);
    });

    test('SHOULD find query using predicate', () {
      final query = cache.find(
        const ['posts'],
        exact: false,
        predicate: (q) => q.key.length == 2,
      );

      expect(query, isNotNull);
      expect(query!.key[0], equals('posts'));
      expect(query.key.length, equals(2));
    });

    test('SHOULD return null WHEN predicate matches nothing', () {
      final query = cache.find(
        const ['comments'],
        exact: false,
      );

      expect(query, isNull);
    });

    test('SHOULD combine queryKey and predicate filters', () {
      final query = cache.find(
        const ['users'],
        exact: false,
        predicate: (q) => q.key.length == 2,
      );

      expect(query, isNotNull);
      expect(query!.key[0], equals('users'));
      expect(query.key.length, equals(2));
    });

    test('SHOULD return null WHEN combined filters match nothing', () {
      final query = cache.find(
        const ['users'],
        exact: false,
        predicate: (q) => q.key.length == 3,
      );

      expect(query, isNull);
    });
  });

  group('findAll', () {
    setUp(() {
      cache.build(QueryOptions(
        const ['users'],
        (context) async => 'users data',
      ));
      cache.build(QueryOptions(
        const ['users', '1'],
        (context) async => 'user 1 data',
      ));
      cache.build(QueryOptions(
        const ['users', '2'],
        (context) async => 'user 2 data',
      ));
      cache.build(QueryOptions(
        const ['posts'],
        (context) async => 'posts data',
      ));
      cache.build(QueryOptions(
        const ['posts', '1'],
        (context) async => 'post 1 data',
      ));
    });

    tearDown(() {
      cache.clear();
    });

    test('SHOULD return all queries WHEN no filters provided', () {
      final queries = cache.findAll();

      expect(queries, hasLength(5));
    });

    test('SHOULD find all queries by exact key match', () {
      final queries = cache.findAll(
        queryKey: const ['users', '1'],
        exact: true,
      );

      expect(queries, hasLength(1));
      expect(queries[0].key.parts, equals(const ['users', '1']));
    });

    test('SHOULD return empty list WHEN exact match not found', () {
      final queries = cache.findAll(
        queryKey: const ['users', '3'],
        exact: true,
      );

      expect(queries, isEmpty);
    });

    test('SHOULD find all queries by prefix match', () {
      final queries = cache.findAll(
        queryKey: const ['users'],
        exact: false,
      );

      expect(queries, hasLength(3));
      for (final query in queries) {
        expect(query.key[0], equals('users'));
      }
    });

    test('SHOULD return empty list WHEN prefix match not found', () {
      final queries = cache.findAll(
        queryKey: const ['comments'],
        exact: false,
      );

      expect(queries, isEmpty);
    });

    test('SHOULD find all queries using predicate', () {
      final queries = cache.findAll(
        predicate: (q) => q.key.length == 2,
      );

      expect(queries, hasLength(3));
      for (final query in queries) {
        expect(query.key.length, equals(2));
      }
    });

    test('SHOULD return empty list WHEN predicate matches nothing', () {
      final queries = cache.findAll(
        predicate: (q) => q.key.length == 5,
      );

      expect(queries, isEmpty);
    });

    test('SHOULD combine queryKey and predicate filters', () {
      final queries = cache.findAll(
        queryKey: const ['users'],
        exact: false,
        predicate: (q) => q.key.length == 2,
      );

      expect(queries, hasLength(2));
      for (final query in queries) {
        expect(query.key[0], equals('users'));
        expect(query.key.length, equals(2));
      }
    });

    test('SHOULD return empty list WHEN combined filters match nothing', () {
      final queries = cache.findAll(
        queryKey: const ['users'],
        exact: false,
        predicate: (q) => q.key.length == 5,
      );

      expect(queries, isEmpty);
    });
  });
}
