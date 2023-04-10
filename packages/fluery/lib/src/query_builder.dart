import 'dart:async';

import 'package:fluery/src/base_query.dart';
import 'package:fluery/src/query_client_provider.dart';
import 'package:fluery/src/query_status.dart';
import 'package:fluery/src/utils/periodic_timer.dart';
import 'package:fluery/src/utils/retry_resolver.dart';
import 'package:fluery/src/utils/zoned_timer_interceptor.dart';
import 'package:flutter/widgets.dart';
import 'package:clock/clock.dart';

typedef QueryFetcher<Data> = Future<Data> Function(QueryIdentifier id);

typedef QueryWidgetBuilder<Data> = Widget Function(
  BuildContext context,
  QueryState<Data> state,
  Widget? child,
);

enum RefetchMode {
  never,
  stale,
  always,
}

class QueryState<Data> extends BaseQueryState {
  const QueryState({
    this.status = QueryStatus.idle,
    this.data,
    this.dataUpdatedAt,
    this.retried = 0,
    this.error,
    this.errorUpdatedAt,
  });

  final QueryStatus status;
  final Data? data;
  final int retried;
  final Object? error;
  final DateTime? dataUpdatedAt;
  final DateTime? errorUpdatedAt;

  bool get hasData => data != null;

  bool get hasError => error != null;

  QueryState<Data> copyWith({
    QueryStatus? status,
    Data? data,
    int? retried,
    Object? error,
    DateTime? dataUpdatedAt,
    DateTime? errorUpdatedAt,
  }) {
    return QueryState<Data>(
      status: status ?? this.status,
      data: data ?? this.data,
      retried: retried ?? this.retried,
      error: error ?? this.error,
      dataUpdatedAt: dataUpdatedAt ?? this.dataUpdatedAt,
      errorUpdatedAt: errorUpdatedAt ?? this.errorUpdatedAt,
    );
  }

  factory QueryState.fromJson(Map<String, dynamic> json) {
    // Not implemented yet.
    return QueryState();
  }

  @override
  List<Object?> get props => [
        status,
        data,
        retried,
        error,
        dataUpdatedAt,
        errorUpdatedAt,
      ];
}

class Query<Data> extends BaseQuery {
  Query({
    required QueryIdentifier id,
    QueryState<Data>? initialState,
  }) : super(id) {
    state = initialState ?? QueryState<Data>();
  }

  late QueryState<Data> state;

  final ZonedTimerInterceptor _zonedTimerInterceptor = ZonedTimerInterceptor();
  RetryResolver<Data>? _retryResolver;
  PeriodicTimer? _periodicTimer;

  Set<QueryController<Data>> get controllers {
    return observers.whereType<QueryController<Data>>().toSet();
  }

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

  int? get retryCount {
    if (!active) return null;

    return controllers.fold<int>(
      controllers.first.retryCount,
      (retryCount, controller) => controller.retryCount > retryCount
          ? controller.retryCount
          : retryCount,
    );
  }

  Duration? get retryDelayDuration {
    if (!active) return null;

    return controllers.fold<Duration>(
      controllers.first.retryDelayDuration,
      (retryDelayDuration, controller) =>
          controller.retryDelayDuration > retryDelayDuration
              ? controller.retryDelayDuration
              : retryDelayDuration,
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
    int? retryCount,
    Duration? retryDelayDuration,
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
    final effectiveRetryCount = retryCount ?? this.retryCount!;
    final effectiveRetryDelayDuration =
        retryDelayDuration ?? this.retryDelayDuration!;

    notify(QueryStateUpdated<QueryState<Data>>(
      state = state.copyWith(
        status: QueryStatus.fetching,
        retried: 0,
      ),
    ));

    try {
      final data = await _zonedTimerInterceptor.run(
        () => effectiveFetcher(id),
      );

      notify(QueryStateUpdated<QueryState<Data>>(
        state = state.copyWith(
          status: QueryStatus.success,
          data: data,
          dataUpdatedAt: clock.now(),
        ),
      ));
    } catch (error) {
      final shouldRetry = effectiveRetryCount >= 1;

      if (shouldRetry) {
        notify(QueryStateUpdated<QueryState<Data>>(
          state = state.copyWith(
            status: QueryStatus.retrying,
            error: error,
            errorUpdatedAt: clock.now(),
          ),
        ));

        _retryResolver = RetryResolver<Data>(
          () => _zonedTimerInterceptor.run(() => effectiveFetcher(id)),
          maxCount: effectiveRetryCount,
          delayDuration: effectiveRetryDelayDuration,
          onError: (error, retried) {
            if (retried < effectiveRetryCount) {
              notify(QueryStateUpdated<QueryState<Data>>(
                state = state.copyWith(
                  retried: retried,
                  error: error,
                  errorUpdatedAt: clock.now(),
                ),
              ));
            } else {
              notify(QueryStateUpdated<QueryState<Data>>(
                state = state.copyWith(
                  status: QueryStatus.failure,
                  retried: retried,
                  error: error,
                  errorUpdatedAt: clock.now(),
                ),
              ));
            }
          },
        );

        final data = await _retryResolver!.call();

        notify(QueryStateUpdated<QueryState<Data>>(
          state = state.copyWith(
            status: QueryStatus.success,
            data: data,
            dataUpdatedAt: clock.now(),
          ),
        ));
      } else {
        notify(QueryStateUpdated<QueryState<Data>>(
          state = state.copyWith(
            status: QueryStatus.failure,
            error: error,
            errorUpdatedAt: clock.now(),
          ),
        ));
      }
    }
  }

  void setInitialData({
    required Data data,
    DateTime? updatedAt,
  }) {
    final isDataUpToDate = updatedAt != null &&
        state.dataUpdatedAt != null &&
        updatedAt.isAfter(state.dataUpdatedAt!);

    if (!state.hasData || isDataUpToDate) {
      notify(QueryStateUpdated(
        state = state.copyWith(
          status: QueryStatus.success,
          data: data,
          dataUpdatedAt: updatedAt ?? clock.now(),
        ),
      ));
    }
  }

  void setData(Data data) {
    notify(QueryStateUpdated(
      state = state.copyWith(
        status: QueryStatus.success,
        data: data,
        retried: 0,
        dataUpdatedAt: clock.now(),
      ),
    ));
  }

  void setState(QueryState<Data> state) {
    notify(QueryStateUpdated(this.state = state));
  }

  void onRefetchIntervalChanged() {
    if (refetchIntervalDuration == null) {
      _periodicTimer?.stop();
      return;
    }

    _periodicTimer ??= PeriodicTimer(fetch, refetchIntervalDuration!);
    _periodicTimer!.setInterval(refetchIntervalDuration!);
    _periodicTimer!.start();
  }

  void dispose() {
    _zonedTimerInterceptor.cancel();
  }
}

class QueryController<Data> extends ValueNotifier<QueryState<Data>>
    with BaseQueryObserver<Query<Data>> {
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
  late Data? _preview;
  late Duration _staleDuration;
  late int _retryCount;
  late Duration _retryDelayDuration;
  late Duration? _refetchIntervalDuration;

  QueryIdentifier get id => _id;
  QueryFetcher<Data> get fetcher => _fetcher;
  bool get enabled => _enabled;
  Data? get placeholderData => _preview;
  Duration get staleDuration => _staleDuration;
  int get retryCount => _retryCount;
  Duration get retryDelayDuration => _retryDelayDuration;
  Duration? get refetchIntervalDuration => _refetchIntervalDuration;

  set refetchIntervalDuration(Duration? value) {
    _refetchIntervalDuration = value;
    _query?.onRefetchIntervalChanged();
  }

  @override
  QueryState<Data> get value {
    QueryState<Data> state = super.value;

    if (_enabled && state.status.isIdle) {
      state = state.copyWith(status: QueryStatus.fetching);
    }

    if (!state.hasData && state.status.isLoading) {
      state = state.copyWith(data: _preview);
    }

    return state;
  }

  Future<void> fetch({
    Duration? staleDuration,
    int? retryCount,
    Duration? retryDelayDuration,
  }) async {
    await _query!.fetch(
      fetcher: _fetcher,
      staleDuration: staleDuration ?? _staleDuration,
      retryCount: retryCount ?? _retryCount,
      retryDelayDuration: retryDelayDuration ?? _retryDelayDuration,
    );
  }

  @override
  void onNotified(Query<Data> query, BaseQueryEvent event) {
    if (event is QueryStateUpdated<QueryState<Data>>) {
      value = event.state;
    } else if (event is QueryObserverAdded<QueryController<Data>>) {
      if (event.observer == this) {
        _query = query;
        value = query.state;
        if (_initialData != null) {
          query.setInitialData(
            // ignore: null_check_on_nullable_type_parameter
            data: _initialData!,
            updatedAt: _initialDataUpdatedAt,
          );
        }
        if (_enabled) {
          query.onRefetchIntervalChanged();
        }
      }
    } else if (event is QueryObserverRemoved<QueryController<Data>>) {
      if (event.observer == this) {
        _query = null;
        query.onRefetchIntervalChanged();
      }
    }
  }
}

class QueryBuilder<Data> extends StatefulWidget {
  const QueryBuilder({
    super.key,
    this.controller,
    required this.id,
    required this.fetcher,
    this.enabled = true,
    this.preview,
    this.staleDuration = Duration.zero,
    this.retryCount = 0,
    this.retryDelayDuration = const Duration(seconds: 3),
    this.refetchOnInit = RefetchMode.stale,
    this.refetchOnResumed = RefetchMode.stale,
    this.refetchIntervalDuration,
    required this.builder,
    this.child,
  });

  final QueryController<Data>? controller;
  final QueryIdentifier id;
  final QueryFetcher<Data> fetcher;
  final bool enabled;
  final Data? preview;
  final Duration staleDuration;
  final int retryCount;
  final Duration retryDelayDuration;
  final RefetchMode refetchOnInit;
  final RefetchMode refetchOnResumed;
  final Duration? refetchIntervalDuration;
  final QueryWidgetBuilder<Data> builder;
  final Widget? child;

  @visibleForTesting
  QueryBuilder copyWith({
    QueryController<Data>? controller,
    QueryIdentifier? id,
    QueryFetcher<Data>? fetcher,
    bool? enabled,
    Data? preview,
    Duration? staleDuration,
    int? retryCount,
    Duration? retryDelayDuration,
    RefetchMode? refetchOnInit,
    RefetchMode? refetchOnResumed,
    Duration? refetchIntervalDuration,
    QueryWidgetBuilder<Data>? builder,
    Widget? child,
  }) {
    return QueryBuilder<Data>(
      controller: controller ?? this.controller,
      id: id ?? this.id,
      fetcher: fetcher ?? this.fetcher,
      enabled: enabled ?? this.enabled,
      preview: preview ?? this.preview,
      staleDuration: staleDuration ?? this.staleDuration,
      retryCount: retryCount ?? this.retryCount,
      retryDelayDuration: retryDelayDuration ?? this.retryDelayDuration,
      refetchOnInit: refetchOnInit ?? this.refetchOnInit,
      refetchOnResumed: refetchOnResumed ?? this.refetchOnResumed,
      refetchIntervalDuration:
          refetchIntervalDuration ?? this.refetchIntervalDuration,
      builder: builder ?? this.builder,
      child: child ?? this.child,
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
    _effectiveController._preview = widget.preview;
    _effectiveController._staleDuration = widget.staleDuration;
    _effectiveController._retryCount = widget.retryCount;
    _effectiveController._retryDelayDuration = widget.retryDelayDuration;
    _effectiveController._refetchIntervalDuration =
        widget.refetchIntervalDuration;

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _initQuery();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _query = QueryClientProvider.of(context)
        .manager
        .buildQuery(_effectiveController.id);

    _query.addObserver<QueryController<Data>>(_effectiveController);
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
      _query.removeObserver<QueryController<Data>>(_controller);
    } else if (!hasController && hadController) {
      _query.removeObserver<QueryController<Data>>(oldWidget.controller!);
    } else if (hasController && hadController && !hasHadSameController) {
      _query.removeObserver<QueryController<Data>>(oldWidget.controller!);
    } else if (hasHadNoController && widget.id != oldWidget.id) {
      _query.removeObserver<QueryController<Data>>(_controller);
    } else if (hasHadSameController && widget.id != oldWidget.id) {
      _query.removeObserver<QueryController<Data>>(widget.controller!);
    }

    _effectiveController._id = widget.id;
    _effectiveController._fetcher = widget.fetcher;
    _effectiveController._enabled = widget.enabled;
    _effectiveController._preview = widget.preview;
    _effectiveController._staleDuration = widget.staleDuration;
    _effectiveController._retryCount = widget.retryCount;
    _effectiveController._retryDelayDuration = widget.retryDelayDuration;
    _effectiveController._refetchIntervalDuration =
        widget.refetchIntervalDuration;

    if (widget.id != oldWidget.id) {
      _query = QueryClientProvider.of(context).manager.buildQuery(widget.id);
    }

    if (hasController && !hadController) {
      _query.addObserver<QueryController<Data>>(widget.controller!);
    } else if (!hasController && hadController) {
      _query.addObserver<QueryController<Data>>(_controller);
    } else if (hasController && hadController && !hasHadSameController) {
      _query.addObserver<QueryController<Data>>(widget.controller!);
    } else if (hasHadNoController && widget.id != oldWidget.id) {
      _query.addObserver<QueryController<Data>>(_controller);
    } else if (hasHadSameController && widget.id != oldWidget.id) {
      _query.addObserver<QueryController<Data>>(widget.controller!);
    }

    if (widget.id != oldWidget.id || widget.enabled && !oldWidget.enabled) {
      _initQuery();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refetch(widget.refetchOnResumed);
    }
  }

  @override
  void dispose() {
    _query.removeObserver<QueryController<Data>>(_effectiveController);
    _controller.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initQuery() async {
    if (_query.state.status == QueryStatus.idle) {
      await _fetch();
    } else {
      await _refetch(widget.refetchOnInit);
    }
  }

  Future<void> _fetch({
    bool ignoreStaleness = false,
  }) async {
    if (!widget.enabled) return;

    await _query.fetch(
      fetcher: widget.fetcher,
      staleDuration: ignoreStaleness ? Duration.zero : widget.staleDuration,
      retryCount: widget.retryCount,
      retryDelayDuration: widget.retryDelayDuration,
    );
  }

  Future<void> _refetch(RefetchMode mode) async {
    switch (mode) {
      case RefetchMode.never:
        break;
      case RefetchMode.stale:
        await _fetch();
        break;
      case RefetchMode.always:
        await _fetch(ignoreStaleness: true);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<QueryState<Data>>(
      valueListenable: _effectiveController,
      builder: (context, value, child) {
        return widget.builder(context, value, child);
      },
      child: widget.child,
    );
  }
}
