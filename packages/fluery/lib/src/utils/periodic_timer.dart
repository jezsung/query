import 'dart:async';

class PeriodicTimer {
  PeriodicTimer(
    Function callback,
    Duration interval,
  )   : _callback = callback,
        _interval = interval;

  Function _callback;
  Duration _interval;

  DateTime? _lastTickedAt;
  Timer? _timer;

  bool get running =>
      _timer != null && _timer!.isActive && _lastTickedAt != null;

  void start() {
    if (running) {
      return;
    }

    _lastTickedAt = DateTime.now();
    _timer = Timer.periodic(
      _interval,
      (timer) {
        _lastTickedAt = DateTime.now();
        _callback();
      },
    );
  }

  void stop() {
    _timer?.cancel();
  }

  void setCallback(Function callback) {
    if (callback == _callback) return;

    _callback = callback;
    _reset();
  }

  void setInterval(Duration duration) {
    if (duration == _interval) return;

    _interval = duration;
    _reset();
  }

  void _reset() {
    if (!running) return;

    final diff = _lastTickedAt!.add(_interval).difference(DateTime.now());

    if (diff.isNegative || diff == Duration.zero) {
      _lastTickedAt = DateTime.now();
      _callback();
      _timer?.cancel();
      _timer = Timer.periodic(
        _interval,
        (timer) {
          _lastTickedAt = DateTime.now();
          _callback();
        },
      );
    } else {
      Timer(diff, () {
        _lastTickedAt = DateTime.now();
        _callback();
        _timer?.cancel();
        _timer = Timer.periodic(
          _interval,
          (timer) {
            _lastTickedAt = DateTime.now();
            _callback();
          },
        );
      });
    }
  }
}
