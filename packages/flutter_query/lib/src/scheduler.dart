import 'dart:async';

import 'package:clock/clock.dart';

typedef Callback = FutureOr Function();

class Scheduler {
  Scheduler._(
    Duration duration,
    this.callback,
  )   : _timer = Timer(duration, callback),
        _lastScheduledAt = clock.now();

  final Callback callback;

  Timer _timer;
  DateTime _lastScheduledAt;

  bool get isScheduled => _timer.isActive;

  bool get isCanceled => !_timer.isActive;

  void reschedule(Duration duration) {
    _timer.cancel();

    final now = clock.now();
    final rescheduleAt = _lastScheduledAt.add(duration);

    if (now.isAfter(rescheduleAt) || now.isAtSameMomentAs(rescheduleAt)) {
      callback();
    } else {
      _lastScheduledAt = now;
      _timer = Timer(rescheduleAt.difference(now), callback);
    }
  }

  void cancel() {
    _timer.cancel();
  }

  static Scheduler run(Duration duration, Callback callback) {
    return Scheduler._(duration, callback);
  }
}
