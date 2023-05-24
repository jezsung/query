part of 'paged_query.dart';

class PagedQueryBuilder<T, P> extends StatefulWidget {
  const PagedQueryBuilder({
    super.key,
    this.controller,
    required this.id,
    required this.fetcher,
    this.nextPageParamBuilder,
    this.previousPageParamBuilder,
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
    required this.builder,
    this.child,
  });

  final PagedQueryController<T, P>? controller;
  final QueryIdentifier id;
  final PagedQueryFetcher<T, P> fetcher;
  final PagedQueryParamBuilder<T, P>? nextPageParamBuilder;
  final PagedQueryParamBuilder<T, P>? previousPageParamBuilder;
  final bool enabled;
  final Pages<T>? initialData;
  final DateTime? initialDataUpdatedAt;
  final Pages<T>? placeholder;
  final Duration staleDuration;
  final Duration cacheDuration;
  final RetryCondition? retryWhen;
  final int retryMaxAttempts;
  final Duration retryMaxDelay;
  final Duration retryDelayFactor;
  final double retryRandomizationFactor;
  final RefetchMode refetchOnInit;
  final RefetchMode refetchOnResumed;
  final PagedQueryWidgetBuilder<T, P> builder;
  final Widget? child;

  @override
  State<PagedQueryBuilder<T, P>> createState() =>
      _PagedQueryBuilderState<T, P>();
}

class _PagedQueryBuilderState<T, P> extends State<PagedQueryBuilder<T, P>>
    with WidgetsBindingObserver, _PagedQueryWidgetState {
  late PagedQuery<T, P> _query;
  late final PagedQueryObserver<T, P> _observer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller?._attach(this);

    _query = context.read<QueryClient>().cache.buildPagedQuery<T, P>(widget.id);

    _observer = PagedQueryObserver<T, P>(
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
    );

    if (widget.initialData != null) {
      _query.setInitialData(
        widget.initialData!,
        widget.nextPageParamBuilder,
        widget.previousPageParamBuilder,
        widget.initialDataUpdatedAt,
      );
    }

    _observer.bind(_query);

    if (_query.state.status.isIdle) {
      fetch();
    } else {
      refetch(widget.refetchOnInit);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final query =
        context.watch<QueryClient>().cache.buildPagedQuery<T, P>(widget.id);

    if (query != _query) {
      _observer.unbind();

      _query = query;

      if (widget.initialData != null) {
        query.setInitialData(
          widget.initialData!,
          widget.nextPageParamBuilder,
          widget.previousPageParamBuilder,
          widget.initialDataUpdatedAt,
        );
      }

      _observer.bind(_query);

      if (query.state.status.isIdle) {
        fetch();
      } else {
        refetch(widget.refetchOnInit);
      }
    }
  }

  @override
  void didUpdateWidget(covariant PagedQueryBuilder<T, P> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }

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
      ..retryRandomizationFactor = widget.retryRandomizationFactor;

    if (widget.id != oldWidget.id) {
      final query =
          context.read<QueryClient>().cache.buildPagedQuery<T, P>(widget.id);

      _query = query;

      if (widget.initialData != null) {
        query.setInitialData(
          widget.initialData!,
          widget.nextPageParamBuilder,
          widget.previousPageParamBuilder,
          widget.initialDataUpdatedAt,
        );
      }

      _observer.bind(query);

      if (query.state.status.isIdle) {
        fetch();
      } else {
        refetch(widget.refetchOnInit);
      }

      return;
    }

    if (widget.enabled && !oldWidget.enabled) {
      if (_query.state.status.isIdle) {
        fetch();
      } else {
        refetch(widget.refetchOnInit);
      }

      return;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refetch(widget.refetchOnResumed);
    }
  }

  @override
  Future fetch({bool ignoreStaleness = false}) async {
    await _query.fetch(
      fetcher: widget.fetcher,
      nextPageParamBuilder: widget.nextPageParamBuilder,
      previousPageParamBuilder: widget.previousPageParamBuilder,
      staleDuration: ignoreStaleness ? Duration.zero : widget.staleDuration,
      retryWhen: widget.retryWhen,
      retryMaxAttempts: widget.retryMaxAttempts,
      retryMaxDelay: widget.retryMaxDelay,
      retryDelayFactor: widget.retryDelayFactor,
      retryRandomizationFactor: widget.retryRandomizationFactor,
    );
  }

  @override
  Future fetchNextPage() async {
    await _query.fetchNextPage(
      fetcher: widget.fetcher,
      nextPageParamBuilder: widget.nextPageParamBuilder,
      previousPageParamBuilder: widget.previousPageParamBuilder,
      retryWhen: widget.retryWhen,
      retryMaxAttempts: widget.retryMaxAttempts,
      retryMaxDelay: widget.retryMaxDelay,
      retryDelayFactor: widget.retryDelayFactor,
      retryRandomizationFactor: widget.retryRandomizationFactor,
    );
  }

  @override
  Future fetchPreviousPage() async {
    await _query.fetchPreviousPage(
      fetcher: widget.fetcher,
      nextPageParamBuilder: widget.nextPageParamBuilder,
      previousPageParamBuilder: widget.previousPageParamBuilder,
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
    return ConditionalValueListenableBuilder<PagedQueryState<T, P>>(
      valueListenable: _observer,
      builder: (context, value, child) {
        return widget.builder(context, value, child);
      },
      child: widget.child,
    );
  }
}
