part of 'index.dart';

class QueryBuilder<T> extends StatefulWidget {
  const QueryBuilder({
    super.key,
    this.controller,
    required this.id,
    required this.fetcher,
    this.enabled = true,
    this.initialData,
    this.initialDataUpdatedAt,
    this.placeholder,
    this.staleDuration = Duration.zero,
    this.cacheDuration = const Duration(minutes: 5),
    this.retryWhen,
    this.retryMaxAttempts = 3,
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

  final QueryController<T>? controller;
  final QueryIdentifier id;
  final QueryFetcher<T> fetcher;
  final bool enabled;
  final T? initialData;
  final DateTime? initialDataUpdatedAt;
  final T? placeholder;
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
  final QueryBuilderCondition<T>? buildWhen;
  final QueryWidgetBuilder<T> builder;
  final Widget? child;

  @visibleForTesting
  QueryBuilder<T> copyWith({
    Key? key,
    QueryIdentifier? id,
    QueryFetcher<T>? fetcher,
    bool? enabled,
    T? initialData,
    DateTime? initialDataUpdatedAt,
    T? placeholder,
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
    QueryBuilderCondition<T>? buildWhen,
    QueryWidgetBuilder<T>? builder,
    Widget? child,
  }) {
    return QueryBuilder<T>(
      key: key ?? this.key,
      id: id ?? this.id,
      fetcher: fetcher ?? this.fetcher,
      enabled: enabled ?? this.enabled,
      initialData: initialData ?? this.initialData,
      initialDataUpdatedAt: initialDataUpdatedAt ?? this.initialDataUpdatedAt,
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
  QueryBuilder<T> copyWithNull({
    bool key = false,
    bool initialData = false,
    bool initialDataUpdatedAt = false,
    bool placeholder = false,
    bool retryWhen = false,
    bool refetchIntervalDuration = false,
    bool buildWhen = false,
    bool child = false,
  }) {
    return QueryBuilder<T>(
      key: key ? null : this.key,
      id: this.id,
      fetcher: this.fetcher,
      enabled: this.enabled,
      initialData: initialData ? null : this.initialData,
      initialDataUpdatedAt:
          initialDataUpdatedAt ? null : this.initialDataUpdatedAt,
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
  State<QueryBuilder<T>> createState() => _QueryBuilderState<T>();
}

class _QueryBuilderState<T> extends State<QueryBuilder<T>>
    with WidgetsBindingObserver
    implements _QueryWidgetState<T> {
  late Query<T> _query;

  QueryController<T>? _internalController;

  QueryController<T> get _controller =>
      widget.controller ?? _internalController!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _query = context.read<QueryClient>().cache.build<T>(widget.id);

    if (widget.initialData != null) {
      _query.setInitialData(
        widget.initialData!,
        widget.initialDataUpdatedAt,
      );
    }

    if (widget.controller == null) {
      _internalController = QueryController<T>().._attach(this);
    }

    _query.addListener(_controller);

    if (_query.state.status.isIdle) {
      fetch();
    } else {
      refetch(widget.refetchOnInit);
    }
  }

  @override
  void dispose() {
    _query.removeListener(_controller);
    _controller._detach(this);
    _internalController?.dispose();
    _internalController = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final query = context.watch<QueryClient>().cache.build<T>(widget.id);

    if (query != _query) {
      _query.removeListener(_controller);

      _query = query;

      if (widget.initialData != null) {
        _query.setInitialData(
          widget.initialData!,
          widget.initialDataUpdatedAt,
        );
      }

      _query.addListener(_controller);

      if (_query.state.status.isIdle) {
        fetch();
      } else {
        refetch(widget.refetchOnInit);
      }
    }
  }

  @override
  void didUpdateWidget(covariant QueryBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldController = oldWidget.controller ?? _internalController!;

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      if (widget.controller != null) {
        _internalController?._detach(this);
        _internalController?.dispose();
        _internalController = null;
        widget.controller?._attach(this);
      } else {
        assert(_internalController == null);
        _internalController = QueryController<T>().._attach(this);
      }
    }

    if (widget.id != oldWidget.id) {
      _query.removeListener(oldController);

      _query = context.read<QueryClient>().cache.build<T>(widget.id);

      if (widget.initialData != null) {
        _query.setInitialData(
          widget.initialData!,
          widget.initialDataUpdatedAt,
        );
      }

      _query.addListener(_controller);
    }

    if (widget.id != oldWidget.id || widget.enabled && !oldWidget.enabled) {
      if (_query.state.status.isIdle) {
        fetch();
      } else {
        refetch(widget.refetchOnInit);
      }
    }

    if (widget.refetchIntervalDuration != oldWidget.refetchIntervalDuration) {
      _query.setRefetchInterval();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refetch(widget.refetchOnResumed);
    }
  }

  Future fetch({bool ignoreStaleness = false}) async {
    if (!widget.enabled) {
      return;
    }

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

  Future refetch(RefetchMode mode) async {
    switch (mode) {
      case RefetchMode.never:
        break;
      case RefetchMode.stale:
        await fetch();
        break;
      case RefetchMode.always:
        await fetch(ignoreStaleness: true);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConditionalValueListenableBuilder<QueryState<T>>(
      valueListenable: _controller,
      buildWhen: widget.buildWhen,
      builder: widget.builder,
      child: widget.child,
    );
  }

  @override
  Query<T> get query => _query;

  @override
  QueryIdentifier get id => widget.id;

  @override
  QueryFetcher<T> get fetcher => widget.fetcher;

  @override
  bool get enabled => widget.enabled;

  @override
  get initialData => widget.initialData;

  @override
  DateTime? get initialDataUpdatedAt => widget.initialDataUpdatedAt;

  @override
  T? get placeholder => widget.placeholder;

  @override
  Duration get staleDuration => widget.staleDuration;

  @override
  Duration get cacheDuration => widget.cacheDuration;

  @override
  RetryCondition? get retryWhen => widget.retryWhen;

  @override
  int get retryMaxAttempts => widget.retryMaxAttempts;

  @override
  Duration get retryMaxDelay => widget.retryMaxDelay;

  @override
  Duration get retryDelayFactor => widget.retryDelayFactor;

  @override
  double get retryRandomizationFactor => widget.retryRandomizationFactor;

  @override
  Duration? get refetchIntervalDuration => widget.refetchIntervalDuration;
}
