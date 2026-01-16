import 'package:flutter/widgets.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_query/flutter_query.dart';

void main() {
  group('Constructor: new', () {
    testWidgets(
        'SHOULD provide created QueryClient'
        '', (tester) async {
      QueryClient? createdClient;
      QueryClient? capturedClient;

      await tester.pumpWidget(QueryClientProvider(
        create: (context) {
          return createdClient = QueryClient();
        },
        child: Builder(
          builder: (context) {
            capturedClient = QueryClientProvider.of(context);

            return const SizedBox();
          },
        ),
      ));

      expect(createdClient, isNotNull);
      expect(capturedClient, same(createdClient));
    });

    testWidgets(
        'SHOULD clear cache in QueryClient '
        'WHEN unmounted', (tester) async {
      final client = QueryClient();

      // Add a query to the cache so we can verify clear was called
      await client.prefetchQuery(
        queryKey: const ['key'],
        queryFn: (context) async => 'data',
      );

      await tester.pumpWidget(QueryClientProvider(
        create: (context) => client,
        child: const SizedBox(),
      ));

      expect(client.cache.get(const ['key']), isNotNull);

      // Remove the provider from the tree
      await tester.pumpWidget(const SizedBox());

      // Verify the cache was cleared
      expect(client.cache.get(const ['key']), isNull);
    });

    testWidgets(
        'SHOULD call create immediately '
        'WHEN lazy == false', (tester) async {
      var called = false;

      await tester.pumpWidget(QueryClientProvider(
        create: (context) {
          called = true;
          return QueryClient();
        },
        lazy: false,
        child: const SizedBox(),
      ));

      expect(called, isTrue);
    });

    testWidgets(
        'SHOULD defer calling create until first access '
        'WHEN lazy == true', (tester) async {
      var called = false;

      await tester.pumpWidget(QueryClientProvider(
        key: Key('$QueryClientProvider'),
        create: (context) {
          called = true;
          return QueryClient();
        },
        lazy: true,
        child: const SizedBox(),
      ));

      // Should NOT have been called yet
      expect(called, isFalse);

      // Now pump a widget that accesses the client
      await tester.pumpWidget(QueryClientProvider(
        key: Key('$QueryClientProvider'),
        create: (context) {
          called = true;
          return QueryClient();
        },
        lazy: true,
        child: Builder(
          builder: (context) {
            QueryClientProvider.of(context);
            return const SizedBox();
          },
        ),
      ));

      // Should have been called now
      expect(called, isTrue);
    });
  });

  group('Constructor: value', () {
    testWidgets(
        'SHOULD provide given QueryClient'
        '', (tester) async {
      final expectedClient = QueryClient();
      QueryClient? capturedClient;

      await tester.pumpWidget(QueryClientProvider.value(
        expectedClient,
        child: Builder(
          builder: (context) {
            capturedClient = QueryClientProvider.of(context);
            return const SizedBox();
          },
        ),
      ));

      expect(capturedClient, same(expectedClient));
    });

    testWidgets(
        'SHOULD NOT clear cache in QueryClient '
        'WHEN unmounted', (tester) async {
      final client = QueryClient();

      // Add a query to the cache so we can verify clear was NOT called
      await client.prefetchQuery(
        queryKey: const ['key'],
        queryFn: (context) async => 'data',
      );

      await tester.pumpWidget(QueryClientProvider.value(
        client,
        child: const SizedBox(),
      ));

      expect(client.cache.get(const ['key']), isNotNull);

      // Remove the provider from the tree
      await tester.pumpWidget(const SizedBox());

      // Verify the cache was NOT cleared (clear was NOT called)
      expect(client.cache.get(const ['key']), isNotNull);

      // Clean up manually
      client.clear();
    });
  });

  group('Method: of', () {
    testWidgets(
        'SHOULD return QueryClient from ancestor provider'
        '', (tester) async {
      final client = QueryClient();
      addTearDown(client.clear);

      await tester.pumpWidget(QueryClientProvider.value(
        client,
        child: Builder(
          builder: (context) {
            expect(QueryClientProvider.of(context), same(client));
            return const SizedBox();
          },
        ),
      ));
    });

    testWidgets(
        'SHOULD throw FlutterError '
        'WHEN no provider is found', (tester) async {
      Object? capturedError;

      await tester.pumpWidget(Builder(
        builder: (context) {
          try {
            QueryClientProvider.of(context);
          } catch (e) {
            capturedError = e;
          }
          return const SizedBox();
        },
      ));

      expect(capturedError, isA<FlutterError>());
    });
  });

  group('Method: maybeOf', () {
    testWidgets(
        'SHOULD return QueryClient from ancestor provider'
        '', (tester) async {
      final client = QueryClient();
      addTearDown(client.clear);

      await tester.pumpWidget(QueryClientProvider.value(
        client,
        child: Builder(
          builder: (context) {
            expect(QueryClientProvider.maybeOf(context), same(client));
            return const SizedBox();
          },
        ),
      ));
    });

    testWidgets(
        'SHOULD return null '
        'WHEN no provider is found', (tester) async {
      await tester.pumpWidget(Builder(
        builder: (context) {
          expect(QueryClientProvider.maybeOf(context), isNull);
          return const SizedBox();
        },
      ));
    });
  });
}
