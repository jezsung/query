import 'package:flutter/material.dart';
import 'package:flutter_query/flutter_query.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_query_example/main.dart';

void main() {
  late QueryClient client;

  setUp(() {
    client = QueryClient(
      defaultQueryOptions: DefaultQueryOptions(
        gcDuration: GcDuration.infinity,
      ),
    );
  });

  tearDown(() {
    client.clear();
  });

  testWidgets('SHOULD succeed with data after 3 seconds', (tester) async {
    await tester.pumpWidget(
      QueryClientProvider.value(
        client,
        child: MaterialApp(home: Example()),
      ),
    );

    expect(find.text('Loading...'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));

    expect(find.text('Hello, Flutter Query!'), findsOneWidget);
  });
}
