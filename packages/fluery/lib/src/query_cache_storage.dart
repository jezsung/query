import 'package:fluery/fluery.dart';
import 'package:fluery/src/base_query.dart';
import 'package:flutter/foundation.dart';

abstract class QueryCacheStorage with BaseQueryObserver {
  Map<String, dynamic>? get(QueryIdentifier id);

  void set(QueryIdentifier id, Object data);

  @nonVirtual
  @override
  void onNotified(BaseQuery query, BaseQueryEvent event) {
    if (event is QueryStateUpdated) {
      try {
        set(query.id, event.state);
      } catch (e) {
        // A non-serializable object will not be cached in a persistent storage.
      }
    }
  }
}
