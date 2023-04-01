import 'package:fluery/src/base_query.dart';
import 'package:fluery/src/query_client_provider.dart';
import 'package:fluery/src/utils/is_outdated.dart';
import 'package:fluery/src/utils/periodic_timer.dart';
import 'package:fluery/src/utils/retry_resolver.dart';
import 'package:flutter/widgets.dart';

typedef QueryFetcher<Data> = Future<Data> Function(QueryIdentifier id);

typedef QueryWidgetBuilder<Data> = Widget Function(
  BuildContext context,
  QueryState<Data> state,
  Widget? child,
);

enum RefetchMode {
  never,
  stale,
  failure,
  always,
}

enum QueryStatus {
  idle,
  loading,
  retrying,
  success,
  failure,
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

  bool _isFetching = false;
  RetryResolver<Data>? _retryResolver;
  PeriodicTimer? _periodicTimer;

  Set<QueryController<Data>> get controllers {
    return observers.whereType<QueryController<Data>>().toSet();
  }

  QueryFetcher<Data> get fetcher {
    return controllers.first.fetcher;
  }

  Duration get staleDuration {
    return controllers.fold(
      controllers.first.staleDuration,
      (staleDuration, controller) => controller.staleDuration < staleDuration
          ? controller.staleDuration
          : staleDuration,
    );
  }

  int get retryCount {
    return controllers.fold(
      controllers.first.retryCount,
      (retryCount, controller) => controller.retryCount > retryCount
          ? controller.retryCount
          : retryCount,
    );
  }

  Duration get retryDelayDuration {
    return controllers.fold(
      controllers.first.retryDelayDuration,
      (retryDelayDuration, controller) =>
          controller.retryDelayDuration > retryDelayDuration
              ? controller.retryDelayDuration
              : retryDelayDuration,
    );
  }

  Duration? get refetchIntervalDuration {
    return controllers.fold(
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
    final effectiveFetcher = fetcher ?? this.fetcher;
    final effectiveStaleDuration = staleDuration ?? this.staleDuration;
    final effectiveRetryCount = retryCount ?? this.retryCount;
    final effectiveRetryDelayDuration =
        retryDelayDuration ?? this.retryDelayDuration;

    if (observers.isEmpty) {
      return;
    }

    if (state.status == QueryStatus.success &&
        state.dataUpdatedAt != null &&
        !isOutdated(state.dataUpdatedAt!, effectiveStaleDuration)) {
      return;
    }

    if (_isFetching) {
      return;
    } else {
      _isFetching = true;
    }

    Future<void> execute() async {
      notify(QueryStateUpdated<QueryState<Data>>(
        state = state.copyWith(
          status: QueryStatus.loading,
          retried: 0,
        ),
      ));

      try {
        final data = await effectiveFetcher(id);

        notify(QueryStateUpdated<QueryState<Data>>(
          state = state.copyWith(
            status: QueryStatus.success,
            data: data,
            dataUpdatedAt: DateTime.now(),
          ),
        ));
      } catch (error) {
        final shouldRetry = effectiveRetryCount >= 1;

        if (shouldRetry) {
          notify(QueryStateUpdated<QueryState<Data>>(
            state = state.copyWith(
              status: QueryStatus.retrying,
              error: error,
              errorUpdatedAt: DateTime.now(),
            ),
          ));

          _retryResolver = RetryResolver<Data>(
            () => effectiveFetcher(id),
            maxCount: effectiveRetryCount,
            delayDuration: effectiveRetryDelayDuration,
            onError: (error, retried) {
              if (retried < effectiveRetryCount) {
                notify(QueryStateUpdated<QueryState<Data>>(
                  state = state.copyWith(
                    retried: retried,
                    error: error,
                    errorUpdatedAt: DateTime.now(),
                  ),
                ));
              } else {
                notify(QueryStateUpdated<QueryState<Data>>(
                  state = state.copyWith(
                    status: QueryStatus.failure,
                    retried: retried,
                    error: error,
                    errorUpdatedAt: DateTime.now(),
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
              dataUpdatedAt: DateTime.now(),
            ),
          ));
        } else {
          notify(QueryStateUpdated<QueryState<Data>>(
            state = state.copyWith(
              status: QueryStatus.failure,
              error: error,
              errorUpdatedAt: DateTime.now(),
            ),
          ));
        }
      }
    }

    try {
      await execute();
    } catch (error) {
      rethrow;
    } finally {
      _isFetching = false;
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
          dataUpdatedAt: updatedAt ?? DateTime.now(),
        ),
      ));
    }
  }

  void setRefetchInterval() {
    if (refetchIntervalDuration == null) {
      _periodicTimer?.stop();
      return;
    }

    _periodicTimer ??= PeriodicTimer(fetch, refetchIntervalDuration!);
    _periodicTimer!.setInterval(refetchIntervalDuration!);
    _periodicTimer!.start();
  }
}

class QueryController<Data> extends ValueNotifier<QueryState<Data>>
    with BaseQueryObserver<Query<Data>> {
  QueryController() : super(QueryState<Data>());

  Query? _query;

  late QueryIdentifier _id;
  late QueryFetcher<Data> _fetcher;
  late Data? _placeholderData;
  late Duration _staleDuration;
  late int _retryCount;
  late Duration _retryDelayDuration;
  late Duration? _refetchIntervalDuration;

  QueryIdentifier get id => _id;
  QueryFetcher<Data> get fetcher => _fetcher;
  Data? get placeholderData => _placeholderData;
  Duration get staleDuration => _staleDuration;
  int get retryCount => _retryCount;
  Duration get retryDelayDuration => _retryDelayDuration;
  Duration? get refetchIntervalDuration => _refetchIntervalDuration;

  @override
  QueryState<Data> get value {
    if (!super.value.hasData && super.value.status == QueryStatus.loading) {
      return super.value.copyWith(data: _placeholderData);
    }

    return super.value;
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
      }
    } else if (event is QueryObserverRemoved<QueryController<Data>>) {
      if (event.observer == this) {
        _query = null;
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
    this.initialData,
    this.initialDataUpdatedAt,
    this.placeholderData,
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
  final Data? initialData;
  final DateTime? initialDataUpdatedAt;
  final Data? placeholderData;
  final Duration staleDuration;
  final int retryCount;
  final Duration retryDelayDuration;
  final RefetchMode refetchOnInit;
  final RefetchMode refetchOnResumed;
  final Duration? refetchIntervalDuration;
  final QueryWidgetBuilder<Data> builder;
  final Widget? child;

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
    _effectiveController._placeholderData = widget.placeholderData;
    _effectiveController._staleDuration = widget.staleDuration;
    _effectiveController._retryCount = widget.retryCount;
    _effectiveController._retryDelayDuration = widget.retryDelayDuration;
    _effectiveController._refetchIntervalDuration =
        widget.refetchIntervalDuration;

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      if (_query.state.status == QueryStatus.idle) {
        await _effectiveController.fetch();
      } else {
        await _refetch(widget.refetchOnInit);
      }

      if (widget.refetchIntervalDuration != null) {
        _query.setRefetchInterval();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _query = QueryClientProvider.of(context)
        .manager
        .buildQuery(_effectiveController.id);

    _query.addObserver<QueryController<Data>>(_effectiveController);

    if (widget.initialData != null) {
      _query.setInitialData(
        // ignore: null_check_on_nullable_type_parameter
        data: widget.initialData!,
        updatedAt: widget.initialDataUpdatedAt,
      );
    }
  }

  @override
  void didUpdateWidget(covariant QueryBuilder<Data> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != null && widget.controller == null) {
      _query.removeObserver<QueryController<Data>>(oldWidget.controller!);
    } else if (oldWidget.controller == null && widget.controller != null) {
      _query.removeObserver<QueryController<Data>>(_controller);
    } else if (oldWidget.controller != widget.controller) {
      _query.removeObserver<QueryController<Data>>(oldWidget.controller!);
    }

    _effectiveController._id = widget.id;
    _effectiveController._fetcher = widget.fetcher;
    _effectiveController._placeholderData = widget.placeholderData;
    _effectiveController._staleDuration = widget.staleDuration;
    _effectiveController._retryCount = widget.retryCount;
    _effectiveController._retryDelayDuration = widget.retryDelayDuration;
    _effectiveController._refetchIntervalDuration =
        widget.refetchIntervalDuration;

    _query = QueryClientProvider.of(context)
        .manager
        .buildQuery(_effectiveController.id);

    if (oldWidget.controller != null && widget.controller == null) {
      _query.addObserver<QueryController<Data>>(_controller);
    } else if (oldWidget.controller == null && widget.controller != null) {
      _query.addObserver<QueryController<Data>>(widget.controller!);
    } else if (oldWidget.controller != widget.controller) {
      _query.addObserver<QueryController<Data>>(widget.controller!);
    }

    if (widget.id != oldWidget.id ||
        widget.staleDuration != oldWidget.staleDuration) {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        _effectiveController.fetch();
      });
    }

    if (widget.refetchIntervalDuration != oldWidget.refetchIntervalDuration) {
      _query.setRefetchInterval();
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
    _query.setRefetchInterval();
    _controller.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _refetch(RefetchMode mode) async {
    switch (mode) {
      case RefetchMode.never:
        break;
      case RefetchMode.stale:
        await _effectiveController.fetch();
        break;
      case RefetchMode.failure:
        if (_query.state.status == QueryStatus.failure) {
          await _effectiveController.fetch();
        }
        break;
      case RefetchMode.always:
        await _effectiveController.fetch(staleDuration: Duration.zero);
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
