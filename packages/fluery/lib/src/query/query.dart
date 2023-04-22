import 'dart:async';

import 'package:async/async.dart';
import 'package:clock/clock.dart';
import 'package:equatable/equatable.dart';
import 'package:fluery/src/conditional_value_listenable_builder.dart';
import 'package:fluery/src/query_client/query_client.dart';
import 'package:fluery/src/timer_interceptor.dart';
import 'package:flutter/widgets.dart';
import 'package:retry/retry.dart';

part 'query_builder.dart';
part 'query_controller.dart';
part 'query_listener.dart';
part 'query_status.dart';

typedef QueryIdentifier = String;

typedef QueryFetcher<Data> = Future<Data> Function(QueryIdentifier id);

typedef RetryCondition = FutureOr<bool> Function(Exception e);

class QueryState<Data> extends Equatable {
  const QueryState({
    this.status = QueryStatus.idle,
    this.data,
    this.dataUpdatedAt,
    this.error,
    this.errorUpdatedAt,
  });

  final QueryStatus status;
  final Data? data;
  final Exception? error;
  final DateTime? dataUpdatedAt;
  final DateTime? errorUpdatedAt;

  bool get hasData => data != null;

  bool get hasError => error != null;

  QueryState<Data> copyWith({
    QueryStatus? status,
    Data? data,
    Exception? error,
    DateTime? dataUpdatedAt,
    DateTime? errorUpdatedAt,
  }) {
    return QueryState<Data>(
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

class Query<Data> {
  Query(
    this.id,
    this.cache,
  );

  final QueryIdentifier id;
  final QueryCache cache;
  final Set<QueryController<Data>> controllers = {};

  QueryState<Data> state = QueryState<Data>();

  final TimerInterceptor _timerInterceptor = TimerInterceptor();
  CancelableOperation<Data>? _cancelableOperation;
  Timer? _refetchTimer;
  DateTime? _refetchedAt;
  Timer? _garbageCollectionTimer;

  bool get active {
    return controllers.isNotEmpty;
  }

  QueryFetcher<Data>? get fetcher {
    if (!active) return null;

    return controllers.first.fetcher;
  }

  Duration? get staleDuration {
    if (!active) return null;

    return controllers.fold<Duration>(
      controllers.first.staleDuration,
      (staleDuration, controller) => controller.staleDuration < staleDuration
          ? controller.staleDuration
          : staleDuration,
    );
  }

  Duration? get cacheDuration {
    if (!active) return null;

    return controllers.fold<Duration>(
      controllers.first.cacheDuration,
      (cacheDuration, controller) => controller.cacheDuration > cacheDuration
          ? controller.cacheDuration
          : cacheDuration,
    );
  }

  RetryCondition? get retryWhen {
    if (!active) return null;

    return controllers.first.retryWhen;
  }

  int? get retryMaxAttempts {
    if (!active) return null;

    return controllers.fold<int>(
      controllers.first.retryMaxAttempts,
      (retryMaxAttempts, controller) =>
          controller.retryMaxAttempts > retryMaxAttempts
              ? controller.retryMaxAttempts
              : retryMaxAttempts,
    );
  }

  Duration? get retryMaxDelay {
    if (!active) return null;

    return controllers.fold<Duration>(
      controllers.first.retryMaxDelay,
      (retryMaxDelay, controller) => controller.retryMaxDelay > retryMaxDelay
          ? controller.retryMaxDelay
          : retryMaxDelay,
    );
  }

  Duration? get retryDelayFactor {
    if (!active) return null;

    return controllers.fold<Duration>(
      controllers.first.retryDelayFactor,
      (retryDelayFactor, controller) =>
          controller.retryDelayFactor > retryDelayFactor
              ? controller.retryDelayFactor
              : retryDelayFactor,
    );
  }

  double? get retryRandomizationFactor {
    if (!active) return null;

    return controllers.fold<double>(
      controllers.first.retryRandomizationFactor,
      (retryRandomizationFactor, controller) =>
          controller.retryRandomizationFactor > retryRandomizationFactor
              ? controller.retryRandomizationFactor
              : retryRandomizationFactor,
    );
  }

  Duration? get refetchIntervalDuration {
    if (!active) return null;

    return controllers.fold<Duration?>(
      controllers.first.refetchIntervalDuration,
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
    QueryFetcher<Data>? fetcher,
    Duration? staleDuration,
    RetryCondition? retryWhen,
    int? retryMaxAttempts,
    Duration? retryMaxDelay,
    Duration? retryDelayFactor,
    double? retryRandomizationFactor,
  }) async {
    if (!active) return;

    if (state.status.isLoading) return;

    final isDataFresh = () {
      final hadFetched = state.hasData && state.dataUpdatedAt != null;

      // If this query has never been fetched, the data should be considered stale.
      if (!hadFetched) return false;

      final effectiveStaleDuration = staleDuration ?? this.staleDuration!;

      final isFresh = clock.now().isBefore(
            state.dataUpdatedAt!.add(effectiveStaleDuration),
          );

      return isFresh;
    }();

    if (isDataFresh) return;

    final effectiveFetcher = fetcher ?? this.fetcher!;
    final effectiveRetryWhen =
        retryWhen ?? this.retryWhen ?? (Exception e) => true;
    final effectiveRetryMaxAttempts =
        retryMaxAttempts ?? this.retryMaxAttempts!;
    final effectiveRetryMaxDelay = retryMaxDelay ?? this.retryMaxDelay!;
    final effectiveRetryDelayFactor =
        retryDelayFactor ?? this.retryDelayFactor!;
    final effectiveRetryRandomizationFactor =
        retryRandomizationFactor ?? this.retryRandomizationFactor!;

    update(state.copyWith(status: QueryStatus.fetching));

    try {
      _cancelableOperation = CancelableOperation<Data>.fromFuture(
        _timerInterceptor.run(() => effectiveFetcher(id)),
      );

      final data = await _cancelableOperation!.valueOrCancellation();

      if (!_cancelableOperation!.isCanceled) {
        update(state.copyWith(
          status: QueryStatus.success,
          data: data,
          dataUpdatedAt: clock.now(),
        ));
      }
    } on Exception catch (error) {
      final shouldRetry =
          effectiveRetryMaxAttempts >= 1 && await effectiveRetryWhen(error);

      if (shouldRetry) {
        update(state.copyWith(
          status: QueryStatus.retrying,
          error: error,
          errorUpdatedAt: clock.now(),
        ));

        try {
          final data = await _timerInterceptor.run(
            () => retry(
              () {
                _cancelableOperation =
                    CancelableOperation<Data>.fromFuture(effectiveFetcher(id));
                return _cancelableOperation!.valueOrCancellation();
              },
              retryIf: effectiveRetryWhen,
              maxAttempts: effectiveRetryMaxAttempts,
              maxDelay: effectiveRetryMaxDelay,
              delayFactor: effectiveRetryDelayFactor,
              randomizationFactor: effectiveRetryRandomizationFactor,
              onRetry: (error) {
                update(state.copyWith(
                  error: error,
                  errorUpdatedAt: clock.now(),
                ));
              },
            ),
          );

          if (!_cancelableOperation!.isCanceled) {
            update(state.copyWith(
              status: QueryStatus.success,
              data: data,
              dataUpdatedAt: clock.now(),
            ));
          }
        } on Exception catch (e) {
          update(state.copyWith(
            status: QueryStatus.failure,
            error: e,
            errorUpdatedAt: clock.now(),
          ));
        }
      } else {
        update(state.copyWith(
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
    Data? data,
    Exception? error,
  }) async {
    if (!state.status.isLoading) return;

    await _cancelableOperation?.cancel();

    update(state.copyWith(
      status: QueryStatus.canceled,
      data: data,
      dataUpdatedAt: data != null ? clock.now() : null,
      error: error,
      errorUpdatedAt: error != null ? clock.now() : null,
    ));
  }

  void setData(
    Data data, [
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
      update(state.copyWith(
        status: QueryStatus.success,
        data: data,
        dataUpdatedAt: updatedAt ?? clock.now(),
      ));
    }
  }

  void setRefetchInterval() {
    final shouldCancel = refetchIntervalDuration == null;
    final shouldSchedule = refetchIntervalDuration != null &&
        (_refetchTimer == null || _refetchTimer?.isActive == false);
    final shouldReschedule =
        refetchIntervalDuration != null && _refetchTimer?.isActive == true;

    if (shouldCancel) {
      _refetchTimer?.cancel();
      return;
    }

    if (shouldSchedule) {
      _refetchedAt ??= clock.now();
      _refetchTimer = Timer(
        refetchIntervalDuration!,
        () {
          fetch().then((_) => _refetchedAt = clock.now());
        },
      );
      return;
    }

    if (shouldReschedule) {
      _refetchTimer?.cancel();

      final diff =
          _refetchedAt!.add(refetchIntervalDuration!).difference(clock.now());

      if (diff.isNegative || diff == Duration.zero) {
        fetch().then((_) => _refetchedAt = clock.now());
      } else {
        _refetchTimer = Timer(diff, () {
          fetch().then((_) => _refetchedAt = clock.now());
        });
      }

      return;
    }
  }

  void scheduleGarbageCollection(Duration cacheDuration) {
    if (active) return;

    _garbageCollectionTimer = Timer(
      cacheDuration,
      () {
        dispose();
        cache.remove(id);
      },
    );
  }

  void cancelGarbageCollection() {
    _garbageCollectionTimer?.cancel();
  }

  void update(QueryState<Data> state) {
    this.state = state;
    for (final controller in controllers) {
      controller.onStateUpdated(state);
    }
  }

  void addController(QueryController<Data> controller) {
    controllers.add(controller);
    controller.onAddedToQuery(this);

    if (controllers.length == 1) {
      cancelGarbageCollection();
    }
  }

  void removeController(QueryController<Data> controller) {
    controllers.remove(controller);
    controller.onRemovedFromQuery(this);

    if (!active) {
      scheduleGarbageCollection(controller.cacheDuration);
    }
  }

  void dispose() {
    _timerInterceptor.cancel();
    _refetchTimer?.cancel();
    _garbageCollectionTimer?.cancel();
  }
}
