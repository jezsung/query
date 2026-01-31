import 'query.dart';

/// Events emitted by [QueryCache] when its contents change.
///
/// Use pattern matching to handle specific event types:
/// ```dart
/// cache.subscribe((event) {
///   switch (event) {
///     case QueryAddedEvent(:final query):
///       print('Query added: ${query.key}');
///     case QueryUpdatedEvent(:final query):
///       print('Query updated: ${query.key}');
///     case QueryRemovedEvent(:final query):
///       print('Query removed: ${query.key}');
///   }
/// });
/// ```
sealed class QueryCacheEvent {
  const QueryCacheEvent();
}

/// Emitted when a query is added to the cache.
final class QueryAddedEvent extends QueryCacheEvent {
  const QueryAddedEvent(this.query);

  /// The query that was added.
  final Query query;
}

/// Emitted when a query is removed from the cache.
final class QueryRemovedEvent extends QueryCacheEvent {
  const QueryRemovedEvent(this.query);

  /// The query that was removed.
  final Query query;
}

/// Emitted when a query's state is updated.
final class QueryUpdatedEvent extends QueryCacheEvent {
  const QueryUpdatedEvent(this.query);

  /// The query whose state was updated.
  final Query query;
}
