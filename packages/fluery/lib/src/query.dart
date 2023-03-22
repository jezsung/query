import 'package:equatable/equatable.dart';
import 'package:fluery/src/query_cache_storage.dart';
import 'package:flutter/foundation.dart';

typedef QueryKey = String;

typedef QueryFetcher<Data> = Future<Data> Function(QueryKey key);

enum QueryStatus {
  idle,
  loading,
  success,
  failure,
}

class QueryState<Data> extends Equatable {
  QueryState({
    required this.status,
    this.data,
    this.error,
  });

  final QueryStatus status;
  final Data? data;
  final Object? error;

  QueryState<Data> copyWith({
    QueryStatus? status,
    Data? data,
    Object? error,
  }) {
    return QueryState<Data>(
      status: status ?? this.status,
      data: data ?? this.data,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [
        status,
        data,
        error,
      ];
}

class Query<Data> extends ValueNotifier<QueryState<Data>> {
  Query({
    required this.key,
    required this.cacheStorage,
  }) : super(QueryState<Data>(status: QueryStatus.idle));

  final QueryKey key;
  final QueryCacheStorage cacheStorage;

  bool isFetchRunning = false;

  Future<void> fetch({
    required QueryFetcher<Data> fetcher,
    required Duration staleDuration,
  }) async {
    if (isFetchRunning) {
      return;
    } else {
      isFetchRunning = true;
    }

    Future<void> execute() async {
      final cacheState = cacheStorage.get(key);
      final shouldFetch = cacheState?.isStale(staleDuration) ?? true;
      if (!shouldFetch) {
        value = value.copyWith(
          status: QueryStatus.success,
          data: cacheState!.data,
        );
        return;
      }

      value = value.copyWith(status: QueryStatus.loading);
      try {
        final data = await fetcher(key);
        cacheStorage.set(key, data);
        value = value.copyWith(
          status: QueryStatus.success,
          data: data,
        );
      } catch (error) {
        value = value.copyWith(
          status: QueryStatus.failure,
          error: error,
        );
      }
    }

    try {
      await execute();
    } catch (error) {
      rethrow;
    } finally {
      isFetchRunning = false;
    }
  }
}
