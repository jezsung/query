import 'package:equatable/equatable.dart';

typedef QueryIdentifier = String;

abstract class BaseQueryState extends Equatable {
  const BaseQueryState();
}

abstract class BaseQueryEvent extends Equatable {
  const BaseQueryEvent();
}

class QueryStateUpdated<State extends BaseQueryState> extends BaseQueryEvent {
  const QueryStateUpdated(this.state);

  final State state;

  @override
  List<Object?> get props => [state];
}

class QueryObserverAdded<Observer extends BaseQueryObserver>
    extends BaseQueryEvent {
  QueryObserverAdded(this.observer);

  final Observer observer;

  @override
  List<Object?> get props => [observer];
}

class QueryObserverRemoved<Observer extends BaseQueryObserver>
    extends BaseQueryEvent {
  QueryObserverRemoved(this.observer);

  final Observer observer;

  @override
  List<Object?> get props => [observer];
}

abstract class BaseQueryObserver<Query extends BaseQuery> {
  void onNotified(Query query, BaseQueryEvent event);
}

abstract class BaseQuery {
  BaseQuery(this.id);

  final QueryIdentifier id;

  final Set<BaseQueryObserver> observers = {};

  void addObserver<Observer extends BaseQueryObserver>(Observer observer) {
    if (observers.contains(observer)) return;

    observers.add(observer);
    notify(QueryObserverAdded<Observer>(observer));
  }

  void removeObserver<Observer extends BaseQueryObserver>(Observer observer) {
    if (!observers.contains(observer)) return;

    observers.remove(observer);
    final event = QueryObserverRemoved<Observer>(observer);
    observer.onNotified(this, event);
    notify(event);
  }

  notify(BaseQueryEvent event) {
    for (final observer in observers) {
      observer.onNotified(this, event);
    }
  }
}
