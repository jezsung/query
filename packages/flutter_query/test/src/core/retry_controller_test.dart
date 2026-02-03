import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_query/src/core/network_mode.dart';
import 'package:flutter_query/src/core/retry_controller.dart';
import '../../utils.dart';

void main() {
  group('Function: canFetch', () {
    test('SHOULD return correct value based on passed arguments', () {
      expect(canFetch(NetworkMode.online, true), isTrue);
      expect(canFetch(NetworkMode.online, false), isFalse);
      expect(canFetch(NetworkMode.always, true), isTrue);
      expect(canFetch(NetworkMode.always, false), isTrue);
      expect(canFetch(NetworkMode.offlineFirst, true), isTrue);
      expect(canFetch(NetworkMode.offlineFirst, false), isTrue);
    });
  });

  group('Function: canContinue', () {
    test('SHOULD return correct value based on passed arguments', () {
      expect(canContinue(NetworkMode.online, true), isTrue);
      expect(canContinue(NetworkMode.online, false), isFalse);
      expect(canContinue(NetworkMode.always, true), isTrue);
      expect(canContinue(NetworkMode.always, false), isTrue);
      expect(canContinue(NetworkMode.offlineFirst, true), isTrue);
      expect(canContinue(NetworkMode.offlineFirst, false), isFalse);
    });
  });

  group('Constructor: new', () {
    group('Parameter: onError', () {
      test(
          'SHOULD receive correct arguments'
          '', withFakeAsync((async) {
        final error = Exception();
        final capturedArguments = <(int, Exception)>[];

        final retryController = RetryController<String, Exception>(
          () async => throw error,
          retry: (count, _) => count < 3 ? const Duration(seconds: 1) : null,
          onError: (failureCount, error) {
            capturedArguments.add((failureCount, error));
          },
        );

        retryController.start();
        async.flushMicrotasks();
        expect(capturedArguments.length, 1);
        expect(capturedArguments[0], (1, error));

        async.elapse(const Duration(seconds: 1));
        expect(capturedArguments.length, 2);
        expect(capturedArguments[1], (2, error));

        async.elapse(const Duration(seconds: 1));
        expect(capturedArguments.length, 3);
        expect(capturedArguments[2], (3, error));
      }));

      test(
          'SHOULD NOT be called on success'
          '', withFakeAsync((async) {
        var didFail = false;

        final retryController = RetryController<String, Exception>(
          () async => 'data',
          onError: (_, __) => didFail = true,
        );

        retryController.start();
        async.flushMicrotasks();

        expect(didFail, isFalse);
      }));
    });

    group('Parameter: onPause', () {
      test(
          'SHOULD be called '
          'WHEN paused', withFakeAsync((async) {
        var onPauseCount = 0;

        var retryController = RetryController<String, Exception>(
          () async => 'data',
          onPause: () => onPauseCount++,
        );
        retryController.start(paused: true);
        expect(onPauseCount, 1);

        onPauseCount = 0;
        retryController = RetryController<String, Exception>(
          () async => 'data',
          onPause: () => onPauseCount++,
        );
        retryController.pause();
        expect(onPauseCount, 1);
      }));

      test(
          'SHOULD NOT be called '
          'WHEN already paused', withFakeAsync((async) {
        var onPauseCount = 0;

        final retryController = RetryController<String, Exception>(
          () async => 'data',
          onPause: () => onPauseCount++,
        );

        retryController.start(paused: true);
        expect(onPauseCount, 1);

        retryController.pause();
        expect(onPauseCount, 1);
        retryController.pause();
        expect(onPauseCount, 1);
      }));

      test(
          'SHOULD NOT be called '
          'WHEN already resolved', withFakeAsync((async) {
        var onPauseCount = 0;

        final retryController = RetryController<String, Exception>(
          () async {
            await Future.delayed(const Duration(seconds: 1));
            return 'data';
          },
          onResume: () => onPauseCount++,
        );

        retryController.start();
        async.elapse(const Duration(seconds: 1));
        retryController.pause();

        expect(onPauseCount, 0);
      }));
    });

    group('Parameter: onResume', () {
      test(
          'SHOULD be called '
          'WHEN resumed after pause', withFakeAsync((async) {
        var onResumeCount = 0;

        final retryController = RetryController<String, Exception>(
          () async => 'data',
          onResume: () => onResumeCount++,
        );

        retryController.start(paused: true);

        expect(onResumeCount, 0);

        retryController.resume();

        expect(onResumeCount, 1);
      }));

      test(
          'SHOULD NOT be called '
          'WHEN not paused', withFakeAsync((async) {
        var onResumeCount = 0;

        final retryController = RetryController<String, Exception>(
          () async => 'data',
          onResume: () => onResumeCount++,
        );

        retryController.resume();
        expect(onResumeCount, 0);

        retryController.start();
        retryController.resume();
        expect(onResumeCount, 0);
      }));

      test(
          'SHOULD NOT be called '
          'WHEN already resolved', withFakeAsync((async) {
        var onResumeCount = 0;

        final retryController = RetryController<String, Exception>(
          () async {
            await Future.delayed(const Duration(seconds: 1));
            return 'data';
          },
          onResume: () => onResumeCount++,
        );

        retryController.start();
        async.elapse(const Duration(seconds: 1));
        retryController.resume();

        expect(onResumeCount, 0);
      }));
    });
  });

  group('Property: isPaused', () {
    test(
        'SHOULD return false initially'
        '', () {
      final retryController =
          RetryController<String, Exception>(() async => 'data');

      expect(retryController.isPaused, isFalse);
    });

    test(
        'SHOULD return true '
        'WHEN started with paused', withFakeAsync((async) {
      final retryController =
          RetryController<String, Exception>(() async => 'data');

      retryController.start(paused: true);

      expect(retryController.isPaused, isTrue);
    }));

    test(
        'SHOULD return false '
        'WHEN resumed', withFakeAsync((async) {
      final retryController =
          RetryController<String, Exception>(() async => 'data');

      retryController.start(paused: true);

      expect(retryController.isPaused, isTrue);

      retryController.resume();

      expect(retryController.isPaused, isFalse);
    }));

    test(
        'SHOULD return true in onPause callback'
        '', withFakeAsync((async) {
      late RetryController<String, Exception> retryController;
      bool? isPaused;

      retryController = RetryController<String, Exception>(
        () async => 'data',
        onPause: () {
          isPaused = retryController.isPaused;
        },
      );
      retryController.start(paused: true);
      expect(isPaused, isTrue);

      isPaused = null;
      retryController = RetryController<String, Exception>(
        () async => 'data',
        onPause: () {
          isPaused = retryController.isPaused;
        },
      );
      retryController.pause();
      expect(isPaused, isTrue);
    }));

    test(
        'SHOULD return false in onResume callback'
        '', withFakeAsync((async) {
      late RetryController<String, Exception> retryController;
      bool? isPaused;

      retryController = RetryController<String, Exception>(
        () async => 'data',
        onResume: () {
          isPaused = retryController.isPaused;
        },
      );
      retryController.start(paused: true);
      retryController.resume();
      expect(isPaused, isFalse);

      isPaused = null;
      retryController = RetryController<String, Exception>(
        () async => 'data',
        onResume: () {
          isPaused = retryController.isPaused;
        },
      );
      retryController.pause();
      retryController.resume();
      expect(isPaused, isFalse);
    }));

    test(
        'SHOULD return false '
        'WHEN pause() is called after resolved', withFakeAsync((async) {
      final retryController = RetryController<String, Exception>(
        () async => 'data',
      );

      retryController.start();
      async.flushMicrotasks();

      retryController.pause();
      expect(retryController.isPaused, isFalse);
    }));
  });

  group('Method: start', () {
    test(
        'SHOULD execute immediately '
        'WHEN paused == false', withFakeAsync((async) {
      var fnCount = 0;

      final retryController = RetryController<String, Exception>(() async {
        fnCount++;
        return 'data';
      });

      retryController.start();

      expect(fnCount, 1);
    }));

    test(
        'SHOULD pause immediately '
        'WHEN paused == true', withFakeAsync((async) {
      var fnCount = 0;
      var onPauseCount = 0;

      final retryController = RetryController<String, Exception>(
        () async {
          fnCount++;
          return 'data';
        },
        onPause: () => onPauseCount++,
      );

      retryController.start(paused: true);

      expect(fnCount, 0);
      expect(onPauseCount, 1);
    }));

    test(
        'SHOULD throw '
        'WHEN completes with error', withFakeAsync((async) {
      final expectedError = Exception('test error');
      Object? capturedError;

      final retryController = RetryController<String, Exception>(
        () async => throw expectedError,
        retry: (_, __) => null, // No retries
      );

      retryController.start().catchError((e) {
        capturedError = e;
        return 'error';
      });
      async.flushMicrotasks();

      expect(capturedError, same(expectedError));
    }));

    test(
        'SHOULD return same future on subsequent calls'
        '', withFakeAsync((async) {
      final retryController = RetryController<String, Exception>(
        () async => 'data',
      );

      final future1 = retryController.start();
      final future2 = retryController.start();

      expect(future1, same(future2));
    }));
  });

  group('Method: pause', () {
    test(
        'SHOULD pause execution '
        'WHEN called during retry delay', withFakeAsync((async) {
      var fnCount = 0;

      final retryController = RetryController<String, Exception>(
        () async {
          fnCount++;
          throw Exception();
        },
        retry: (count, _) => count < 3 ? const Duration(seconds: 1) : null,
      );

      retryController.start().ignore();
      expect(fnCount, 1);

      // First retry
      async.elapse(const Duration(seconds: 1));
      expect(fnCount, 2);

      // Pause during retry delay
      retryController.pause();
      expect(retryController.isPaused, isTrue);

      // Time passes but no retry happens
      async.elapse(const Duration(days: 365));
      expect(fnCount, 2);
    }));
  });

  group('Method: resume', () {
    test(
        'SHOULD resume execution '
        'WHEN paused', withFakeAsync((async) {
      var fnCount = 0;

      final retryController = RetryController<String, Exception>(
        () async {
          fnCount++;
          return 'data';
        },
      );

      retryController.start(paused: true);
      expect(fnCount, 0);

      retryController.resume();
      expect(fnCount, 1);
    }));

    test(
        'SHOULD do nothing '
        'WHEN not paused', withFakeAsync((async) {
      var fnCount = 0;

      final retryController = RetryController<String, Exception>(
        () async {
          fnCount++;
          return 'data';
        },
      );

      retryController.start();
      expect(fnCount, 1);

      retryController.resume();
      expect(fnCount, 1);
    }));

    test(
        'SHOULD continue retrying after resume'
        '', withFakeAsync((async) {
      var fnCount = 0;

      late RetryController<String, Exception> retryController;
      retryController = RetryController<String, Exception>(
        () async {
          fnCount++;
          throw Exception();
        },
        retry: (count, _) => count < 2 ? const Duration(seconds: 1) : null,
        onError: (failureCount, error) {
          // Pause after first failure
          if (failureCount == 1) {
            retryController.pause();
          }
        },
      );

      retryController.start().ignore();
      expect(fnCount, 1);

      // Advance past retry delay - should pause
      async.elapse(const Duration(seconds: 1));
      expect(retryController.isPaused, isTrue);
      expect(fnCount, 1);
      async.elapse(const Duration(days: 365));
      expect(fnCount, 1);

      // Resume
      retryController.resume();
      expect(fnCount, 2);

      // Continue retrying
      async.elapse(const Duration(seconds: 1));
      expect(fnCount, 3);
    }));
  });

  group('Method: cancel', () {
    test(
        'SHOULD resolve pause '
        'WHEN cancelled while paused', withFakeAsync((async) {
      late RetryController<String, Exception> retryController;
      retryController = RetryController<String, Exception>(
        () async => 'data',
      );

      retryController.start(paused: true).ignore();
      expect(retryController.isPaused, isTrue);

      retryController.cancel();
      expect(retryController.isPaused, isFalse);

      retryController = RetryController<String, Exception>(
        () async => 'data',
      );

      retryController.pause();
      expect(retryController.isPaused, isTrue);

      retryController.cancel();
      expect(retryController.isPaused, isFalse);
    }));

    test(
        'SHOULD make start throw with passed error'
        '', withFakeAsync((async) {
      final expectedError = Exception();
      Object? capturedError;

      final retryController = RetryController<String, Exception>(
        () async {
          await Future.delayed(const Duration(seconds: 1));
          return 'data';
        },
      );

      retryController.start().catchError((e) {
        capturedError = e;
        return 'error';
      });
      retryController.cancel(error: expectedError);
      async.flushMicrotasks();

      expect(capturedError, same(expectedError));
    }));
  });
}
