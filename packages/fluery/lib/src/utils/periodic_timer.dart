import 'dart:async';

import 'package:clock/clock.dart';

class PeriodicTimer {
  PeriodicTimer(
    callback,
    interval,
  )   : _callback = callback,
        _interval = interval;

  Function _callback;
  Duration _interval;

  Function get callback => _callback;

  Duration get interval => _interval;

  set callback(Function value) {
    if (value == _callback) return;

    _callback = value;
    _reset();
  }

  set interval(Duration value) {
    if (value == _interval) return;

    _interval = value;
    _reset();
  }

  DateTime? _lastTickedAt;
  Timer? _timer;

  bool get running =>
      _timer != null && _timer!.isActive && _lastTickedAt != null;

  void start() {
    if (running) {
      return;
    }

    _lastTickedAt = clock.now();
    _timer = Timer.periodic(
      _interval,
      (timer) {
        _lastTickedAt = clock.now();
        _callback();
      },
    );
  }

  void stop() {
    _timer?.cancel();
  }

  void _reset() {
    if (!running) return;

    final diff = _lastTickedAt!.add(_interval).difference(clock.now());

    if (diff.isNegative || diff == Duration.zero) {
      _lastTickedAt = clock.now();
      _callback();
      _timer?.cancel();
      _timer = Timer.periodic(
        _interval,
        (timer) {
          _lastTickedAt = clock.now();
          _callback();
        },
      );
    } else {
      Timer(diff, () {
        _lastTickedAt = clock.now();
        _callback();
        _timer?.cancel();
        _timer = Timer.periodic(
          _interval,
          (timer) {
            _lastTickedAt = clock.now();
            _callback();
          },
        );
      });
    }
  }
}
