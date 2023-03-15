import 'package:equatable/equatable.dart';
import 'package:fluery/src/fluery_error.dart';
import 'package:fluery/src/query_cache_storage.dart';
import 'package:fluery/src/query_observer.dart';
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
    return QueryState(
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
  final List<QueryObserver<Data>> observers = [];
  final QueryCacheStorage cacheStorage;

  bool isFetchRunning = false;

  Future<void> fetch({
    QueryFetcher<Data>? fetcher,
    Duration? staleDuration,
  }) async {
    if (isFetchRunning) {
      return;
    } else {
      isFetchRunning = true;
    }

    final QueryFetcher<Data> effectiveFetcher;
    final Duration effectiveStaleDuration;

    try {
      effectiveFetcher = fetcher ?? observers.first.fetcher;
    } on StateError {
      isFetchRunning = false;
      throw FlueryError('fetcher is not found on $runtimeType');
    }

    if (staleDuration != null) {
      effectiveStaleDuration = staleDuration;
    } else if (observers.isNotEmpty) {
      effectiveStaleDuration = observers.fold(
        observers.first.staleDuration,
        (duration, observer) => observer.staleDuration < duration
            ? observer.staleDuration
            : duration,
      );
    } else {
      effectiveStaleDuration = Duration.zero;
    }

    final cacheState = cacheStorage.get(key);
    final shouldFetch = cacheState?.isStale(effectiveStaleDuration) ?? true;
    if (!shouldFetch) {
      value = value.copyWith(
        status: QueryStatus.success,
        data: cacheState!.data,
      );
      isFetchRunning = false;
      return;
    }

    value = value.copyWith(status: QueryStatus.loading);
    try {
      final data = await effectiveFetcher(key);
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

    isFetchRunning = false;
  }

  void addObserver(QueryObserver<Data> observer) {
    observers.add(observer);
  }

  void removeObserver(QueryObserver<Data> observer) {
    observers.remove(observer);
  }

  @mustCallSuper
  @override
  void dispose() {
    super.dispose();
  }
}
