import 'package:test/test.dart';

import 'package:flutter_query/flutter_query.dart';

void main() {
  late QueryClient client1;
  late QueryClient client2;
  late AbortController controller1;
  late AbortController controller2;

  setUp(() {
    client1 = QueryClient();
    client2 = QueryClient();
    controller1 = AbortController();
    controller2 = AbortController();
  });

  tearDown(() {
    client1.dispose();
    client2.dispose();
  });

  test(
      'SHOULD NOT match another QueryContext '
      'WHEN queryKey != queryKey', () {
    final context1 = QueryContext(
      queryKey: ['users', 123],
      client: client1,
      signal: controller1.signal,
    );
    final context2 = QueryContext(
      queryKey: ['users', 456],
      client: client1,
      signal: controller1.signal,
    );

    expect(context1, isNot(equals(context2)));
  });

  test(
      'SHOULD NOT match another QueryContext '
      'WHEN client != client', () {
    final context1 = QueryContext(
      queryKey: ['users', 123],
      client: client1,
      signal: controller1.signal,
    );
    final context2 = QueryContext(
      queryKey: ['users', 123],
      client: client2,
      signal: controller1.signal,
    );

    expect(context1, isNot(equals(context2)));
  });

  test(
      'SHOULD match another QueryContext '
      'WHEN signal == signal OR signal != signal '
      'AND other properties all match', () {
    // signal == signal
    {
      final context1 = QueryContext(
        queryKey: ['users', 123],
        client: client1,
        signal: controller1.signal,
      );
      final context2 = QueryContext(
        queryKey: ['users', 123],
        client: client1,
        signal: controller1.signal,
      );

      expect(context1, equals(context2));
    }
    // signal != signal
    {
      final context1 = QueryContext(
        queryKey: ['users', 123],
        client: client1,
        signal: controller1.signal,
      );
      final context2 = QueryContext(
        queryKey: ['users', 123],
        client: client1,
        signal: controller2.signal,
      );

      expect(context1, equals(context2));
    }
  });
}
