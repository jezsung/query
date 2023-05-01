import 'dart:async';

import 'package:async/async.dart';
import 'package:clock/clock.dart';
import 'package:equatable/equatable.dart';
import 'package:fluery/src/timer_interceptor.dart';
import 'package:flutter/foundation.dart';
import 'package:retry/retry.dart';

import 'query_cache.dart';

typedef QueryIdentifier = String;

typedef QueryFetcher<Data> = Future<Data> Function(QueryIdentifier id);

typedef RetryCondition = FutureOr<bool> Function(Exception e);

enum QueryStatus {
  idle,
  fetching,
  retrying,
  canceled,
  success,
  failure,
}

extension QueryStatusExtension on QueryStatus {
  bool get isIdle => this == QueryStatus.idle;

  bool get isFetching => this == QueryStatus.fetching;

  bool get isRetrying => this == QueryStatus.retrying;

  bool get isLoading => isFetching || isRetrying;

  bool get isCanceled => this == QueryStatus.canceled;

  bool get isSuccess => this == QueryStatus.success;

  bool get isFailure => this == QueryStatus.failure;
}

class QueryState<T> extends Equatable {
  const QueryState({
    this.status = QueryStatus.idle,
    this.data,
    this.dataUpdatedAt,
    this.error,
    this.errorUpdatedAt,
  });

  final QueryStatus status;
  final T? data;
  final Exception? error;
  final DateTime? dataUpdatedAt;
  final DateTime? errorUpdatedAt;

  bool get hasData => data != null;

  bool get hasError => error != null;

  DateTime? get lastUpdatedAt {
    if (dataUpdatedAt != null && errorUpdatedAt != null) {
      return dataUpdatedAt!.isAfter(errorUpdatedAt!)
          ? dataUpdatedAt
          : errorUpdatedAt;
    } else if (dataUpdatedAt != null) {
      return dataUpdatedAt;
    } else if (errorUpdatedAt != null) {
      return errorUpdatedAt;
    } else {
      return null;
    }
  }

  QueryState<T> copyWith({
    QueryStatus? status,
    T? data,
    Exception? error,
    DateTime? dataUpdatedAt,
    DateTime? errorUpdatedAt,
  }) {
    return QueryState<T>(
      status: status ?? this.status,
      data: data ?? this.data,
      error: error ?? this.error,
      dataUpdatedAt: dataUpdatedAt ?? this.dataUpdatedAt,
      errorUpdatedAt: errorUpdatedAt ?? this.errorUpdatedAt,
    );
  }

  @override
  List<Object?> get props => [
        status,
        data,
        error,
        dataUpdatedAt,
        errorUpdatedAt,
      ];
}

class QueryOptions<T> {
  QueryOptions({
    required this.fetcher,
    required this.staleDuration,
    required this.cacheDuration,
    required this.retryWhen,
    required this.retryMaxAttempts,
    required this.retryMaxDelay,
    required this.retryDelayFactor,
    required this.retryRandomizationFactor,
    required this.refetchIntervalDuration,
  });

  final QueryFetcher<T> fetcher;
  final Duration staleDuration;
  final Duration cacheDuration;
  final RetryCondition? retryWhen;
  final int retryMaxAttempts;
  final Duration retryMaxDelay;
  final Duration retryDelayFactor;
  final double retryRandomizationFactor;
  final Duration? refetchIntervalDuration;
}

class Query<T> {
  Query({
    required this.id,
    required this.cache,
    QueryState<T>? initialState,
  }) : _state = initialState ?? QueryState<T>() {
    _scheduleGarbageCollection();

    _stateController.onListen = () {
      _cancelGarbageCollection();
    };
    _stateController.onCancel = () {
      if (!active) {
        _scheduleGarbageCollection();
      }
    };
  }

  final QueryIdentifier id;
  final QueryCache cache;
  final StreamController<QueryState<T>> _stateController =
      StreamController<QueryState<T>>.broadcast(sync: true);
  final List<QueryObserver<T>> _observers = <QueryObserver<T>>[];
  final TimerInterceptor _timerInterceptor = TimerInterceptor();

  QueryState<T> _state;
  CancelableOperation<T>? _cancelableOperation;
  Duration _cacheDuration = const Duration(minutes: 5);
  Timer? _garbageCollectionTimer;
  Timer? _refetchIntervalTimer;

  Stream<QueryState<T>> get stream => _stateController.stream;

  QueryState<T> get state => _state;

  bool get active => _stateController.hasListener;

  QueryFetcher<T>? get fetcher {
    if (_observers.isEmpty) return null;

    return _observers.first.fetcher;
  }

  Duration get staleDuration {
    if (_observers.isEmpty) return Duration.zero;

    return _observers.fold<Duration>(
      _observers.first.staleDuration,
      (staleDuration, controller) => controller.staleDuration < staleDuration
          ? controller.staleDuration
          : staleDuration,
    );
  }

  Duration get cacheDuration => _cacheDuration;

  RetryCondition? get retryWhen {
    if (_observers.isEmpty) return null;

    return _observers.first.retryWhen;
  }

  int get retryMaxAttempts {
    if (_observers.isEmpty) return 3;

    return _observers.fold<int>(
      _observers.first.retryMaxAttempts,
      (retryMaxAttempts, controller) =>
          controller.retryMaxAttempts > retryMaxAttempts
              ? controller.retryMaxAttempts
              : retryMaxAttempts,
    );
  }

  Duration get retryMaxDelay {
    if (_observers.isEmpty) return const Duration(seconds: 30);

    return _observers.fold<Duration>(
      _observers.first.retryMaxDelay,
      (retryMaxDelay, controller) => controller.retryMaxDelay > retryMaxDelay
          ? controller.retryMaxDelay
          : retryMaxDelay,
    );
  }

  Duration get retryDelayFactor {
    if (_observers.isEmpty) return const Duration(milliseconds: 200);

    return _observers.fold<Duration>(
      _observers.first.retryDelayFactor,
      (retryDelayFactor, controller) =>
          controller.retryDelayFactor > retryDelayFactor
              ? controller.retryDelayFactor
              : retryDelayFactor,
    );
  }

  double get retryRandomizationFactor {
    if (_observers.isEmpty) return 0.25;

    return _observers.fold<double>(
      _observers.first.retryRandomizationFactor,
      (retryRandomizationFactor, controller) =>
          controller.retryRandomizationFactor > retryRandomizationFactor
              ? controller.retryRandomizationFactor
              : retryRandomizationFactor,
    );
  }

  Duration? get refetchIntervalDuration {
    if (_observers.where((ob) => ob.enabled).isEmpty) return null;

    return _observers.fold<Duration?>(
      _observers.first.refetchIntervalDuration,
      (duration, controller) {
        if (controller.refetchIntervalDuration == null) {
          return duration;
        }
        if (duration == null) {
          return controller.refetchIntervalDuration;
        }

        return controller.refetchIntervalDuration! < duration
            ? controller.refetchIntervalDuration
            : duration;
      },
    );
  }

  Future<void> fetch({
    QueryFetcher<T>? fetcher,
    Duration? staleDuration,
    RetryCondition? retryWhen,
    int? retryMaxAttempts,
    Duration? retryMaxDelay,
    Duration? retryDelayFactor,
    double? retryRandomizationFactor,
  }) async {
    if (state.status.isLoading) return;

    assert(
      fetcher != null || this.fetcher != null,
      'fetcher must be provided',
    );

    final effectiveFetcher = fetcher ?? this.fetcher!;
    final effectiveStaleDuration = staleDuration ?? this.staleDuration;
    final effectiveRetryWhen = retryWhen ?? this.retryWhen ?? (e) => true;
    final effectiveRetryMaxAttempts = retryMaxAttempts ?? this.retryMaxAttempts;
    final effectiveRetryMaxDelay = retryMaxDelay ?? this.retryMaxDelay;
    final effectiveRetryDelayFactor = retryDelayFactor ?? this.retryDelayFactor;
    final effectiveRetryRandomizationFactor =
        retryRandomizationFactor ?? this.retryRandomizationFactor;

    if (!isStale(effectiveStaleDuration)) return;

    setState(state.copyWith(status: QueryStatus.fetching));

    try {
      _cancelableOperation = CancelableOperation<T>.fromFuture(
        _timerInterceptor.run(() => effectiveFetcher(id)),
      );

      final data = await _cancelableOperation!.valueOrCancellation();

      if (!_cancelableOperation!.isCanceled) {
        setState(state.copyWith(
          status: QueryStatus.success,
          data: data,
          dataUpdatedAt: clock.now(),
        ));
      }
    } on Exception catch (error) {
      final shouldRetry =
          effectiveRetryMaxAttempts >= 1 && await effectiveRetryWhen(error);

      if (shouldRetry) {
        setState(state.copyWith(
          status: QueryStatus.retrying,
          error: error,
          errorUpdatedAt: clock.now(),
        ));

        try {
          final data = await retry(
            () {
              _cancelableOperation = CancelableOperation<T>.fromFuture(
                _timerInterceptor.run(() => effectiveFetcher(id)),
              );
              return _cancelableOperation!.valueOrCancellation();
            },
            retryIf: effectiveRetryWhen,
            maxAttempts: effectiveRetryMaxAttempts,
            maxDelay: effectiveRetryMaxDelay,
            delayFactor: effectiveRetryDelayFactor,
            randomizationFactor: effectiveRetryRandomizationFactor,
            onRetry: (error) {
              setState(state.copyWith(
                error: error,
                errorUpdatedAt: clock.now(),
              ));
            },
          );

          if (!_cancelableOperation!.isCanceled) {
            setState(state.copyWith(
              status: QueryStatus.success,
              data: data,
              dataUpdatedAt: clock.now(),
            ));
          }
        } on Exception catch (error) {
          setState(state.copyWith(
            status: QueryStatus.failure,
            error: error,
            errorUpdatedAt: clock.now(),
          ));
        }
      } else {
        setState(state.copyWith(
          status: QueryStatus.failure,
          error: error,
          errorUpdatedAt: clock.now(),
        ));
      }
    } finally {
      setRefetchInterval();
    }
  }

  Future<void> cancel({
    T? data,
    Exception? error,
  }) async {
    if (!state.status.isLoading) return;

    await _cancelableOperation?.cancel();

    setState(state.copyWith(
      status: QueryStatus.canceled,
      data: data,
      dataUpdatedAt: data != null ? clock.now() : null,
      error: error,
      errorUpdatedAt: error != null ? clock.now() : null,
    ));
  }

  void setInitialData(
    T data, [
    DateTime? updatedAt,
  ]) {
    if ((!state.hasData && state.dataUpdatedAt == null) ||
        (updatedAt != null && updatedAt.isAfter(state.dataUpdatedAt!))) {
      setState(state.copyWith(
        status: QueryStatus.success,
        data: data,
        dataUpdatedAt: updatedAt ?? clock.now(),
      ));
    }
  }

  void setData(
    T data, [
    DateTime? updatedAt,
  ]) {
    final bool shouldUpdate;

    if (!state.hasData) {
      shouldUpdate = true;
    } else if (state.dataUpdatedAt == null) {
      shouldUpdate = true;
    } else if (updatedAt == null) {
      shouldUpdate = true;
    } else {
      shouldUpdate = updatedAt.isAfter(state.dataUpdatedAt!);
    }

    if (shouldUpdate) {
      setState(state.copyWith(
        status: QueryStatus.success,
        data: data,
        dataUpdatedAt: updatedAt ?? clock.now(),
      ));
    }
  }

  void setState(QueryState<T> state) {
    _state = state;
    _stateController.add(state);
  }

  void setRefetchInterval() {
    final duration = refetchIntervalDuration;
    final lastUpdatedAt = state.lastUpdatedAt;

    if (duration == null) {
      _refetchIntervalTimer?.cancel();
    } else if (state.status.isLoading) {
      return;
    } else if (lastUpdatedAt == null) {
      fetch();
    } else {
      _refetchIntervalTimer?.cancel();

      final diff = lastUpdatedAt.add(duration).difference(clock.now());

      if (diff.isNegative || diff == Duration.zero) {
        fetch();
      } else {
        _refetchIntervalTimer = Timer(diff, () => fetch());
      }
    }
  }

  void addObserver(QueryObserver<T> observer) {
    _observers.add(observer);

    setRefetchInterval();
  }

  void removeObserver(QueryObserver<T> observer) {
    _observers.remove(observer);

    if (_observers.isEmpty) {
      _cacheDuration = observer.cacheDuration;
    }

    setRefetchInterval();
  }

  bool isStale(Duration duration) {
    if (!state.hasData || state.dataUpdatedAt == null) return true;

    return clock.now().isAfter(state.dataUpdatedAt!.add(duration)) ||
        clock.now().isAtSameMomentAs(state.dataUpdatedAt!.add(duration));
  }

  void dispose() {
    _cancelableOperation?.cancel();
    _garbageCollectionTimer?.cancel();
    _refetchIntervalTimer?.cancel();
    _timerInterceptor.cancel();
    _stateController.close();
  }

  void _scheduleGarbageCollection() {
    if (active) return;

    _garbageCollectionTimer = Timer(
      _cacheDuration,
      () {
        dispose();
        cache.remove(id);
      },
    );
  }

  void _cancelGarbageCollection() {
    _garbageCollectionTimer?.cancel();
  }
}

class QueryObserver<T> extends ValueNotifier<QueryState<T>> {
  QueryObserver({
    required this.fetcher,
    this.enabled = true,
    this.placeholder,
    this.staleDuration = Duration.zero,
    this.cacheDuration = const Duration(minutes: 5),
    this.retryWhen,
    this.retryMaxAttempts = 3,
    this.retryMaxDelay = const Duration(seconds: 30),
    this.retryDelayFactor = const Duration(milliseconds: 200),
    this.retryRandomizationFactor = 0.25,
    this.refetchIntervalDuration,
  }) : super(QueryState<T>());

  QueryFetcher<T> fetcher;
  bool enabled;
  T? placeholder;
  Duration staleDuration;
  Duration cacheDuration;
  RetryCondition? retryWhen;
  int retryMaxAttempts;
  Duration retryMaxDelay;
  Duration retryDelayFactor;
  double retryRandomizationFactor;
  Duration? refetchIntervalDuration;

  Query<T>? _query;
  StreamSubscription<QueryState<T>>? _subscription;

  @override
  QueryState<T> get value {
    QueryState<T> state = super.value;

    if (state.status.isIdle && enabled) {
      state = state.copyWith(status: QueryStatus.fetching);
    }

    if (!state.hasData) {
      state = state.copyWith(data: placeholder);
    }

    return state;
  }

  Future<void> fetch({
    QueryFetcher<T>? fetcher,
    Duration? staleDuration,
    RetryCondition? retryWhen,
    int? retryMaxAttempts,
    Duration? retryMaxDelay,
    Duration? retryDelayFactor,
    double? retryRandomizationFactor,
  }) async {
    assert(
      _query != null,
      '''
      Tried to call QueryObserver<${T.runtimeType}>.fetch before it gets bound.

      Bind the QueryObserver<${T.runtimeType}>.
      ''',
    );

    if (!enabled) return;

    await _query!.fetch(
      fetcher: fetcher ?? this.fetcher,
      staleDuration: staleDuration ?? this.staleDuration,
      retryWhen: retryWhen ?? this.retryWhen,
      retryMaxAttempts: retryMaxAttempts ?? this.retryMaxAttempts,
      retryMaxDelay: retryMaxDelay ?? this.retryMaxDelay,
      retryDelayFactor: retryDelayFactor ?? this.retryDelayFactor,
      retryRandomizationFactor:
          retryRandomizationFactor ?? this.retryRandomizationFactor,
    );
  }

  Future<void> cancel({
    T? data,
    Exception? error,
  }) async {
    assert(
      _query != null,
      '''
      Tried to call QueryObserver<${T.runtimeType}>.cancel before it gets bound.

      Bind the QueryObserver<${T.runtimeType}>.
      ''',
    );

    await _query!.cancel(data: data, error: error);
  }

  void bind(Query<T> query) {
    _query = query;
    value = query.state;
    _subscription = query.stream.listen(_onStateChanged);
    _query!.addObserver(this);
  }

  void unbind() {
    if (_query == null) return;

    _subscription?.cancel();
    _query!.removeObserver(this);
    _query = null;
  }

  void _onStateChanged(QueryState<T> state) {
    value = state;
  }
}
