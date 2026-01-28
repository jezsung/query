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

  group('Method: get', () {
    test(
        'SHOULD return null '
        'WHEN query does not exist', () {
      final query = cache.get(const ['key']);

      expect(query, isNull);
    });

    test(
        'SHOULD return query '
        'WHEN query exists', () {
      final expectedQuery = Query<String, Object>.cached(client, const ['key']);

      final returnedQuery = cache.get(const ['key']);

      expect(returnedQuery, same(expectedQuery));
    });
  });

  group('Method: getAll', () {
    test(
        'SHOULD return empty list '
        'WHEN there are no queries in cache', () {
      final queries = cache.getAll();

      expect(queries, isEmpty);
    });

    test(
        'SHOULD return all queries in cache'
        '', () {
      Query<String, Object>.cached(client, const ['key', 1]);
      Query<String, Object>.cached(client, const ['key', 2]);
      Query<String, Object>.cached(client, const ['key', 3]);

      final queries = cache.getAll();

      expect(queries, hasLength(3));
    });

    test(
        'SHOULD return copy of list'
        '', () {
      Query<String, Object>.cached(client, const ['key']);

      final queries1 = cache.getAll();
      final queries2 = cache.getAll();

      expect(queries1, isNot(same(queries2)));
      expect(queries1.length, equals(queries2.length));
    });

    test(
        'SHOULD return same queries in list'
        '', () {
      Query<String, Object>.cached(client, const ['key', 1]);
      Query<String, Object>.cached(client, const ['key', 2]);

      final queries1 = cache.getAll();
      final queries2 = cache.getAll();

      expect(queries1.length, equals(queries2.length));
      for (var i = 0; i < queries1.length; i++) {
        expect(queries1[i], same(queries2[i]));
      }
    });
  });

  group('Method: remove', () {
    test(
        'SHOULD remove query'
        '', () {
      final query1 = Query<String, Object>.cached(client, const ['key', 1]);
      final query2 = Query<String, Object>.cached(client, const ['key', 2]);

      cache.remove(query1);

      expect(cache.get(const ['key', 1]), isNull);
      expect(cache.get(const ['key', 2]), same(query2));
    });

    test(
        'SHOULD NOT remove different query with same key'
        '', () {
      final query1 = Query<String, Object>.cached(client, const ['key']);
      final query2 = Query<String, Object>(client, const ['key']);

      cache.remove(query2);

      expect(cache.get(const ['key']), same(query1));
    });
  });

  group('Method: removeByKey', () {
    test(
        'SHOULD remove query by key'
        '', () {
      Query<String, Object>.cached(client, const ['key', 1]);
      Query<String, Object>.cached(client, const ['key', 2]);

      cache.removeByKey(const ['key', 1]);

      expect(cache.get(const ['key', 1]), isNull);
      expect(cache.get(const ['key', 2]), isNotNull);
    });
  });

  group('Method: clear', () {
    test(
        'SHOULD remove all queries'
        '', () {
      Query<String, Object>.cached(client, const ['key', 1]);
      Query<String, Object>.cached(client, const ['key', 2]);
      Query<String, Object>.cached(client, const ['key', 3]);

      cache.clear();

      expect(cache.get(const ['key', 1]), isNull);
      expect(cache.get(const ['key', 2]), isNull);
      expect(cache.get(const ['key', 3]), isNull);
      expect(cache.getAll(), isEmpty);
    });
  });

  group('Method: find', () {
    setUp(() {
      Query<String, Object>.cached(client, const ['users']);
      Query<String, Object>.cached(client, const ['users', 1]);
      Query<String, Object>.cached(client, const ['users', 2]);
      Query<String, Object>.cached(client, const ['posts']);
      Query<String, Object>.cached(client, const ['posts', 2]);
    });

    tearDown(() {
      cache.clear();
    });

    test(
        'SHOULD find query by exact match'
        '', () {
      final query = cache.find(
        const ['users', 1],
        exact: true,
      );

      expect(query, isNotNull);
      expect(query!.key.parts, equals(const ['users', 1]));
    });

    test(
        'SHOULD return null '
        'WHEN exact match not found', () {
      final query = cache.find(
        const ['users', 3],
        exact: true,
      );

      expect(query, isNull);
    });

    test(
        'SHOULD find query by prefix match'
        'WHEN exact == false', () {
      final query = cache.find(
        const ['users'],
        exact: false,
      );

      expect(query, isNotNull);
      expect(query!.key[0], equals('users'));
    });

    test(
        'SHOULD return null '
        'WHEN prefix match not found', () {
      final query = cache.find(
        const ['comments'],
        exact: false,
      );

      expect(query, isNull);
    });

    test(
        'SHOULD find query by predicate'
        '', () {
      final query = cache.find(
        const ['posts'],
        exact: false,
        predicate: (key, state) => key.length == 2,
      );

      expect(query, isNotNull);
      expect(query!.key.length, equals(2));
      expect(query.key[0], equals('posts'));
    });

    test(
        'SHOULD return null '
        'WHEN predicate matches nothing', () {
      final query = cache.find(
        const ['users'],
        exact: false,
        predicate: (key, state) => key.length == 3,
      );

      expect(query, isNull);
    });
  });

  group('Method: findAll', () {
    setUp(() {
      Query<String, Object>.cached(client, const ['users']);
      Query<String, Object>.cached(client, const ['users', '1']);
      Query<String, Object>.cached(client, const ['users', '2']);
      Query<String, Object>.cached(client, const ['posts']);
      Query<String, Object>.cached(client, const ['posts', '1']);
    });

    tearDown(() {
      cache.clear();
    });

    test(
        'SHOULD return all queries '
        'WHEN no filters provided', () {
      final queries = cache.findAll();

      expect(queries, hasLength(5));
    });

    test(
        'SHOULD find query by exact match'
        'WHEN exact == true', () {
      final queries = cache.findAll(
        queryKey: const ['users', '1'],
        exact: true,
      );

      expect(queries, hasLength(1));
      expect(queries[0].key.parts, equals(const ['users', '1']));
    });

    test(
        'SHOULD return empty list '
        'WHEN exact match not found', () {
      final queries = cache.findAll(
        queryKey: const ['users', '3'],
        exact: true,
      );

      expect(queries, isEmpty);
    });

    test(
        'SHOULD find all queries by prefix match'
        'WHEN exact == false', () {
      final queries = cache.findAll(
        queryKey: const ['users'],
        exact: false,
      );

      expect(queries, hasLength(3));
      for (final query in queries) {
        expect(query.key[0], equals('users'));
      }
    });

    test(
        'SHOULD return empty list '
        'WHEN prefix match not found', () {
      final queries = cache.findAll(
        queryKey: const ['comments'],
        exact: false,
      );

      expect(queries, isEmpty);
    });

    test(
        'SHOULD find all queries by predicate'
        'WHEN predicate != null', () {
      final queries = cache.findAll(
        predicate: (key, state) => key.length == 2,
      );

      expect(queries, hasLength(3));
      for (final query in queries) {
        expect(query.key.length, equals(2));
      }
    });

    test(
        'SHOULD return empty list '
        'WHEN predicate matches nothing', () {
      final queries = cache.findAll(
        predicate: (key, state) => key.length == 5,
      );

      expect(queries, isEmpty);
    });

    test(
        'SHOULD find queries matching both queryKey and predicate'
        'WHEN queryKey != null && predicate != null', () {
      final queries = cache.findAll(
        queryKey: const ['users'],
        exact: false,
        predicate: (key, state) => key.length == 2,
      );

      expect(queries, hasLength(2));
      for (final query in queries) {
        expect(query.key[0], equals('users'));
        expect(query.key.length, equals(2));
      }
    });

    test(
        'SHOULD return empty list '
        'WHEN combined filters match nothing', () {
      final queries = cache.findAll(
        queryKey: const ['users'],
        exact: false,
        predicate: (key, state) => key.length == 5,
      );

      expect(queries, isEmpty);
    });
  });
}
