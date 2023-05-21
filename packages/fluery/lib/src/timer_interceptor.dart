import 'dart:async';

class TimerInterceptor<T> {
  TimerInterceptor._(
    this.timers,
    this.value,
  );

  final List<Timer> timers;
  final Future<T> value;

  factory TimerInterceptor(Future<T> Function() callback) {
    final timers = <Timer>[];
    final value = Zone.current
        .fork(
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
        )
        .run(callback);
    return TimerInterceptor._(timers, value);
  }
}
