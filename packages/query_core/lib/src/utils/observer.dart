mixin Observable<T extends Observer<E>, E> {
  final List<T> observers = <T>[];

  void addObserver(T observer) {
    observers.add(observer);
    observer.onAdded(this);
  }

  void removeObserver(T observer) {
    observers.remove(observer);
    observer.onRemoved(this);
  }

  void notify(E event) {
    for (final observer in observers) {
      observer.onNotified(event);
    }
  }
}

abstract class Observer<E> {
  void onNotified(E event);

  void onAdded(covariant Observable observable) {}

  void onRemoved(covariant Observable observable) {}
}
