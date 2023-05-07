part of 'query.dart';

class QueryBuilder<T> extends StatefulWidget {
  const QueryBuilder({
    super.key,
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
    with WidgetsBindingObserver {
  late Query<T> _query;
  late final QueryObserver<T> _observer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _query = context.read<QueryClient>().cache.build<T>(widget.id);

    _observer = QueryObserver<T>(
      fetcher: widget.fetcher,
      enabled: widget.enabled,
      placeholder: widget.placeholder,
      staleDuration: widget.staleDuration,
      cacheDuration: widget.cacheDuration,
      retryWhen: widget.retryWhen,
      retryMaxAttempts: widget.retryMaxAttempts,
      retryMaxDelay: widget.retryMaxDelay,
      retryDelayFactor: widget.retryDelayFactor,
      retryRandomizationFactor: widget.retryRandomizationFactor,
      refetchIntervalDuration: widget.refetchIntervalDuration,
    );

    if (widget.initialData != null) {
      _query.setInitialData(
        widget.initialData!,
        widget.initialDataUpdatedAt,
      );
    }

    _observer.bind(_query);

    if (_query.state.status.isIdle) {
      _observer.fetch();
    } else {
      _refetch(widget.refetchOnInit);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final query = context.watch<QueryClient>().cache.build<T>(widget.id);

    if (query != _query) {
      _observer.unbind();

      _query = query;

      if (widget.initialData != null) {
        query.setInitialData(
          widget.initialData!,
          widget.initialDataUpdatedAt,
        );
      }

      _observer.bind(_query);

      if (query.state.status.isIdle) {
        _observer.fetch();
      } else {
        _refetch(widget.refetchOnInit);
      }
    }
  }

  @override
  void dispose() {
    _observer
      ..unbind()
      ..dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant QueryBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.id != oldWidget.id) {
      _observer.unbind();
    }

    _observer
      ..fetcher = widget.fetcher
      ..enabled = widget.enabled
      ..placeholder = widget.placeholder
      ..staleDuration = widget.staleDuration
      ..cacheDuration = widget.cacheDuration
      ..retryWhen = widget.retryWhen
      ..retryMaxAttempts = widget.retryMaxAttempts
      ..retryMaxDelay = widget.retryMaxDelay
      ..retryDelayFactor = widget.retryDelayFactor
      ..retryRandomizationFactor = widget.retryRandomizationFactor
      ..refetchIntervalDuration = widget.refetchIntervalDuration;

    if (widget.id != oldWidget.id) {
      final query = context.read<QueryClient>().cache.build<T>(widget.id);

      _query = query;

      if (widget.initialData != null) {
        query.setInitialData(
          widget.initialData!,
          widget.initialDataUpdatedAt,
        );
      }

      _observer.bind(query);

      if (query.state.status.isIdle) {
        _observer.fetch();
      } else {
        _refetch(widget.refetchOnInit);
      }

      return;
    }

    if (widget.enabled && !oldWidget.enabled) {
      if (_query.state.status.isIdle) {
        _observer.fetch();
      } else {
        _refetch(widget.refetchOnInit);
      }

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
      _refetch(widget.refetchOnResumed);
    }
  }

  Future<void> _refetch(RefetchMode mode) async {
    switch (mode) {
      case RefetchMode.never:
        break;
      case RefetchMode.stale:
        await _observer.fetch();
        break;
      case RefetchMode.always:
        await _observer.fetch(staleDuration: Duration.zero);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConditionalValueListenableBuilder<QueryState<T>>(
      valueListenable: _observer,
      buildWhen: widget.buildWhen,
      builder: widget.builder,
      child: widget.child,
    );
  }
}
