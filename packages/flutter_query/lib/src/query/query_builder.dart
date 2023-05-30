part of 'query.dart';

enum RefetchBehavior {
  never,
  stale,
  always,
}

typedef QueryWidgetBuilder<T> = Widget Function(
  BuildContext context,
  QueryState<T> state,
  Widget? child,
);

typedef QueryBuilderCondition<T> = bool Function(
  QueryState<T> previousState,
  QueryState<T> currentState,
);

class QueryBuilder<T> extends StatefulWidget {
  const QueryBuilder({
    Key? key,
    this.controller,
    required this.id,
    required this.fetcher,
    this.placeholder,
    this.staleDuration = Duration.zero,
    this.cacheDuration = const Duration(minutes: 5),
    this.refetchOnInit = RefetchBehavior.stale,
    this.refetchOnResumed = RefetchBehavior.stale,
    this.buildWhen,
    required this.builder,
    this.child,
  }) : super(key: key);

  final QueryController<T>? controller;
  final QueryId id;
  final QueryFetcher<T> fetcher;
  final T? placeholder;
  final Duration staleDuration;
  final Duration cacheDuration;
  final RefetchBehavior refetchOnInit;
  final RefetchBehavior refetchOnResumed;
  final QueryBuilderCondition<T>? buildWhen;
  final QueryWidgetBuilder<T> builder;
  final Widget? child;

  @visibleForTesting
  QueryBuilder<T> copyWith({
    Key? key,
    QueryController<T>? controller,
    QueryId? id,
    QueryFetcher<T>? fetcher,
    bool? enabled,
    T? placeholder,
    Duration? staleDuration,
    Duration? cacheDuration,
    RefetchBehavior? refetchOnInit,
    RefetchBehavior? refetchOnResumed,
    QueryBuilderCondition<T>? buildWhen,
    QueryWidgetBuilder<T>? builder,
    Widget? child,
  }) {
    return QueryBuilder<T>(
      key: key ?? this.key,
      controller: controller ?? this.controller,
      id: id ?? this.id,
      fetcher: fetcher ?? this.fetcher,
      placeholder: placeholder ?? this.placeholder,
      staleDuration: staleDuration ?? this.staleDuration,
      cacheDuration: cacheDuration ?? this.cacheDuration,
      refetchOnInit: refetchOnInit ?? this.refetchOnInit,
      refetchOnResumed: refetchOnResumed ?? this.refetchOnResumed,
      buildWhen: buildWhen ?? this.buildWhen,
      builder: builder ?? this.builder,
      child: child ?? this.child,
    );
  }

  @visibleForTesting
  QueryBuilder<T> copyWithNull({
    bool key = false,
    bool controller = false,
    bool placeholder = false,
    bool buildWhen = false,
    bool child = false,
  }) {
    return QueryBuilder<T>(
      key: key ? null : this.key,
      controller: controller ? null : this.controller,
      id: this.id,
      fetcher: this.fetcher,
      placeholder: placeholder ? null : this.placeholder,
      staleDuration: this.staleDuration,
      cacheDuration: this.cacheDuration,
      refetchOnInit: this.refetchOnInit,
      refetchOnResumed: this.refetchOnResumed,
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

    if (widget.controller == null) {
      _internalController = QueryController<T>();
    }

    _controller._attach(this);

    _query = context.read<QueryClient>().cacheStorage.buildQuery<T>(widget.id);

    if (!_query.state.status.isIdle) {
      refetch(widget.refetchOnInit);
    }

    _query.addObserver(_controller);
  }

  @override
  void dispose() {
    _query.removeObserver(_controller);
    _controller._detach(this);
    _internalController?.dispose();
    _internalController = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final query =
        context.watch<QueryClient>().cacheStorage.buildQuery<T>(widget.id);

    if (query != _query) {
      _query.removeObserver(_controller);

      _query = query;

      if (!_query.state.status.isIdle) {
        refetch(widget.refetchOnInit);
      }

      _query.addObserver(_controller);
    }
  }

  @override
  void didUpdateWidget(covariant QueryBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldController = oldWidget.controller ?? _internalController!;

    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller != null) {
        _query.removeObserver(oldWidget.controller!);
        oldWidget.controller!._detach(this);
      }
      if (widget.controller != null) {
        if (_internalController != null) {
          _query.removeObserver(_internalController!);
          _internalController!._detach(this);
          _internalController!.dispose();
          _internalController = null;
        }
        _query.addObserver(widget.controller!);
        widget.controller!._attach(this);
      } else {
        assert(_internalController == null);
        _internalController = QueryController<T>().._attach(this);
      }
    }

    if (widget.id != oldWidget.id) {
      _query.removeObserver(oldController);

      _query =
          context.read<QueryClient>().cacheStorage.buildQuery<T>(widget.id);

      if (!_query.state.status.isIdle) {
        refetch(widget.refetchOnInit);
      }

      _query.addObserver(_controller);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refetch(widget.refetchOnResumed);
    }
  }

  Future fetch({bool ignoreStaleness = false}) async {
    await _query.fetch(
      fetcher: widget.fetcher,
      staleDuration: ignoreStaleness ? Duration.zero : widget.staleDuration,
    );
  }

  Future refetch(RefetchBehavior behavior) async {
    switch (behavior) {
      case RefetchBehavior.never:
        break;
      case RefetchBehavior.stale:
        await fetch();
        break;
      case RefetchBehavior.always:
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
  QueryId get id => widget.id;

  @override
  QueryFetcher<T> get fetcher => widget.fetcher;

  @override
  T? get placeholder => widget.placeholder;

  @override
  Duration get staleDuration => widget.staleDuration;

  @override
  Duration get cacheDuration => widget.cacheDuration;
}

abstract class _QueryWidgetState<T> {
  QueryId get id;
  QueryFetcher<T> get fetcher;
  T? get placeholder;
  Duration get staleDuration;
  Duration get cacheDuration;
}
