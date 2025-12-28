import 'package:test/test.dart';

import 'package:flutter_query/src/core/core.dart';

void main() {
  test('SHOULD match WHEN keys are same', () {
    const key1 = QueryKey(['users', 123]);
    const key2 = QueryKey(['users', 123]);

    expect(key1, equals(key2));
    expect(key1.hashCode, equals(key2.hashCode));
  });

  test('SHOULD NOT match WHEN keys are different', () {
    const key1 = QueryKey(['users', 123]);
    const key2 = QueryKey(['users', 456]);

    expect(key1, isNot(equals(key2)));
  });

  test('SHOULD NOT match WHEN lengths are different', () {
    const key1 = QueryKey(['users']);
    const key2 = QueryKey(['users', 123]);

    expect(key1, isNot(equals(key2)));
  });

  test('SHOULD work as map key', () {
    final map = <QueryKey, String>{};
    const key1 = QueryKey(['users', 123]);

    map[key1] = 'value1';

    expect(map[key1], 'value1');
    expect(map.length, 1);
  });

  test('SHOULD NOT match WHEN order of items are different', () {
    const key1 = QueryKey(['users', 123]);
    const key2 = QueryKey([123, 'users']);

    expect(key1, isNot(equals(key2)));
  });

  test('SHOULD match WHEN both keys are empty', () {
    const key1 = QueryKey([]);
    const key2 = QueryKey([]);

    expect(key1, equals(key2));
  });

  test('SHOULD match WHEN keys are not constant', () {
    final key1 = QueryKey(['users', 123]);
    final key2 = QueryKey(['users', 123]);

    expect(key1, equals(key2));
    expect(key1.hashCode, equals(key2.hashCode));
  });

  test('toString()', () {
    expect(
      QueryKey(['users', 123]).toString(),
      "[users, 123]",
    );
    expect(
      QueryKey([
        {'id': 123, 'name': 'test'}
      ]).toString(),
      "[{id: 123, name: test}]",
    );
  });

  group('deep collection equality', () {
    test('SHOULD match WHEN nested lists have same elements in same order', () {
      final key1 = QueryKey([
        'users',
        [1, 2, 3]
      ]);
      final key2 = QueryKey([
        'users',
        [1, 2, 3]
      ]);

      expect(key1, equals(key2));
      expect(key1.hashCode, equals(key2.hashCode));
    });

    test('SHOULD NOT match WHEN nested lists have different order', () {
      final key1 = QueryKey([
        'users',
        [1, 2, 3]
      ]);
      final key2 = QueryKey([
        'users',
        [3, 2, 1]
      ]);

      expect(key1, isNot(equals(key2)));
    });

    test('SHOULD match WHEN nested maps have different key order', () {
      const key1 = QueryKey([
        {'id': 123, 'name': 'test'}
      ]);
      const key2 = QueryKey([
        {'name': 'test', 'id': 123}
      ]);

      expect(key1, equals(key2));
      expect(key1.hashCode, equals(key2.hashCode));
    });

    test('SHOULD match WHEN maps contain equal nested collections', () {
      final key1 = QueryKey([
        'query',
        {
          'ids': [1, 2],
          'tags': {'a', 'b'}
        }
      ]);
      final key2 = QueryKey([
        'query',
        {
          'tags': {'b', 'a'},
          'ids': [1, 2]
        }
      ]);

      expect(key1, equals(key2));
      expect(key1.hashCode, equals(key2.hashCode));
    });

    test('SHOULD match WHEN nested sets have different element order', () {
      const key1 = QueryKey([
        {'users', 123}
      ]);
      const key2 = QueryKey([
        {123, 'users'}
      ]);

      expect(key1, equals(key2));
      expect(key1.hashCode, equals(key2.hashCode));
    });
  });

  group('startsWith', () {
    test('SHOULD return true WHEN key starts with prefix', () {
      const key = QueryKey(['users', '1']);
      const prefix = QueryKey(['users']);

      expect(key.startsWith(prefix), isTrue);
    });

    test('SHOULD return true WHEN key is exact same as prefix', () {
      const key = QueryKey(['users', '1']);
      const prefix = QueryKey(['users', '1']);

      expect(key.startsWith(prefix), isTrue);
    });

    test('SHOULD return false WHEN prefix is longer than key', () {
      const key = QueryKey(['users']);
      const prefix = QueryKey(['users', '1']);

      expect(key.startsWith(prefix), isFalse);
    });

    test('SHOULD return false WHEN prefix does not match', () {
      const key = QueryKey(['users', '1']);
      const prefix = QueryKey(['posts']);

      expect(key.startsWith(prefix), isFalse);
    });

    test('SHOULD return false WHEN only partial segments match', () {
      const key1 = QueryKey(['users', '1']);
      const prefix1 = QueryKey(['users', '2']);

      expect(key1.startsWith(prefix1), isFalse);

      const key2 = QueryKey(['users', '1', 'posts', '1']);
      const prefix2 = QueryKey(['users', '1', 'posts', '2']);

      expect(key2.startsWith(prefix2), isFalse);
    });

    test('SHOULD return true WHEN prefix is empty', () {
      const key = QueryKey(['users', '1']);
      const prefix = QueryKey([]);

      expect(key.startsWith(prefix), isTrue);
    });

    test('SHOULD return true WHEN both are empty', () {
      const key = QueryKey([]);
      const prefix = QueryKey([]);

      expect(key.startsWith(prefix), isTrue);
    });

    test('SHOULD return true with multiple segments', () {
      const key = QueryKey(['users', '1', 'posts', '42']);
      const prefix = QueryKey(['users', '1', 'posts']);

      expect(key.startsWith(prefix), isTrue);
    });

    test('SHOULD return false WHEN first segment differs', () {
      const key = QueryKey(['users', '1']);
      const prefix = QueryKey(['posts', '1']);

      expect(key.startsWith(prefix), isFalse);
    });

    test('SHOULD return false WHEN middle segment differs', () {
      const key = QueryKey(['users', '1', 'posts']);
      const prefix = QueryKey(['users', '2']);

      expect(key.startsWith(prefix), isFalse);
    });

    group('deep collection equality', () {
      test('SHOULD return true WHEN segments contain equal nested lists', () {
        final key = QueryKey([
          'users',
          [1, 2, 3],
          'posts'
        ]);
        final prefix = QueryKey([
          'users',
          [1, 2, 3]
        ]);

        expect(key.startsWith(prefix), isTrue);
      });

      test(
          'SHOULD return true WHEN segments contain maps with different key order',
          () {
        final key = QueryKey([
          'users',
          {'id': 1, 'name': 'test'},
          'posts'
        ]);
        final prefix = QueryKey([
          'users',
          {'name': 'test', 'id': 1}
        ]);

        expect(key.startsWith(prefix), isTrue);
      });

      test(
          'SHOULD return true WHEN segments contain sets with different element order',
          () {
        final key = QueryKey([
          'users',
          {1, 2, 3},
          'posts'
        ]);
        final prefix = QueryKey([
          'users',
          {3, 2, 1}
        ]);

        expect(key.startsWith(prefix), isTrue);
      });

      test(
          'SHOULD return false WHEN segments contain lists with different order',
          () {
        final key = QueryKey([
          'users',
          [1, 2, 3],
          'posts'
        ]);
        final prefix = QueryKey([
          'users',
          [3, 2, 1]
        ]);

        expect(key.startsWith(prefix), isFalse);
      });

      test(
          'SHOULD return false WHEN segments contain maps with different values',
          () {
        final key = QueryKey([
          'users',
          {'id': 1, 'name': 'test'},
          'posts'
        ]);
        final prefix = QueryKey([
          'users',
          {'id': 2, 'name': 'test'}
        ]);

        expect(key.startsWith(prefix), isFalse);
      });

      test(
          'SHOULD return false WHEN segments contain sets with different elements',
          () {
        final key = QueryKey([
          'users',
          {1, 2, 3},
          'posts'
        ]);
        final prefix = QueryKey([
          'users',
          {4, 5, 6}
        ]);

        expect(key.startsWith(prefix), isFalse);
      });
    });
  });
}
