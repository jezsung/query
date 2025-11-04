import 'dart:async';

import 'package:query_core/src/types.dart';


class QueryCacheConfig {
  final void Function(dynamic error)? onError;
  final void Function(dynamic data)? onSuccess;

  QueryCacheConfig({this.onError, this.onSuccess});
}

class QueryCache {
  final QueryCacheConfig config;

  QueryCache({required this.config});
}

class CacheQuery<T> {
  final dynamic result; // can be QueryResult/InfiniteQueryResult from flutter layer
  final DateTime timestamp;
  late TrackedFuture<T>? queryFnRunning;

  CacheQuery(this.result, this.timestamp, {this.queryFnRunning});
}

class QueryCacheListener {
  final String id;
  bool isInfinite;
  final Function() refetchCallBack;
  final Function(dynamic) listenUpdateCallBack;
  bool? refetchOnRestart;
  bool? refetchOnReconnect;

  QueryCacheListener(this.id, this.isInfinite, this.refetchCallBack, this.listenUpdateCallBack, this.refetchOnRestart,
      this.refetchOnReconnect);
}
