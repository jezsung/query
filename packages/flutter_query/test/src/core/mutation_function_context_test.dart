import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_query/src/core/core.dart';

void main() {
  late QueryClient client;

  setUp(() {
    client = QueryClient();
  });

  tearDown(() {
    client.dispose();
  });

  group('toString', () {
    test(
        'SHOULD return debug-friendly string '
        'WHEN called with default fields', () {
      final context = MutationFunctionContext(client: client);

      expect(
        context.toString(),
        'MutationFunctionContext('
        'client: $client, '
        'meta: null, '
        'mutationKey: null)',
      );
    });

    test(
        'SHOULD return debug-friendly string '
        'WHEN called with all fields', () {
      final context = MutationFunctionContext(
        client: client,
        meta: {'source': 'api'},
        mutationKey: ['users', 'create'],
      );

      expect(
        context.toString(),
        'MutationFunctionContext('
        'client: $client, '
        'meta: {source: api}, '
        'mutationKey: [users, create])',
      );
    });
  });
}
