part of 'query.dart';

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
