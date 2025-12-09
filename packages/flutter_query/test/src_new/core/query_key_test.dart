import 'package:test/test.dart';

import 'package:flutter_query/src_new/core/query_key.dart';

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

  test('SHOULD match WHEN order of keys in inner maps are different', () {
    const key1 = QueryKey([
      {'id': 123, 'name': 'test'}
    ]);
    const key2 = QueryKey([
      {'name': 'test', 'id': 123}
    ]);

    expect(key1, equals(key2));
  });

  test('SHOULD match WHEN order of keys in inner sets are different', () {
    const key1 = QueryKey([
      {'users', 123}
    ]);
    const key2 = QueryKey([
      {123, 'users'}
    ]);

    expect(key1, equals(key2));
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
  });
}
