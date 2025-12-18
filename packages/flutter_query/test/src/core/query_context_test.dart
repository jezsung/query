import 'package:test/test.dart';

import 'package:flutter_query/flutter_query.dart';

void main() {
  late QueryClient client1;
  late QueryClient client2;

  setUp(() {
    client1 = QueryClient();
    client2 = QueryClient();
  });

  tearDown(() {
    client1.dispose();
    client2.dispose();
  });

  test('SHOULD match WHEN queryKey and client are same', () {
    final context1 = QueryContext(queryKey: ['users', 123], client: client1);
    final context2 = QueryContext(queryKey: ['users', 123], client: client1);

    expect(context1, equals(context2));
    expect(context1.hashCode, equals(context2.hashCode));
  });

  test('SHOULD NOT match WHEN queryKey is different', () {
    final context1 = QueryContext(queryKey: ['users', 123], client: client1);
    final context2 = QueryContext(queryKey: ['users', 456], client: client1);

    expect(context1, isNot(equals(context2)));
  });

  test('SHOULD NOT match WHEN client is different', () {
    final context1 = QueryContext(queryKey: ['users', 123], client: client1);
    final context2 = QueryContext(queryKey: ['users', 123], client: client2);

    expect(context1, isNot(equals(context2)));
  });
}
