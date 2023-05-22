import 'dart:async';

import 'package:async/async.dart';
import 'package:clock/clock.dart';
import 'package:fluery/src/conditional_value_listenable_builder.dart';
import 'package:fluery/src/query/query.dart';
import 'package:fluery/src/timer_interceptor.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:retry/retry.dart';

part 'paged_query_builder.dart';
part 'paged_query_controller.dart';
part 'paged_query_observer.dart';
part 'paged_query_state.dart';

typedef Pages<T> = List<T>;

typedef PagedQueryFetcher<T, P> = Future<T> Function(
  QueryIdentifier id,
  P? param,
);

typedef PagedQueryParamBuilder<T, P> = P? Function(
  Pages<T> pages,
);

typedef PagedQueryWidgetBuilder<T, P> = Widget Function(
  BuildContext context,
  PagedQueryState<T, P> state,
  Widget? child,
);

enum FetchMode {
  initial,
  next,
  previous,
}

mixin _PagedQueryWidgetState {
  Future fetch();

  Future fetchNextPage();

  Future fetchPreviousPage();
}

class PagedQuery<T, P> extends QueryBase<PagedQueryState<T, P>> {
  PagedQuery({
    required super.id,
    required super.cache,
    PagedQueryState<T, P>? initialState,
  }) : super(initialState: initialState ?? PagedQueryState<T, P>());

  final List<PagedQueryObserver<T, P>> _observers =
      <PagedQueryObserver<T, P>>[];

  TimerInterceptor<T>? _timerInterceptor;
  CancelableOperation<T>? _cancelableOperation;

  PagedQueryFetcher<T, P>? get fetcher {
    if (_observers.isEmpty) return null;

    return _observers.first.fetcher;
  }

  PagedQueryParamBuilder<T, P>? get nextPageParamBuilder {
    if (_observers.where((ob) => ob.nextPageParamBuilder != null).isEmpty) {
      return null;
    }

    return _observers.first.nextPageParamBuilder!;
  }

  PagedQueryParamBuilder<T, P>? get previousPageParamBuilder {
    if (_observers.where((ob) => ob.previousPageParamBuilder != null).isEmpty) {
      return null;
    }

    return _observers.first.previousPageParamBuilder!;
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

  Future fetch({
    PagedQueryFetcher<T, P>? fetcher,
    PagedQueryParamBuilder<T, P>? nextPageParamBuilder,
    PagedQueryParamBuilder<T, P>? previousPageParamBuilder,
    Duration? staleDuration,
    RetryCondition? retryWhen,
    int? retryMaxAttempts,
    Duration? retryMaxDelay,
    Duration? retryDelayFactor,
    double? retryRandomizationFactor,
  }) async {
    await _fetch(
      fetchMode: FetchMode.initial,
      fetcher: fetcher,
      nextPageParamBuilder: nextPageParamBuilder,
      previousPageParamBuilder: previousPageParamBuilder,
      staleDuration: staleDuration,
      retryWhen: retryWhen,
      retryMaxAttempts: retryMaxAttempts,
      retryMaxDelay: retryMaxDelay,
      retryDelayFactor: retryDelayFactor,
      retryRandomizationFactor: retryRandomizationFactor,
    );
  }

  Future fetchNextPage({
    PagedQueryFetcher<T, P>? fetcher,
    PagedQueryParamBuilder<T, P>? nextPageParamBuilder,
    PagedQueryParamBuilder<T, P>? previousPageParamBuilder,
    RetryCondition? retryWhen,
    int? retryMaxAttempts,
    Duration? retryMaxDelay,
    Duration? retryDelayFactor,
    double? retryRandomizationFactor,
  }) async {
    await _fetch(
      fetchMode: FetchMode.next,
      fetcher: fetcher,
      nextPageParamBuilder: nextPageParamBuilder,
      previousPageParamBuilder: previousPageParamBuilder,
      retryWhen: retryWhen,
      retryMaxAttempts: retryMaxAttempts,
      retryMaxDelay: retryMaxDelay,
      retryDelayFactor: retryDelayFactor,
      retryRandomizationFactor: retryRandomizationFactor,
    );
  }

  Future fetchPreviousPage({
    PagedQueryFetcher<T, P>? fetcher,
    PagedQueryParamBuilder<T, P>? nextPageParamBuilder,
    PagedQueryParamBuilder<T, P>? previousPageParamBuilder,
    RetryCondition? retryWhen,
    int? retryMaxAttempts,
    Duration? retryMaxDelay,
    Duration? retryDelayFactor,
    double? retryRandomizationFactor,
  }) async {
    await _fetch(
      fetchMode: FetchMode.previous,
      fetcher: fetcher,
      nextPageParamBuilder: nextPageParamBuilder,
      previousPageParamBuilder: previousPageParamBuilder,
      retryWhen: retryWhen,
      retryMaxAttempts: retryMaxAttempts,
      retryMaxDelay: retryMaxDelay,
      retryDelayFactor: retryDelayFactor,
      retryRandomizationFactor: retryRandomizationFactor,
    );
  }

  Future cancel() async {
    if (!state.inProgress) return;

    await _cancelableOperation?.cancel();
  }

  Future _fetch({
    required FetchMode fetchMode,
    PagedQueryFetcher<T, P>? fetcher,
    PagedQueryParamBuilder<T, P>? nextPageParamBuilder,
    PagedQueryParamBuilder<T, P>? previousPageParamBuilder,
    Duration? staleDuration,
    RetryCondition? retryWhen,
    int? retryMaxAttempts,
    Duration? retryMaxDelay,
    Duration? retryDelayFactor,
    double? retryRandomizationFactor,
  }) async {
    switch (fetchMode) {
      case FetchMode.initial:
        if (state.inProgress) return;
        break;
      case FetchMode.next:
        if (state.isFetchingNextPage || !state.hasNextPage) return;
        break;
      case FetchMode.previous:
        if (state.isFetchingPreviousPage || !state.hasPreviousPage) return;
        break;
    }

    final effectiveFetcher = fetcher ?? this.fetcher!;
    final effectiveNextPageParamBuilder =
        nextPageParamBuilder ?? this.nextPageParamBuilder;
    final effectivePreviousPageParamBuilder =
        previousPageParamBuilder ?? this.previousPageParamBuilder;
    final effectiveStaleDuration = staleDuration ?? this.staleDuration;
    final effectiveRetryWhen = retryWhen ?? this.retryWhen ?? (e) => true;
    final effectiveRetryMaxAttempts = retryMaxAttempts ?? this.retryMaxAttempts;
    final effectiveRetryMaxDelay = retryMaxDelay ?? this.retryMaxDelay;
    final effectiveRetryDelayFactor = retryDelayFactor ?? this.retryDelayFactor;
    final effectiveRetryRandomizationFactor =
        retryRandomizationFactor ?? this.retryRandomizationFactor;

    final P? param;
    switch (fetchMode) {
      case FetchMode.initial:
        param = null;
        break;
      case FetchMode.next:
        param = state.nextPageParam;
        break;
      case FetchMode.previous:
        param = state.previousPageParam;
        break;
    }

    if (fetchMode == FetchMode.initial && !isStale(effectiveStaleDuration)) {
      return;
    }

    final stateBeforeFetching = state;

    state = state.copyWith(
      status: QueryStatus.fetching,
      isFetchingNextPage: fetchMode == FetchMode.next,
      isFetchingPreviousPage: fetchMode == FetchMode.previous,
    );

    try {
      _timerInterceptor = TimerInterceptor<T>(
        () => effectiveFetcher(id, param),
      );
      _cancelableOperation = CancelableOperation<T>.fromFuture(
        _timerInterceptor!.value,
      );

      final data = await _cancelableOperation!.valueOrCancellation();

      final Pages<T> pages;
      switch (fetchMode) {
        case FetchMode.initial:
          pages = [data!];
          break;
        case FetchMode.next:
          pages = [...state.pages, data!];
          break;
        case FetchMode.previous:
          pages = [data!, ...state.pages];
          break;
      }

      if (!_cancelableOperation!.isCanceled) {
        final nextPageParam = effectiveNextPageParamBuilder?.call(pages);
        final previousPageParam =
            effectivePreviousPageParamBuilder?.call(pages);

        state = state
            .copyWith(
              status: QueryStatus.success,
              data: pages,
              isFetchingNextPage: false,
              isFetchingPreviousPage: false,
              nextPageParam: nextPageParam,
              previousPageParam: previousPageParam,
              dataUpdatedAt: clock.now(),
            )
            .copyWithNull(
              nextPageParam: nextPageParam == null,
              previousPageParam: previousPageParam == null,
            );
      } else {
        state = stateBeforeFetching;
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
              _timerInterceptor = TimerInterceptor<T>(
                () => effectiveFetcher(id, param),
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

          final Pages<T> pages;
          switch (fetchMode) {
            case FetchMode.initial:
              pages = [data!];
              break;
            case FetchMode.next:
              pages = [...state.pages, data!];
              break;
            case FetchMode.previous:
              pages = [data!, ...state.pages];
              break;
          }

          if (!_cancelableOperation!.isCanceled) {
            final nextPageParam = effectiveNextPageParamBuilder?.call(pages);
            final previousPageParam =
                effectivePreviousPageParamBuilder?.call(pages);

            state = state
                .copyWith(
                  status: QueryStatus.success,
                  data: pages,
                  isFetchingNextPage: false,
                  isFetchingPreviousPage: false,
                  nextPageParam: nextPageParam,
                  previousPageParam: previousPageParam,
                  dataUpdatedAt: clock.now(),
                )
                .copyWithNull(
                  nextPageParam: nextPageParam == null,
                  previousPageParam: previousPageParam == null,
                );
          } else {
            state = stateBeforeFetching;
          }
        } on Exception catch (error) {
          state = state.copyWith(
            status: QueryStatus.failure,
            isFetchingNextPage: false,
            isFetchingPreviousPage: false,
            error: error,
            errorUpdatedAt: clock.now(),
          );
        }
      } else {
        state = state.copyWith(
          status: QueryStatus.failure,
          isFetchingNextPage: false,
          isFetchingPreviousPage: false,
          error: error,
          errorUpdatedAt: clock.now(),
        );
      }
    }
  }

  bool isStale(Duration duration) {
    if (!state.hasData || state.dataUpdatedAt == null) return true;

    final now = clock.now();

    return now.isAfter(state.dataUpdatedAt!.add(duration)) ||
        now.isAtSameMomentAs(state.dataUpdatedAt!.add(duration));
  }

  void setInitialData(
    Pages<T> pages,
    PagedQueryParamBuilder<T, P>? nextPageParamBuilder,
    PagedQueryParamBuilder<T, P>? previousPageParamBuilder, [
    DateTime? updatedAt,
  ]) {
    final effectiveNextPageParamBuilder =
        nextPageParamBuilder ?? this.nextPageParamBuilder;
    final effectivePreviousPageParamBuilder =
        previousPageParamBuilder ?? this.previousPageParamBuilder;

    if ((!state.hasData && state.dataUpdatedAt == null) ||
        (updatedAt != null && updatedAt.isAfter(state.dataUpdatedAt!))) {
      final nextPageParam = effectiveNextPageParamBuilder?.call(pages);
      final previousPageParam = effectivePreviousPageParamBuilder?.call(pages);

      state = state
          .copyWith(
            status: QueryStatus.success,
            data: pages,
            nextPageParam: nextPageParam,
            previousPageParam: previousPageParam,
            dataUpdatedAt: updatedAt ?? clock.now(),
          )
          .copyWithNull(
            nextPageParam: nextPageParam == null,
            previousPageParam: previousPageParam == null,
          );
    }
  }

  void setData(
    Pages<T> pages, [
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
        data: pages,
        dataUpdatedAt: updatedAt ?? clock.now(),
      );
    }
  }

  void addObserver(PagedQueryObserver<T, P> observer) {
    _observers.add(observer);
  }

  void removeObserver(PagedQueryObserver<T, P> observer) {
    _observers.remove(observer);

    if (_observers.isEmpty) {
      cacheDuration = observer.cacheDuration;
    }
  }

  @override
  Future close() async {
    await _cancelableOperation?.cancel();
    _timerInterceptor?.timers.forEach((timer) => timer.cancel());
    await super.close();
  }
}
