import 'package:meta/meta.dart';

import 'query.dart';

@internal
sealed class QueryCacheEvent {
  const QueryCacheEvent();
}

@internal
final class QueryAddedEvent extends QueryCacheEvent {
  const QueryAddedEvent(this.query);

  final Query query;
}

@internal
final class QueryRemovedEvent extends QueryCacheEvent {
  const QueryRemovedEvent(this.query);

  final Query query;
}

@internal
final class QueryUpdatedEvent extends QueryCacheEvent {
  const QueryUpdatedEvent(this.query);

  final Query query;
}
