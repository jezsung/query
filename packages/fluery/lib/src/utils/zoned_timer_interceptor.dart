import 'dart:async';

class ZonedTimerInterceptor {
  final List<Timer> timers = [];

  late final Zone _zone;

  R run<R>(R Function() callback) {
    timers.clear();
    _zone = Zone.current.fork(
      specification: ZoneSpecification(
        createTimer: (self, parent, zone, duration, f) {
          final timer = parent.createTimer(zone, duration, f);
          timers.add(timer);
          return timer;
        },
        createPeriodicTimer: (self, parent, zone, period, f) {
          final timer = parent.createPeriodicTimer(zone, period, f);
          timers.add(timer);
          return timer;
        },
      ),
    );
    return _zone.run<R>(callback);
  }

  cancel() {
    for (final timer in timers) {
      timer.cancel();
    }
    timers.clear();
  }
}
