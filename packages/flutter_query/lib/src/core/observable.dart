import 'package:meta/meta.dart';

mixin Observer<TValue> {
  void onNotified(TValue value);
}

mixin Observable<TValue, TObserver extends Observer<TValue>> {
  final List<TObserver> _observers = <TObserver>[];
  void Function(TObserver observer)? _onAdd;
  void Function(TObserver observer)? _onRemove;

  @internal
  List<TObserver> get observers => List.unmodifiable(_observers);

  @protected
  set onAddObserver(void Function(TObserver) callback) => _onAdd = callback;

  @protected
  set onRemoveObserver(void Function(TObserver) callback) =>
      _onRemove = callback;

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

  void notifyObservers(TValue value) {
    for (final observer in _observers) {
      observer.onNotified(value);
    }
  }
}
