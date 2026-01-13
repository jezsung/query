import 'dart:async';

import 'package:meta/meta.dart';

import 'options/gc_duration.dart';

/// Mixin that provides garbage collection functionality for queries and mutations.
///
/// Classes that use this mixin must:
/// - Implement [gcDuration] to specify how long to wait before garbage collection
/// - Implement [tryRemove] to define removal logic (including checks for observers, fetching state, etc.)
mixin GarbageCollectable {
  Timer? _gcTimer;

  @visibleForOverriding
  GcDuration get gcDuration;

  @protected
  void scheduleGc([GcDuration? duration]) {
    cancelGc();
    switch (duration ?? gcDuration) {
      case final GcDurationDuration duration:
        _gcTimer = Timer(duration, tryRemove);
      case GcDurationInfinity():
        return;
    }
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
