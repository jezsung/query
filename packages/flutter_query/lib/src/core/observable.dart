import 'package:meta/meta.dart';

mixin Observer {
  void onNotified();
}

mixin Observable<TObserver extends Observer> {
  final List<TObserver> _observers = <TObserver>[];
  void Function(TObserver observer)? _onAdd;
  void Function(TObserver observer)? _onRemove;

  @protected
  List<TObserver> get observers => List.unmodifiable(_observers);

  @protected
  set onAdd(void Function(TObserver) callback) => _onAdd = callback;

  @protected
  set onRemove(void Function(TObserver) callback) => _onRemove = callback;

  bool get hasObservers => observers.isNotEmpty;

  void addObserver(TObserver observer) {
    if (!_observers.contains(observer)) {
      _observers.add(observer);
      _onAdd?.call(observer);
    }
  }

  void removeObserver(TObserver observer) {
    _observers.remove(observer);
    _onRemove?.call(observer);
  }

  void notifyObservers() {
    for (final observer in _observers) {
      observer.onNotified();
    }
  }
}
