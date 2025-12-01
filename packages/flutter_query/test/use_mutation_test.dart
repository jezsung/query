import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_query/src/hooks/use_mutation.dart';

void main() {
  testWidgets('should mutate and succeed when mutate is called', (WidgetTester tester) async {
    String? successData;

    await tester.pumpWidget(MaterialApp(
      home: HookBuilder(
        builder: (context) {
          final result = useMutation<String, String>(
            (params) async {
              // simulate async operation
              await Future.delayed(Duration(milliseconds: 10));
              return 'ok';
            },
            onSuccess: (data) => successData = data,
            spreadCallBackLocalyOnly: true,
          );

          return Column(
            children: [
              Text(result.status.toString(), key: Key('status')),
              ElevatedButton(onPressed: () => result.mutate('p'), child: Text('mutate')),
            ],
          );
        },
      ),
    ));

    // initial state is idle
    expect(find.text('MutationStatus.idle'), findsOneWidget);

    await tester.tap(find.text('mutate'));
    await tester.pump(); // start async

    // should be pending while in-flight
    expect(find.text('MutationStatus.pending'), findsOneWidget);

    // finish the async mutation
    await tester.pumpAndSettle();

    // should end as success
    expect(find.text('MutationStatus.success'), findsOneWidget);
    expect(successData, equals('ok'));
  });

  testWidgets('should mutate and fail when mutate is called', (WidgetTester tester) async {
    Object? errorObj;

    await tester.pumpWidget(MaterialApp(
      home: HookBuilder(
        builder: (context) {
          final result = useMutation<String, String>(
            (params) async {
              // simulate async error
              await Future.delayed(Duration(milliseconds: 10));
              throw Exception('boom');
            },
            onError: (e) => errorObj = e,
            spreadCallBackLocalyOnly: true,
          );

          return Column(
            children: [
              Text(result.status.toString(), key: Key('status')),
              ElevatedButton(onPressed: () => result.mutate('p'), child: Text('mutate')),
            ],
          );
        },
      ),
    ));

    // initial state is idle
    expect(find.text('MutationStatus.idle'), findsOneWidget);

    await tester.tap(find.text('mutate'));
    await tester.pump(); // start async

    // should be pending while in-flight
    expect(find.text('MutationStatus.pending'), findsOneWidget);

    // finish the async mutation which should throw
    await tester.pumpAndSettle();

    // should end as error
    expect(find.text('MutationStatus.error'), findsOneWidget);
    expect(errorObj, isNotNull);
  });
}
