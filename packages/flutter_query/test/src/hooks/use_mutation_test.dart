import 'dart:async';

import 'package:flutter_hooks_test/flutter_hooks_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_query/src/core/core.dart';
import 'package:flutter_query/src/hooks/hooks.dart';
import '../../utils.dart';

void main() {
  late QueryClient client;

  setUp(() {
    client = QueryClient();
  });

  tearDown(() {
    client.clear();
  });

  group('Parameter: networkMode', () {
    late StreamController<bool> connectivityController;

    setUp(() {
      connectivityController = StreamController<bool>();
      client = QueryClient(
        connectivityChanges: connectivityController.stream,
      );
    });

    tearDown(() {
      client.clear();
      connectivityController.close();
    });

    group('== NetworkMode.online', () {
      // Pauses when offline, resumes when online

      testWidgets(
          'SHOULD execute normally online'
          '', withCleanup((tester) async {
        // Start online
        connectivityController.add(true);

        final hook = await buildHook(
          () => useMutation<String, Object, void, void>(
            (_, __) async {
              await Future.delayed(const Duration(seconds: 1));
              return 'data';
            },
            networkMode: NetworkMode.online,
            client: client,
          ),
        );

        hook.current.mutate(null);
        await tester.pump();
        expect(hook.current.status, MutationStatus.pending);
        expect(hook.current.isPaused, isFalse);

        await tester.pump(const Duration(seconds: 1));
        expect(hook.current.status, MutationStatus.success);
        expect(hook.current.data, 'data');
      }));

      testWidgets(
          'SHOULD pause offline, then resume on going online'
          '', withCleanup((tester) async {
        // Start offline
        connectivityController.add(false);

        final hook = await buildHook(
          () => useMutation<String, Object, void, void>(
            (_, __) async {
              await Future.delayed(const Duration(seconds: 1));
              return 'data';
            },
            networkMode: NetworkMode.online,
            client: client,
          ),
        );

        hook.current.mutate(null);
        await tester.pump();
        expect(hook.current.status, MutationStatus.pending);
        expect(hook.current.isPaused, isTrue);

        // Should be kept paused
        await tester.pump(const Duration(days: 365));
        expect(hook.current.status, MutationStatus.pending);
        expect(hook.current.isPaused, isTrue);

        // Go online
        connectivityController.add(true);
        await tester.pump();
        await tester.pump();
        expect(hook.current.status, MutationStatus.pending);
        expect(hook.current.isPaused, isFalse);

        await tester.pump(const Duration(seconds: 1));
        expect(hook.current.status, MutationStatus.success);
        expect(hook.current.data, 'data');
      }));

      testWidgets(
          'SHOULD pause retries on going offline, then resume on going online'
          '', withCleanup((tester) async {
        // Start online
        connectivityController.add(true);

        var mutateFnCount = 0;
        final hook = await buildHook(
          () => useMutation<String, Object, void, void>(
            (_, __) async {
              mutateFnCount++;
              throw Exception();
            },
            networkMode: NetworkMode.online,
            retry: (retryCount, _) {
              if (retryCount < 3) {
                return const Duration(seconds: 1);
              }
              return null;
            },
            client: client,
          ),
        );

        hook.current.mutate(null);
        await tester.pump();
        expect(hook.current.isPaused, isFalse);
        expect(mutateFnCount, 1);

        // Go offline
        connectivityController.add(false);
        await tester.pump();
        await tester.pump();
        expect(hook.current.isPaused, isTrue);
        expect(mutateFnCount, 1);

        // Go online
        connectivityController.add(true);
        await tester.pump();
        await tester.pump();
        expect(hook.current.isPaused, isFalse);
        expect(mutateFnCount, 2);

        // Wait for remaining retries to complete
        await tester.pump(const Duration(seconds: 1));
        expect(mutateFnCount, 3);
        await tester.pump(const Duration(seconds: 1));
        expect(mutateFnCount, 4);
        expect(hook.current.status, MutationStatus.error);
      }));
    });

    group('== NetworkMode.always', () {
      // Never pauses, ignores network state

      testWidgets(
          'SHOULD execute normally online'
          '', withCleanup((tester) async {
        // Start online
        connectivityController.add(true);

        final hook = await buildHook(
          () => useMutation<String, Object, void, void>(
            (_, __) async {
              await Future.delayed(const Duration(seconds: 1));
              return 'data';
            },
            networkMode: NetworkMode.always,
            client: client,
          ),
        );

        hook.current.mutate(null);
        await tester.pump();
        expect(hook.current.status, MutationStatus.pending);
        expect(hook.current.isPaused, isFalse);

        await tester.pump(const Duration(seconds: 1));
        expect(hook.current.status, MutationStatus.success);
        expect(hook.current.data, 'data');
      }));

      testWidgets(
          'SHOULD execute normally offline'
          '', withCleanup((tester) async {
        // Start offline
        connectivityController.add(false);

        final hook = await buildHook(
          () => useMutation<String, Object, void, void>(
            (_, __) async {
              await Future.delayed(const Duration(seconds: 1));
              return 'data';
            },
            networkMode: NetworkMode.always,
            client: client,
          ),
        );
        expect(hook.current.status, MutationStatus.idle);

        hook.current.mutate(null);
        await tester.pump();
        expect(hook.current.status, MutationStatus.pending);
        expect(hook.current.isPaused, isFalse);

        await tester.pump(const Duration(seconds: 1));
        expect(hook.current.status, MutationStatus.success);
        expect(hook.current.data, 'data');
      }));

      testWidgets(
          'SHOULD NOT pause on going offline'
          '', withCleanup((tester) async {
        // Start online
        connectivityController.add(true);

        final hook = await buildHook(
          () => useMutation<String, Object, void, void>(
            (_, __) async {
              await Future.delayed(const Duration(seconds: 1));
              return 'data';
            },
            networkMode: NetworkMode.always,
            client: client,
          ),
        );

        hook.current.mutate(null);
        await tester.pump();
        expect(hook.current.status, MutationStatus.pending);
        expect(hook.current.isPaused, isFalse);

        // Go offline
        connectivityController.add(false);
        await tester.pump();
        await tester.pump();
        expect(hook.current.status, MutationStatus.pending);
        expect(hook.current.isPaused, isFalse);

        await tester.pump(const Duration(seconds: 1));
        expect(hook.current.status, MutationStatus.success);
        expect(hook.current.data, 'data');
      }));

      testWidgets(
          'SHOULD NOT pause retries on going offline'
          '', withCleanup((tester) async {
        // Start online
        connectivityController.add(true);

        var mutateFnCount = 0;
        final hook = await buildHook(
          () => useMutation<String, Object, void, void>(
            (_, __) async {
              mutateFnCount++;
              throw Exception();
            },
            networkMode: NetworkMode.always,
            retry: (retryCount, _) {
              if (retryCount < 3) {
                return const Duration(seconds: 1);
              }
              return null;
            },
            client: client,
          ),
        );

        hook.current.mutate(null);
        await tester.pump();
        expect(hook.current.isPaused, isFalse);
        expect(mutateFnCount, 1);

        // Go offline
        connectivityController.add(false);
        await tester.pump();
        await tester.pump();
        expect(hook.current.isPaused, isFalse);
        expect(mutateFnCount, 1);

        // Should continue retrying
        await tester.pump(const Duration(seconds: 1));
        expect(mutateFnCount, 2);
        await tester.pump(const Duration(seconds: 1));
        expect(mutateFnCount, 3);
        await tester.pump(const Duration(seconds: 1));
        expect(mutateFnCount, 4);
        expect(hook.current.status, MutationStatus.error);
      }));
    });

    group('== NetworkMode.offlineFirst', () {
      // Always runs first execution, pauses retries offline

      testWidgets(
          'SHOULD execute initial mutation normally online'
          '', withCleanup((tester) async {
        // Start online
        connectivityController.add(true);

        final hook = await buildHook(
          () => useMutation<String, Object, void, void>(
            (_, __) async {
              await Future.delayed(const Duration(seconds: 1));
              return 'data';
            },
            networkMode: NetworkMode.offlineFirst,
            client: client,
          ),
        );

        hook.current.mutate(null);
        await tester.pump();
        expect(hook.current.status, MutationStatus.pending);
        expect(hook.current.isPaused, isFalse);

        await tester.pump(const Duration(seconds: 1));
        expect(hook.current.status, MutationStatus.success);
        expect(hook.current.data, 'data');
      }));

      testWidgets(
          'SHOULD execute initial mutation normally offline'
          '', withCleanup((tester) async {
        // Start offline
        connectivityController.add(false);

        final hook = await buildHook(
          () => useMutation<String, Object, void, void>(
            (_, __) async {
              await Future.delayed(const Duration(seconds: 1));
              return 'data';
            },
            networkMode: NetworkMode.offlineFirst,
            client: client,
          ),
        );
        expect(hook.current.status, MutationStatus.idle);

        hook.current.mutate(null);
        await tester.pump();
        expect(hook.current.status, MutationStatus.pending);
        expect(hook.current.isPaused, isFalse);

        await tester.pump(const Duration(seconds: 1));
        expect(hook.current.status, MutationStatus.success);
        expect(hook.current.data, 'data');
      }));

      testWidgets(
          'SHOULD pause retries offline, then resume on going online'
          '', withCleanup((tester) async {
        // Start offline
        connectivityController.add(false);

        var mutateFnCount = 0;
        final hook = await buildHook(
          () => useMutation<String, Object, void, void>(
            (_, __) async {
              mutateFnCount++;
              throw Exception();
            },
            networkMode: NetworkMode.offlineFirst,
            retry: (retryCount, _) {
              if (retryCount < 3) {
                return const Duration(seconds: 1);
              }
              return null;
            },
            client: client,
          ),
        );

        hook.current.mutate(null);
        await tester.pump();
        expect(hook.current.isPaused, isTrue);
        expect(mutateFnCount, 1);

        // Should NOT retry when paused
        await tester.pump(const Duration(days: 365));
        expect(hook.current.isPaused, isTrue);
        expect(mutateFnCount, 1);

        // Go online
        connectivityController.add(true);
        await tester.pump();
        await tester.pump();
        expect(hook.current.isPaused, isFalse);
        expect(mutateFnCount, 2);

        // Should continue retrying
        await tester.pump(const Duration(seconds: 1));
        expect(mutateFnCount, 3);
        await tester.pump(const Duration(seconds: 1));
        expect(mutateFnCount, 4);
        expect(hook.current.status, MutationStatus.error);
      }));
    });
  });
}
