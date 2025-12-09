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
}
