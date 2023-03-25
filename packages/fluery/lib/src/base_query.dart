import 'package:equatable/equatable.dart';
import 'package:fluery/src/query_cache_storage.dart';
import 'package:flutter/foundation.dart';

typedef QueryIdentifier = String;

enum QueryStatus {
  idle,
  loading,
  success,
  failure,
}

abstract class BaseQueryState extends Equatable {
  const BaseQueryState({
    this.status = QueryStatus.idle,
    this.error,
  });

  final QueryStatus status;
  final Object? error;

  @mustCallSuper
  @override
  List<Object?> get props => [
        status,
        error,
      ];
}

abstract class BaseQuery<
    Query extends BaseQuery<Query, Controller, State>,
    Controller extends BaseQueryController<Query, Controller, State>,
    State extends BaseQueryState> {
  BaseQuery({
    required this.id,
    required this.cacheStorage,
  });

  final QueryIdentifier id;
  final QueryCacheStorage cacheStorage;

  final Set<Controller> controllers = {};

  late State state;

  Future<void> fetch();

  subscribe(Controller controller) {
    controllers.add(controller);
    controller.query = this as Query;
    notify(state);
  }

  unsubscribe(Controller controller) {
    controllers.remove(controller);
  }

  notify(State state) {
    for (final controller in controllers) {
      controller.onNotified(state);
    }
  }
}

abstract class BaseQueryController<
    Query extends BaseQuery<Query, Controller, State>,
    Controller extends BaseQueryController<Query, Controller, State>,
    State extends BaseQueryState> extends ValueNotifier<State> {
  BaseQueryController(super.value);

  late Query query;

  onNotified(State state) {
    value = state;
  }
}
