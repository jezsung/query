part of 'index.dart';

class Query<T> extends QueryBase<QueryObserver<T>, QueryState<T>> {
  Query({
    required super.id,
    required super.cache,
    QueryState<T>? initialState,
  }) : super(initialState: initialState ?? QueryState<T>());

  TimerInterceptor<T>? _timerInterceptor;
  CancelableOperation<T>? _cancelableOperation;
  Scheduler? _refetchScheduler;

  QueryFetcher<T>? get fetcher {
    if (observers.isEmpty) return null;

    return observers.first.fetcher;
  }

  Duration get staleDuration {
    if (observers.isEmpty) return Duration.zero;

    return observers.fold<Duration>(
      observers.first.staleDuration,
      (staleDuration, controller) => controller.staleDuration < staleDuration
          ? controller.staleDuration
          : staleDuration,
    );
  }

  RetryCondition? get retryWhen {
    if (observers.isEmpty) return null;

    return observers.first.retryWhen;
  }

  int get retryMaxAttempts {
    if (observers.isEmpty) return 3;

    return observers.fold<int>(
      observers.first.retryMaxAttempts,
      (retryMaxAttempts, controller) =>
          controller.retryMaxAttempts > retryMaxAttempts
              ? controller.retryMaxAttempts
              : retryMaxAttempts,
    );
  }

  Duration get retryMaxDelay {
    if (observers.isEmpty) return const Duration(seconds: 30);

    return observers.fold<Duration>(
      observers.first.retryMaxDelay,
      (retryMaxDelay, controller) => controller.retryMaxDelay > retryMaxDelay
          ? controller.retryMaxDelay
          : retryMaxDelay,
    );
  }

  Duration get retryDelayFactor {
    if (observers.isEmpty) return const Duration(milliseconds: 200);

    return observers.fold<Duration>(
      observers.first.retryDelayFactor,
      (retryDelayFactor, controller) =>
          controller.retryDelayFactor > retryDelayFactor
              ? controller.retryDelayFactor
              : retryDelayFactor,
    );
  }

  double get retryRandomizationFactor {
    if (observers.isEmpty) return 0.25;

    return observers.fold<double>(
      observers.first.retryRandomizationFactor,
      (retryRandomizationFactor, controller) =>
          controller.retryRandomizationFactor > retryRandomizationFactor
              ? controller.retryRandomizationFactor
              : retryRandomizationFactor,
    );
  }

  Duration? get refetchIntervalDuration {
    if (observers.where((ob) => ob.enabled).isEmpty) return null;

    return observers.fold<Duration?>(
      observers.first.refetchIntervalDuration,
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
    if (state.status.isFetching) return;

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

    if (!isStale(effectiveStaleDuration) && !state.invalidated) return;

    final stateBeforeFetching = state.copyWith();

    state = state.copyWith(status: QueryStatus.fetching);

    try {
      _timerInterceptor = TimerInterceptor<T>(() => effectiveFetcher(id));
      _cancelableOperation = CancelableOperation<T>.fromFuture(
        _timerInterceptor!.value,
      );

      final data = await _cancelableOperation!.valueOrCancellation();

      if (!_cancelableOperation!.isCanceled) {
        state = state.copyWith(
          status: QueryStatus.success,
          data: data,
          dataUpdatedAt: clock.now(),
        );
      } else {
        state = stateBeforeFetching;
      }
    } on Exception catch (error) {
      final shouldRetry =
          effectiveRetryMaxAttempts >= 1 && await effectiveRetryWhen(error);

      if (shouldRetry) {
        state = state.copyWith(
          isRetrying: true,
          error: error,
          errorUpdatedAt: clock.now(),
        );

        try {
          final data = await retry(
            () {
              _timerInterceptor = TimerInterceptor<T>(
                () => effectiveFetcher(id),
              );
              _cancelableOperation = CancelableOperation<T>.fromFuture(
                _timerInterceptor!.value,
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
              isRetrying: false,
              dataUpdatedAt: clock.now(),
            );
          } else {
            state = stateBeforeFetching;
          }
        } on Exception catch (error) {
          state = state.copyWith(
            status: QueryStatus.failure,
            isRetrying: false,
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

  Future cancel() async {
    if (!state.status.isFetching) return;

    await _cancelableOperation?.cancel();
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

  void invalidate() {
    state = state.copyWith(invalidated: true);
  }

  void setRefetchInterval() {
    final duration = refetchIntervalDuration;
    final scheduled = _refetchScheduler?.isScheduled == true;

    if (duration == null) {
      _refetchScheduler?.cancel();
      return;
    }

    if (state.status.isFetching) return;

    if (state.lastUpdatedAt == null) {
      fetch();
      return;
    }

    if (scheduled) {
      _refetchScheduler!.reschedule(duration);
    } else {
      _refetchScheduler = Scheduler.run(duration, fetch);
    }
  }

  @override
  void addListener(QueryObserver<T> listener) {
    super.addListener(listener);

    setRefetchInterval();
  }

  @override
  void removeListener(QueryObserver<T> listener) {
    super.removeListener(listener);

    if (observers.isEmpty) {
      cacheDuration = listener.cacheDuration;
    }

    setRefetchInterval();
  }

  bool isStale(Duration duration) {
    if (!state.hasData || state.dataUpdatedAt == null) return true;

    return clock.now().isAfter(state.dataUpdatedAt!.add(duration)) ||
        clock.now().isAtSameMomentAs(state.dataUpdatedAt!.add(duration));
  }

  @override
  Future close() async {
    await _cancelableOperation?.cancel();
    _refetchScheduler?.cancel();
    _timerInterceptor?.timers.forEach((timer) => timer.cancel());
    await super.close();
  }
}
