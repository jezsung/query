import 'package:flutter/widgets.dart';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

export 'package:clock/clock.dart' show clock;
export 'package:fake_async/fake_async.dart' show FakeAsync;

/// A test helper that wraps a test body in [fakeAsync] for time manipulation.
///
/// This allows you to control time in tests using [FakeAsync.elapse] and
/// [FakeAsync.flushMicrotasks].
///
/// Usage:
/// ```dart
/// test('my test', withFakeAsync((async) {
///   // Start an async operation
///   myFuture.then((_) {}).catchError((e) => ...);
///
///   // Advance time
///   async.elapse(const Duration(seconds: 5));
///
///   // Assert
///   expect(...);
/// }));
/// ```
///
/// Note: The test body must be synchronous. Use `.then()` and `.catchError()`
/// to handle async results within the fakeAsync zone.
void Function() withFakeAsync(void Function(FakeAsync async) testBody) {
  return () => fakeAsync(testBody);
}

/// Creates a [WidgetTesterCallback] that wraps test body with automatic cleanup.
///
/// This ensures proper cleanup order:
/// 1. Test body completes
/// 2. Widget tree is unmounted
/// 3. Waits for all pending timers to finish
///
/// Usage:
/// ```dart
/// testWidgets('my test', withCleanup((tester) async {
///   // test body
/// }));
/// ```
WidgetTesterCallback withCleanup(
  Future<void> Function(WidgetTester tester) testBody,
) {
  return (WidgetTester tester) async {
    await testBody(tester);

    // Unmount widget tree first (disposes QueryObservers)
    await tester.pumpWidget(Container());

    // Wait until all pending timers finish
    await tester.binding.delayed(const Duration(days: 365));
  };
}

/// Extension on [WidgetTester] for time-based pumping.
extension WidgetTesterPumpUntil on WidgetTester {
  /// Pumps the widget tree until the specified [target] time.
  ///
  /// Calculates the duration from the current clock time to [target]
  /// and calls [pump] with that duration.
  ///
  /// Throws if [target] is in the past.
  Future<void> pumpUntil(DateTime target) async {
    final duration = target.difference(clock.now());

    if (duration.isNegative) {
      throw Exception('Cannot pump to a time in the past');
    }

    await pump(duration);
  }
}
