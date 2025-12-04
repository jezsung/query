import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_query/src/hooks/use_mutation.dart';
import 'package:query_core/query_core.dart';

void main() {
  setUp(() {
    // Ensure a fresh QueryClient instance between tests
    QueryClient();
  });

// (setUp is declared above)
  testWidgets('should mutate and succeed when mutate is called', (WidgetTester tester) async {
    String? successData;
    final holder = ValueNotifier<MutationResult<String, String>?>(null);

    await tester.pumpWidget(MaterialApp(
      home: HookBuilder(
        builder: (context) {
          final result = useMutation<String, String>(
            mutationFn: (params) async {
              // simulate async operation
              await Future.delayed(Duration(milliseconds: 10));
              return 'ok';
            },
            onSuccess: (data) => successData = data,
          );

          holder.value = result;
          return Container();
        },
      ),
    ));
    // initial state is idle
    expect(holder.value!.status, equals(MutationStatus.idle));

    // start mutation
    holder.value!.mutate('p');
    await tester.pump(); // start async

    // should be pending while in-flight
    expect(holder.value!.status, equals(MutationStatus.pending));

    // finish the async mutation
    await tester.pumpAndSettle();

    // should end as success and data should be available via the result and callback
    expect(holder.value!.status, equals(MutationStatus.success));
    expect(holder.value!.data, equals('ok'));
    expect(successData, equals('ok'));
  });

  testWidgets('should mutate and fail when mutate is called', (WidgetTester tester) async {
    Object? errorObj;
    final holder = ValueNotifier<MutationResult<String, String>?>(null);

    await tester.pumpWidget(MaterialApp(
      home: HookBuilder(
        builder: (context) {
          final result = useMutation<String, String>(
            mutationFn: (params) async {
              // simulate async error
              await Future.delayed(Duration(milliseconds: 10));
              throw Exception('boom');
            },
            onError: (e) => errorObj = e,
          );

          holder.value = result;
          return Container();
        },
      ),
    ));
    // initial state is idle
    expect(holder.value!.status, equals(MutationStatus.idle));

    holder.value!.mutate('p');
    await tester.pump(); // start async

    // should be pending while in-flight
    expect(holder.value!.status, equals(MutationStatus.pending));

    // finish the async mutation which should throw
    await tester.pumpAndSettle();

    // should end as error; result should include the error
    expect(holder.value!.status, equals(MutationStatus.error));
    expect(holder.value!.error, isNotNull);
    expect(holder.value!.error.toString(), contains('boom'));
    expect(errorObj, isNotNull);
  });
}
