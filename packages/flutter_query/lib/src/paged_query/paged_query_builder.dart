part of 'paged_query.dart';

typedef PagedQueryBuilderCondition<T> = bool Function(
  PagedQueryState<T> previousState,
  PagedQueryState<T> currentState,
);

typedef PagedQueryWidgetBuilder<T> = Widget Function(
  BuildContext context,
  PagedQueryState<T> state,
  Widget? child,
);

class PagedQueryBuilder<T, P> extends StatefulWidget {
  const PagedQueryBuilder({
    Key? key,
    required this.controller,
    required this.id,
    required this.fetcher,
    required this.initialPageParam,
    this.nextPageParamBuilder,
    this.previousPageParamBuilder,
    this.placeholder,
    this.staleDuration = Duration.zero,
    this.cacheDuration = const Duration(minutes: 5),
    this.refetchOnInit = RefetchBehavior.stale,
    this.refetchOnResumed = RefetchBehavior.stale,
    this.buildWhen,
    required this.builder,
    this.child,
  }) : super(key: key);

  final PagedQueryController<T, P> controller;
  final QueryId id;
  final PagedQueryFetcher<T, P> fetcher;
  final P initialPageParam;
  final PagedQueryParamBuilder<T, P>? nextPageParamBuilder;
  final PagedQueryParamBuilder<T, P>? previousPageParamBuilder;
  final Pages<T>? placeholder;
  final Duration staleDuration;
  final Duration cacheDuration;
  final RefetchBehavior refetchOnInit;
  final RefetchBehavior refetchOnResumed;
  final PagedQueryBuilderCondition<T>? buildWhen;
  final PagedQueryWidgetBuilder<T> builder;
  final Widget? child;

  PagedQueryBuilder<T, P> copyWith({
    PagedQueryController<T, P>? controller,
    QueryId? id,
    PagedQueryFetcher<T, P>? fetcher,
    P? initialPageParam,
    PagedQueryParamBuilder<T, P>? nextPageParamBuilder,
    PagedQueryParamBuilder<T, P>? previousPageParamBuilder,
    Pages<T>? placeholder,
    Duration? staleDuration,
    Duration? cacheDuration,
    RefetchBehavior? refetchOnInit,
    RefetchBehavior? refetchOnResumed,
    PagedQueryBuilderCondition<T>? buildWhen,
    PagedQueryWidgetBuilder<T>? builder,
    Widget? child,
  }) {
    return PagedQueryBuilder<T, P>(
      controller: controller ?? this.controller,
      id: id ?? this.id,
      fetcher: fetcher ?? this.fetcher,
      initialPageParam: initialPageParam ?? this.initialPageParam,
      nextPageParamBuilder: nextPageParamBuilder ?? this.nextPageParamBuilder,
      previousPageParamBuilder:
          previousPageParamBuilder ?? this.previousPageParamBuilder,
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

  PagedQueryBuilder<T, P> copyWithNull({
    bool nextPageParamBuilder = false,
    bool previousPageParamBuilder = false,
    bool placeholder = false,
    bool buildWhen = false,
    bool child = false,
  }) {
    return PagedQueryBuilder<T, P>(
      controller: controller,
      id: id,
      fetcher: fetcher,
      initialPageParam: initialPageParam,
      nextPageParamBuilder:
          nextPageParamBuilder ? null : this.nextPageParamBuilder,
      previousPageParamBuilder:
          previousPageParamBuilder ? null : this.previousPageParamBuilder,
      placeholder: placeholder ? null : this.placeholder,
      staleDuration: staleDuration,
      cacheDuration: cacheDuration,
      refetchOnInit: refetchOnInit,
      refetchOnResumed: refetchOnResumed,
      buildWhen: buildWhen ? null : this.buildWhen,
      builder: builder,
      child: child ? null : this.child,
    );
  }

  @override
  State<PagedQueryBuilder<T, P>> createState() => _PagedQueryBuilder<T, P>();
}

class _PagedQueryBuilder<T, P> extends State<PagedQueryBuilder<T, P>>
    with WidgetsBindingObserver
    implements _PagedQueryWidgetState<T, P> {
  late PagedQuery<T, P> _query;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _query = context
        .read<QueryClient>()
        .cacheStorage
        .buildPagedQuery<T, P>(widget.id);

    if (!_query.state.status.isIdle) {
      refetch(widget.refetchOnInit);
    }

    widget.controller._attach(this);
    _query.addObserver(widget.controller);
  }

  @override
  void dispose() {
    _query.removeObserver(widget.controller);
    widget.controller._detach(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PagedQueryBuilder<T, P> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.controller != oldWidget.controller) {
      _query.removeObserver(oldWidget.controller);
      oldWidget.controller._detach(this);
      widget.controller._attach(this);
      _query.addObserver(widget.controller);
    }

    if (widget.id != oldWidget.id) {
      _query.removeObserver(oldWidget.controller);

      _query = context
          .read<QueryClient>()
          .cacheStorage
          .buildPagedQuery<T, P>(widget.id);

      if (!_query.state.status.isIdle) {
        refetch(widget.refetchOnInit);
      }

      _query.addObserver(widget.controller);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final query = context
        .watch<QueryClient>()
        .cacheStorage
        .buildPagedQuery<T, P>(widget.id);

    if (query != _query) {
      _query.removeObserver(widget.controller);

      _query = query;

      if (!_query.state.status.isIdle) {
        refetch(widget.refetchOnInit);
      }

      _query.addObserver(widget.controller);
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
      fetcher: fetcher,
      initialPageParam: initialPageParam,
      nextPageParamBuilder: nextPageParamBuilder,
      previousPageParamBuilder: previousPageParamBuilder,
      staleDuration: staleDuration,
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
    return ConditionalValueListenableBuilder<PagedQueryState<T>>(
      valueListenable: widget.controller,
      buildWhen: widget.buildWhen,
      builder: widget.builder,
      child: widget.child,
    );
  }

  @override
  QueryId get id => widget.id;

  @override
  PagedQueryFetcher<T, P> get fetcher => widget.fetcher;

  @override
  P get initialPageParam => widget.initialPageParam;

  @override
  PagedQueryParamBuilder<T, P>? get nextPageParamBuilder =>
      widget.nextPageParamBuilder;

  @override
  PagedQueryParamBuilder<T, P>? get previousPageParamBuilder =>
      widget.previousPageParamBuilder;
  @override
  Pages<T>? get placeholder => widget.placeholder;

  @override
  Duration get staleDuration => widget.staleDuration;

  @override
  Duration get cacheDuration => widget.cacheDuration;
}

abstract class _PagedQueryWidgetState<T, P> {
  QueryId get id;
  PagedQueryFetcher<T, P> get fetcher;
  P get initialPageParam;
  PagedQueryParamBuilder<T, P>? get nextPageParamBuilder;
  PagedQueryParamBuilder<T, P>? get previousPageParamBuilder;
  Pages<T>? get placeholder;
  Duration get staleDuration;
  Duration get cacheDuration;
}
