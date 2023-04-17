import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:fluery/src/query_cache.dart';
import 'package:fluery/src/query_client_provider.dart';
import 'package:fluery/src/query_status.dart';
import 'package:fluery/src/utils/retry_resolver.dart';
import 'package:fluery/src/utils/zoned_timer_interceptor.dart';
import 'package:flutter/widgets.dart';
import 'package:clock/clock.dart';

typedef QueryIdentifier = String;

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

class QueryState<Data> extends Equatable {
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

class Query<Data> {
  Query(
    this.id,
    this.cache,
  );

  final QueryIdentifier id;
  final QueryCache cache;
  final Set<QueryController<Data>> controllers = {};

  QueryState<Data> state = QueryState<Data>();

  final ZonedTimerInterceptor _zonedTimerInterceptor = ZonedTimerInterceptor();
  RetryResolver<Data>? _retryResolver;
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

    update(state.copyWith(
      status: QueryStatus.fetching,
      retried: 0,
    ));

    try {
      final data = await _zonedTimerInterceptor.run(
        () => effectiveFetcher(id),
      );

      update(state.copyWith(
        status: QueryStatus.success,
        data: data,
        dataUpdatedAt: clock.now(),
      ));
    } catch (error) {
      final shouldRetry = effectiveRetryCount >= 1;

      if (shouldRetry) {
        update(state.copyWith(
          status: QueryStatus.retrying,
          error: error,
          errorUpdatedAt: clock.now(),
        ));

        _retryResolver = RetryResolver<Data>(
          () => _zonedTimerInterceptor.run(() => effectiveFetcher(id)),
          maxCount: effectiveRetryCount,
          delayDuration: effectiveRetryDelayDuration,
          onError: (error, retried) {
            if (retried < effectiveRetryCount) {
              update(state.copyWith(
                retried: retried,
                error: error,
                errorUpdatedAt: clock.now(),
              ));
            } else {
              update(state.copyWith(
                status: QueryStatus.failure,
                retried: retried,
                error: error,
                errorUpdatedAt: clock.now(),
              ));
            }
          },
        );

        final data = await _retryResolver!.call();

        update(state.copyWith(
          status: QueryStatus.success,
          data: data,
          dataUpdatedAt: clock.now(),
        ));
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
        retried: 0,
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
    _zonedTimerInterceptor.cancel();
    _retryResolver?.cancel();
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
  late int _retryCount;
  late Duration _retryDelayDuration;
  late Duration? _refetchIntervalDuration;

  QueryIdentifier get id => _id;
  QueryFetcher<Data> get fetcher => _fetcher;
  bool get enabled => _enabled;
  Data? get placeholder => _placeholder;
  Duration get staleDuration => _staleDuration;
  Duration get cacheDuration => _cacheDuration;
  int get retryCount => _retryCount;
  Duration get retryDelayDuration => _retryDelayDuration;
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
  final Data? placeholder;
  final Duration staleDuration;
  final Duration cacheDuration;
  final int retryCount;
  final Duration retryDelayDuration;
  final RefetchMode refetchOnInit;
  final RefetchMode refetchOnResumed;
  final Duration? refetchIntervalDuration;
  final QueryWidgetBuilder<Data> builder;
  final Widget? child;

  @visibleForTesting
  QueryBuilder copyWith({
    Key? key,
    QueryController<Data>? controller,
    QueryIdentifier? id,
    QueryFetcher<Data>? fetcher,
    bool? enabled,
    Data? placeholder,
    Duration? staleDuration,
    Duration? cacheDuration,
    int? retryCount,
    Duration? retryDelayDuration,
    RefetchMode? refetchOnInit,
    RefetchMode? refetchOnResumed,
    Duration? refetchIntervalDuration,
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
    _effectiveController._placeholder = widget.placeholder;
    _effectiveController._staleDuration = widget.staleDuration;
    _effectiveController._cacheDuration = widget.cacheDuration;
    _effectiveController._retryCount = widget.retryCount;
    _effectiveController._retryDelayDuration = widget.retryDelayDuration;
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
    _effectiveController._retryCount = widget.retryCount;
    _effectiveController._retryDelayDuration = widget.retryDelayDuration;
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
      retryCount: widget.retryCount,
      retryDelayDuration: widget.retryDelayDuration,
    );
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
