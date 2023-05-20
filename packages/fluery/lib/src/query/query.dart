import 'dart:async';

import 'package:async/async.dart';
import 'package:clock/clock.dart';
import 'package:equatable/equatable.dart';
import 'package:fluery/src/conditional_value_listenable_builder.dart';
import 'package:fluery/src/streamable.dart';
import 'package:fluery/src/timer_interceptor.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:retry/retry.dart';

part 'query_builder.dart';
part 'query_cache.dart';
part 'query_client_provider.dart';
part 'query_client.dart';
part 'query_observer.dart';
part 'query_state.dart';

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

  bool get isCanceled => this == QueryStatus.canceled;

  bool get isSuccess => this == QueryStatus.success;

  bool get isFailure => this == QueryStatus.failure;
}

typedef QueryWidgetBuilder<T> = Widget Function(
  BuildContext context,
  QueryState<T> state,
  Widget? child,
);

typedef QueryBuilderCondition<T> = bool Function(
  QueryState<T> previousState,
  QueryState<T> currentState,
);

enum RefetchMode {
  never,
  stale,
  always,
}

class Query<T> extends StateStreamable<QueryState<T>> {
  Query({
    required this.id,
    required this.cache,
    QueryState<T>? initialState,
  }) : super.broadcast(
          initialState: initialState ?? QueryState<T>(),
          sync: true,
        ) {
    _scheduleGarbageCollection();

    streamController.onListen = () {
      _cancelGarbageCollection();
    };
    streamController.onCancel = () {
      if (!active) {
        _scheduleGarbageCollection();
      }
    };
  }

  final QueryIdentifier id;
  final QueryCache cache;
  final List<QueryObserver<T>> _observers = <QueryObserver<T>>[];
  final TimerInterceptor _timerInterceptor = TimerInterceptor();

  CancelableOperation<T>? _cancelableOperation;
  Duration _cacheDuration = const Duration(minutes: 5);
  Timer? _garbageCollectionTimer;
  Timer? _refetchIntervalTimer;

  bool get active => streamController.hasListener;

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
    if (state.inProgress) return;

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

    state = state.copyWith(status: QueryStatus.fetching);

    try {
      _cancelableOperation = CancelableOperation<T>.fromFuture(
        _timerInterceptor.run(() => effectiveFetcher(id)),
      );

      final data = await _cancelableOperation!.valueOrCancellation();

      if (!_cancelableOperation!.isCanceled) {
        state = state.copyWith(
          status: QueryStatus.success,
          data: data,
          dataUpdatedAt: clock.now(),
        );
      }
    } on Exception catch (error) {
      final shouldRetry =
          effectiveRetryMaxAttempts >= 1 && await effectiveRetryWhen(error);

      if (shouldRetry) {
        state = state.copyWith(
          status: QueryStatus.retrying,
          error: error,
          errorUpdatedAt: clock.now(),
        );

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
              state = state.copyWith(
                error: error,
                errorUpdatedAt: clock.now(),
              );
            },
          );

          if (!_cancelableOperation!.isCanceled) {
            state = state.copyWith(
              status: QueryStatus.success,
              data: data,
              dataUpdatedAt: clock.now(),
            );
          }
        } on Exception catch (error) {
          state = state.copyWith(
            status: QueryStatus.failure,
            error: error,
            errorUpdatedAt: clock.now(),
          );
        }
      } else {
        state = state.copyWith(
          status: QueryStatus.failure,
          error: error,
          errorUpdatedAt: clock.now(),
        );
      }
    } finally {
      setRefetchInterval();
    }
  }

  Future<void> cancel({
    T? data,
    Exception? error,
  }) async {
    if (!state.inProgress) return;

    await _cancelableOperation?.cancel();

    state = state.copyWith(
      status: QueryStatus.canceled,
      data: data,
      dataUpdatedAt: data != null ? clock.now() : null,
      error: error,
      errorUpdatedAt: error != null ? clock.now() : null,
    );
  }

  void setInitialData(
    T data, [
    DateTime? updatedAt,
  ]) {
    if ((!state.hasData && state.dataUpdatedAt == null) ||
        (updatedAt != null && updatedAt.isAfter(state.dataUpdatedAt!))) {
      state = state.copyWith(
        status: QueryStatus.success,
        data: data,
        dataUpdatedAt: updatedAt ?? clock.now(),
      );
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
      state = state.copyWith(
        status: QueryStatus.success,
        data: data,
        dataUpdatedAt: updatedAt ?? clock.now(),
      );
    }
  }

  void setRefetchInterval() {
    final duration = refetchIntervalDuration;
    final lastUpdatedAt = state.lastUpdatedAt;

    if (duration == null) {
      _refetchIntervalTimer?.cancel();
    } else if (state.inProgress) {
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

  @override
  Future<void> close() async {
    await _cancelableOperation?.cancel();
    await super.close();
    _garbageCollectionTimer?.cancel();
    _refetchIntervalTimer?.cancel();
    _timerInterceptor.cancel();
  }

  void _scheduleGarbageCollection() {
    if (active) return;

    _garbageCollectionTimer = Timer(
      _cacheDuration,
      () async {
        await close();
        cache.remove(id);
      },
    );
  }

  void _cancelGarbageCollection() {
    _garbageCollectionTimer?.cancel();
  }
}
