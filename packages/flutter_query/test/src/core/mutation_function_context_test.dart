import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_query/src/core/core.dart';

void main() {
  late QueryClient client;

  setUp(() {
    client = QueryClient();
  });

  tearDown(() {
    client.clear();
  });

  group('toString', () {
    test(
        'SHOULD return debug-friendly string '
        'WHEN called with empty meta and null mutationKey', () {
      final context = MutationFunctionContext(
        client: client,
        meta: const {},
        mutationKey: null,
      );

      expect(
        context.toString(),
        'MutationFunctionContext('
        'mutationKey: null, '
        'client: $client, '
        'meta: {})',
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
        'mutationKey: [users, create], '
        'client: $client, '
        'meta: {source: api})',
      );
    });
  });
}
