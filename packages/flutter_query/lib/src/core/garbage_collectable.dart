import 'dart:async';

import 'package:meta/meta.dart';

import 'query_options.dart';

/// Mixin that provides garbage collection functionality for queries and mutations.
///
/// Classes that use this mixin must:
/// - Implement [tryRemove] to define removal logic
@internal
mixin GarbageCollectable {
  Timer? _gcTimer;
  GcDuration? _lastGcDuration;

  @protected
  void scheduleGc([GcDuration? duration]) {
    cancelGc();
    _lastGcDuration = duration;
    switch (duration ?? const GcDuration(minutes: 5)) {
      case final GcDurationDuration duration:
        _gcTimer = Timer(duration, tryRemove);
      case GcDurationInfinity():
        return;
    }
  }

  @protected
  void rescheduleGc() {
    scheduleGc(_lastGcDuration);
  }

  @protected
  void cancelGc() {
    _gcTimer?.cancel();
    _gcTimer = null;
  }

  @mustCallSuper
  void dispose() {
    _gcTimer?.cancel();
    _gcTimer = null;
  }

  @visibleForOverriding
  void tryRemove();
}
