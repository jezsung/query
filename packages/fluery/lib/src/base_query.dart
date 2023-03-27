import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

typedef QueryIdentifier = String;

enum QueryStatus {
  idle,
  loading,
  success,
  failure,
}

abstract class BaseQueryState extends Equatable {
  const BaseQueryState(this.status);

  final QueryStatus status;

  @mustCallSuper
  @override
  List<Object?> get props => [status];
}

abstract class BaseQueryEvent extends Equatable {}

class QueryStateUpdated<State extends BaseQueryState> extends BaseQueryEvent {
  QueryStateUpdated(this.state);

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

    notify(QueryObserverRemoved<Observer>(observer));
    observers.remove(observer);
  }

  notify(BaseQueryEvent event) {
    for (final observer in observers) {
      observer.onNotified(this, event);
    }
  }
}
