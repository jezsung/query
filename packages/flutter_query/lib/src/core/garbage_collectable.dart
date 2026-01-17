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

  @protected
  void scheduleGc(GcDuration duration) {
    cancelGc();
    switch (duration) {
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
