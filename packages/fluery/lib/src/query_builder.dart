import 'dart:async';

import 'package:async/async.dart';
import 'package:equatable/equatable.dart';
import 'package:fluery/src/conditional_value_listenable_builder.dart';
import 'package:fluery/src/query_cache.dart';
import 'package:fluery/src/query_client_provider.dart';
import 'package:fluery/src/query_status.dart';
import 'package:fluery/src/timer_interceptor.dart';
import 'package:flutter/widgets.dart';
import 'package:clock/clock.dart';
import 'package:retry/retry.dart';

typedef QueryIdentifier = String;

typedef QueryFetcher<Data> = Future<Data> Function(QueryIdentifier id);

typedef RetryCondition = FutureOr<bool> Function(Exception e);

typedef QueryWidgetBuilder<Data> = Widget Function(
  BuildContext context,
  QueryState<Data> state,
  Widget? child,
);

typedef QueryBuilderCondition<Data> = bool Function(
  QueryState<Data> previousState,
  QueryState<Data> currentState,
);

enum RefetchMode {
  never,
  stale,
  always,
}

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

class QueryController<Data> extends ValueNotifier<QueryState<Data>> {
  QueryController({
    Data? data,
    DateTime? dataUpdatedAt,
  })  : _initialData = data,
        _initialDataUpdatedAt = dataUpdatedAt,
        super(QueryState<Data>());

  Query? _query;

  final Data? _initialData;
  final DateTime? _initialDataUpdatedAt;

  late QueryIdentifier _id;
  late QueryFetcher<Data> _fetcher;
  late bool _enabled;
  late Data? _placeholder;
  late Duration _staleDuration;
  late Duration _cacheDuration;
  late RetryCondition? _retryWhen;
  late int _retryMaxAttempts;
  late Duration _retryMaxDelay;
  late Duration _retryDelayFactor;
  late double _retryRandomizationFactor;
  late Duration? _refetchIntervalDuration;

  QueryIdentifier get id => _id;
  QueryFetcher<Data> get fetcher => _fetcher;
  bool get enabled => _enabled;
  Data? get placeholder => _placeholder;
  Duration get staleDuration => _staleDuration;
  Duration get cacheDuration => _cacheDuration;
  RetryCondition? get retryWhen => _retryWhen;
  int get retryMaxAttempts => _retryMaxAttempts;
  Duration get retryMaxDelay => _retryMaxDelay;
  Duration get retryDelayFactor => _retryDelayFactor;
  double get retryRandomizationFactor => _retryRandomizationFactor;
  Duration? get refetchIntervalDuration => _refetchIntervalDuration;

  @override
  QueryState<Data> get value {
    QueryState<Data> state = super.value;

    if (!state.hasData) {
      state = state.copyWith(data: _placeholder);
    }

    return state;
  }

  Future<void> refetch({
    Duration? staleDuration,
    RetryCondition? retryWhen,
    int? retryMaxAttempts,
    Duration? retryMaxDelay,
    Duration? retryDelayFactor,
    double? retryRandomizationFactor,
  }) async {
    await _query!.fetch(
      fetcher: _fetcher,
      staleDuration: staleDuration ?? _staleDuration,
      retryWhen: retryWhen ?? _retryWhen,
      retryMaxAttempts: retryMaxAttempts ?? _retryMaxAttempts,
      retryMaxDelay: retryMaxDelay ?? _retryMaxDelay,
      retryDelayFactor: retryDelayFactor ?? _retryDelayFactor,
      retryRandomizationFactor:
          retryRandomizationFactor ?? _retryRandomizationFactor,
    );
  }

  Future<void> cancel({
    Data? data,
    Exception? error,
  }) async {
    await _query!.cancel(
      data: data,
      error: error,
    );
  }

  void onStateUpdated(QueryState<Data> state) {
    value = state;
  }

  void onAddedToQuery(Query<Data> query) {
    _query = query;
    value = query.state;

    if (_initialData != null) {
      // ignore: null_check_on_nullable_type_parameter
      query.setData(_initialData!, _initialDataUpdatedAt);
    }
  }

  void onRemovedFromQuery(Query<Data> query) {
    _query = null;
  }
}

class QueryBuilder<Data> extends StatefulWidget {
  const QueryBuilder({
    super.key,
    this.controller,
    required this.id,
    required this.fetcher,
    this.enabled = true,
    this.placeholder,
    this.staleDuration = Duration.zero,
    this.cacheDuration = const Duration(minutes: 5),
    this.retryWhen,
    this.retryMaxAttempts = 8,
    this.retryMaxDelay = const Duration(seconds: 30),
    this.retryDelayFactor = const Duration(milliseconds: 200),
    this.retryRandomizationFactor = 0.25,
    this.refetchOnInit = RefetchMode.stale,
    this.refetchOnResumed = RefetchMode.stale,
    this.refetchIntervalDuration,
    this.buildWhen,
    required this.builder,
    this.child,
  });

  final QueryController<Data>? controller;
  final QueryIdentifier id;
  final QueryFetcher<Data> fetcher;
  final bool enabled;
  final Data? placeholder;
  final Duration staleDuration;
  final Duration cacheDuration;
  final RetryCondition? retryWhen;
  final int retryMaxAttempts;
  final Duration retryMaxDelay;
  final Duration retryDelayFactor;
  final double retryRandomizationFactor;
  final RefetchMode refetchOnInit;
  final RefetchMode refetchOnResumed;
  final Duration? refetchIntervalDuration;
  final QueryBuilderCondition<Data>? buildWhen;
  final QueryWidgetBuilder<Data> builder;
  final Widget? child;

  @visibleForTesting
  QueryBuilder<Data> copyWith({
    Key? key,
    QueryController<Data>? controller,
    QueryIdentifier? id,
    QueryFetcher<Data>? fetcher,
    bool? enabled,
    Data? placeholder,
    Duration? staleDuration,
    Duration? cacheDuration,
    RetryCondition? retryWhen,
    int? retryMaxAttempts,
    Duration? retryMaxDelay,
    Duration? retryDelayFactor,
    double? retryRandomizationFactor,
    RefetchMode? refetchOnInit,
    RefetchMode? refetchOnResumed,
    Duration? refetchIntervalDuration,
    QueryBuilderCondition<Data>? buildWhen,
    QueryWidgetBuilder<Data>? builder,
    Widget? child,
  }) {
    return QueryBuilder<Data>(
      key: key ?? this.key,
      controller: controller ?? this.controller,
      id: id ?? this.id,
      fetcher: fetcher ?? this.fetcher,
      enabled: enabled ?? this.enabled,
      placeholder: placeholder ?? this.placeholder,
      staleDuration: staleDuration ?? this.staleDuration,
      cacheDuration: cacheDuration ?? this.cacheDuration,
      retryWhen: retryWhen ?? this.retryWhen,
      retryMaxAttempts: retryMaxAttempts ?? this.retryMaxAttempts,
      retryMaxDelay: retryMaxDelay ?? this.retryMaxDelay,
      retryDelayFactor: retryDelayFactor ?? this.retryDelayFactor,
      retryRandomizationFactor:
          retryRandomizationFactor ?? this.retryRandomizationFactor,
      refetchOnInit: refetchOnInit ?? this.refetchOnInit,
      refetchOnResumed: refetchOnResumed ?? this.refetchOnResumed,
      refetchIntervalDuration:
          refetchIntervalDuration ?? this.refetchIntervalDuration,
      buildWhen: buildWhen ?? this.buildWhen,
      builder: builder ?? this.builder,
      child: child ?? this.child,
    );
  }

  @visibleForTesting
  QueryBuilder<Data> copyWithNull({
    bool key = false,
    bool controller = false,
    bool placeholder = false,
    bool retryWhen = false,
    bool refetchIntervalDuration = false,
    bool buildWhen = false,
    bool child = false,
  }) {
    return QueryBuilder<Data>(
      key: key ? null : this.key,
      controller: controller ? null : this.controller,
      id: this.id,
      fetcher: this.fetcher,
      enabled: this.enabled,
      placeholder: placeholder ? null : this.placeholder,
      staleDuration: this.staleDuration,
      cacheDuration: this.cacheDuration,
      retryWhen: retryWhen ? null : this.retryWhen,
      retryMaxAttempts: this.retryMaxAttempts,
      retryMaxDelay: this.retryMaxDelay,
      retryDelayFactor: this.retryDelayFactor,
      retryRandomizationFactor: this.retryRandomizationFactor,
      refetchOnInit: this.refetchOnInit,
      refetchOnResumed: this.refetchOnResumed,
      refetchIntervalDuration:
          refetchIntervalDuration ? null : this.refetchIntervalDuration,
      buildWhen: buildWhen ? null : this.buildWhen,
      builder: this.builder,
      child: this.child,
    );
  }

  @override
  State<QueryBuilder> createState() => _QueryBuilderState<Data>();
}

class _QueryBuilderState<Data> extends State<QueryBuilder<Data>>
    with WidgetsBindingObserver {
  final QueryController<Data> _controller = QueryController<Data>();

  late Query<Data> _query;

  QueryController<Data> get _effectiveController =>
      widget.controller ?? _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _effectiveController._id = widget.id;
    _effectiveController._fetcher = widget.fetcher;
    _effectiveController._enabled = widget.enabled;
    _effectiveController._placeholder = widget.placeholder;
    _effectiveController._staleDuration = widget.staleDuration;
    _effectiveController._cacheDuration = widget.cacheDuration;
    _effectiveController._retryWhen = widget.retryWhen;
    _effectiveController._retryMaxAttempts = widget.retryMaxAttempts;
    _effectiveController._retryMaxDelay = widget.retryMaxDelay;
    _effectiveController._retryDelayFactor = widget.retryDelayFactor;
    _effectiveController._retryRandomizationFactor =
        widget.retryRandomizationFactor;
    _effectiveController._refetchIntervalDuration =
        widget.refetchIntervalDuration;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _query = QueryClientProvider.of(context).cache.build(widget.id);
    _query.addController(_effectiveController);

    _initQuery();
  }

  @override
  void didUpdateWidget(covariant QueryBuilder<Data> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final hasController = widget.controller != null;
    final hadController = oldWidget.controller != null;
    final hasHadSameController = widget.controller != null &&
        oldWidget.controller != null &&
        widget.controller == oldWidget.controller;
    final hasHadNoController =
        widget.controller == null && oldWidget.controller == null;

    if (hasController && !hadController) {
      _query.removeController(_controller);
    } else if (!hasController && hadController) {
      _query.removeController(oldWidget.controller!);
    } else if (hasController && hadController && !hasHadSameController) {
      _query.removeController(oldWidget.controller!);
    } else if (hasHadNoController && widget.id != oldWidget.id) {
      _query.removeController(_controller);
    } else if (hasHadSameController && widget.id != oldWidget.id) {
      _query.removeController(widget.controller!);
    }

    _effectiveController._id = widget.id;
    _effectiveController._fetcher = widget.fetcher;
    _effectiveController._enabled = widget.enabled;
    _effectiveController._placeholder = widget.placeholder;
    _effectiveController._staleDuration = widget.staleDuration;
    _effectiveController._cacheDuration = widget.cacheDuration;
    _effectiveController._retryWhen = widget.retryWhen;
    _effectiveController._retryMaxAttempts = widget.retryMaxAttempts;
    _effectiveController._retryMaxDelay = widget.retryMaxDelay;
    _effectiveController._retryDelayFactor = widget.retryDelayFactor;
    _effectiveController._retryRandomizationFactor =
        widget.retryRandomizationFactor;
    _effectiveController._refetchIntervalDuration =
        widget.refetchIntervalDuration;

    if (widget.id != oldWidget.id) {
      _query = QueryClientProvider.of(context).cache.build(widget.id);
    }

    if (hasController && !hadController) {
      _query.addController(widget.controller!);
    } else if (!hasController && hadController) {
      _query.addController(_controller);
    } else if (hasController && hadController && !hasHadSameController) {
      _query.addController(widget.controller!);
    } else if (hasHadNoController && widget.id != oldWidget.id) {
      _query.addController(_controller);
    } else if (hasHadSameController && widget.id != oldWidget.id) {
      _query.addController(widget.controller!);
    }

    if (widget.id != oldWidget.id || widget.enabled && !oldWidget.enabled) {
      _initQuery();
      return;
    }

    if (widget.refetchIntervalDuration != oldWidget.refetchIntervalDuration) {
      _query.setRefetchInterval();
      return;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!widget.enabled) return;

      switch (widget.refetchOnResumed) {
        case RefetchMode.never:
          break;
        case RefetchMode.stale:
          _fetch();
          break;
        case RefetchMode.always:
          _fetch(ignoreStaleness: true);
          break;
      }
    }
  }

  @override
  void dispose() {
    _query.removeController(_effectiveController);
    _controller.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _initQuery() {
    if (!widget.enabled) return;

    if (_query.state.status.isIdle) {
      _fetch();
    } else if (widget.refetchOnInit == RefetchMode.stale) {
      _fetch();
    } else if (widget.refetchOnInit == RefetchMode.always) {
      _fetch(ignoreStaleness: true);
    } else if (widget.refetchIntervalDuration != null) {
      _query.setRefetchInterval();
    }
  }

  Future<void> _fetch({
    bool ignoreStaleness = false,
  }) async {
    await _query.fetch(
      fetcher: widget.fetcher,
      staleDuration: ignoreStaleness ? Duration.zero : widget.staleDuration,
      retryWhen: widget.retryWhen,
      retryMaxAttempts: widget.retryMaxAttempts,
      retryMaxDelay: widget.retryMaxDelay,
      retryDelayFactor: widget.retryDelayFactor,
      retryRandomizationFactor: widget.retryRandomizationFactor,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ConditionalValueListenableBuilder<QueryState<Data>>(
      valueListenable: _effectiveController,
      buildWhen: widget.buildWhen,
      builder: (context, value, child) {
        return widget.builder(context, value, child);
      },
      child: widget.child,
    );
  }
}
