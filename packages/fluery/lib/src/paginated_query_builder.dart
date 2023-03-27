import 'package:fluery/src/base_query.dart';
import 'package:fluery/src/query_client_provider.dart';
import 'package:fluery/src/query_manager.dart';
import 'package:flutter/widgets.dart';

typedef Pages<Data> = List<Data>;

typedef PaginatedQueryFetcher<Data, Params> = Future<Data> Function(
  QueryIdentifier id,
  Params? params,
);

typedef PaginatedQueryParamsBuilder<Data, Params> = Params? Function(
  Pages<Data> pages,
);

typedef PaginatedQueryWidgetBuilder<Data> = Widget Function(
  BuildContext context,
  PaginatedQueryState<Data> state,
  Widget? child,
);

class PaginatedQueryState<Data> extends BaseQueryState {
  const PaginatedQueryState({
    QueryStatus status = QueryStatus.idle,
    this.pages = const [],
    this.hasNextPage = true,
    this.hasPreviousPage = false,
    this.error,
    this.pagesUpdatedAt,
    this.errorUpdatedAt,
  }) : super(status);

  final Pages<Data> pages;
  final bool hasNextPage;
  final bool hasPreviousPage;
  final Object? error;
  final DateTime? pagesUpdatedAt;
  final DateTime? errorUpdatedAt;

  PaginatedQueryState<Data> copyWith({
    QueryStatus? status,
    Pages<Data>? pages,
    bool? hasNextPage,
    bool? hasPreviousPage,
    Object? error,
    DateTime? pagesUpdatedAt,
    DateTime? errorUpdatedAt,
  }) {
    return PaginatedQueryState<Data>(
      status: status ?? this.status,
      pages: pages ?? this.pages,
      hasNextPage: hasNextPage ?? this.hasNextPage,
      hasPreviousPage: hasPreviousPage ?? this.hasPreviousPage,
      error: error ?? this.error,
      pagesUpdatedAt: pagesUpdatedAt ?? this.pagesUpdatedAt,
      errorUpdatedAt: errorUpdatedAt ?? this.errorUpdatedAt,
    );
  }

  factory PaginatedQueryState.fromJson(Map<String, dynamic> json) {
    // Not implemented yet.
    return PaginatedQueryState<Data>();
  }

  @override
  List<Object?> get props =>
      super.props +
      [
        pages,
        hasNextPage,
        hasPreviousPage,
        error,
        pagesUpdatedAt,
        errorUpdatedAt,
      ];
}

class PaginatedQuery<Data, Params> extends BaseQuery {
  PaginatedQuery({
    required QueryIdentifier id,
    PaginatedQueryState<Data>? initialState,
  }) : super(id) {
    state = initialState ?? PaginatedQueryState<Data>();
  }

  late PaginatedQueryState<Data> state;

  bool isFetching = false;

  Set<PaginatedQueryController<Data, Params>> get controllers =>
      observers.whereType<PaginatedQueryController<Data, Params>>().toSet();

  Future<void> fetch({
    required PaginatedQueryFetcher<Data, Params> fetcher,
    required PaginatedQueryParamsBuilder<Data, Params>? nextPageParamsBuilder,
    required PaginatedQueryParamsBuilder<Data, Params>?
        previousPageParamsBuilder,
    required Duration staleDuration,
  }) async {
    if (controllers.isEmpty) {
      return;
    }

    if (isFetching) {
      return;
    } else {
      isFetching = true;
    }

    Future<void> execute() async {
      final isDataStale = state.pagesUpdatedAt
              ?.isBefore(DateTime.now().subtract(staleDuration)) ??
          false;
      if (isDataStale) {
        return;
      }

      notify(QueryStateUpdated(
        state = state.copyWith(
          status: QueryStatus.loading,
        ),
      ));

      try {
        final data = await fetcher(id, null);
        final pages = [data];

        notify(QueryStateUpdated(
          state = state.copyWith(
            status: QueryStatus.success,
            pages: pages,
            hasNextPage: nextPageParamsBuilder?.call(pages) != null,
            hasPreviousPage: previousPageParamsBuilder?.call(pages) != null,
            pagesUpdatedAt: DateTime.now(),
          ),
        ));
      } catch (e) {
        notify(QueryStateUpdated(
          state = state.copyWith(
            status: QueryStatus.failure,
            error: e,
            errorUpdatedAt: DateTime.now(),
          ),
        ));
      }
    }

    try {
      await execute();
    } catch (error) {
      rethrow;
    } finally {
      isFetching = false;
    }
  }

  Future<void> fetchNextPage({
    required PaginatedQueryFetcher<Data, Params> fetcher,
    required PaginatedQueryParamsBuilder<Data, Params>? nextPageParamsBuilder,
  }) async {
    if (controllers.isEmpty) {
      return;
    }
    if (!state.hasNextPage) {
      return;
    }

    if (isFetching) {
      return;
    } else {
      isFetching = true;
    }

    Future<void> execute() async {
      notify(QueryStateUpdated(
        state = state.copyWith(
          status: QueryStatus.loading,
        ),
      ));

      try {
        final params = nextPageParamsBuilder?.call(state.pages);
        final data = await fetcher(id, params);
        final pages = [...state.pages, data];

        notify(QueryStateUpdated(
          state = state.copyWith(
            status: QueryStatus.success,
            pages: pages,
            hasNextPage: nextPageParamsBuilder?.call(pages) != null,
            pagesUpdatedAt: DateTime.now(),
          ),
        ));
      } catch (e) {
        notify(QueryStateUpdated(
          state = state.copyWith(
            status: QueryStatus.failure,
            error: e,
            errorUpdatedAt: DateTime.now(),
          ),
        ));
      }
    }

    try {
      await execute();
    } catch (error) {
      rethrow;
    } finally {
      isFetching = false;
    }
  }

  Future<void> fetchPreviousPage({
    required PaginatedQueryFetcher<Data, Params> fetcher,
    required PaginatedQueryParamsBuilder<Data, Params>?
        previousPageParamsBuilder,
  }) async {
    if (controllers.isEmpty) {
      return;
    }
    if (!state.hasPreviousPage) {
      return;
    }

    if (isFetching) {
      return;
    } else {
      isFetching = true;
    }

    Future<void> execute() async {
      notify(QueryStateUpdated(
        state = state.copyWith(
          status: QueryStatus.loading,
        ),
      ));

      try {
        final params = previousPageParamsBuilder?.call(state.pages);
        final data = await fetcher(id, params);
        final pages = [data, ...state.pages];

        notify(QueryStateUpdated(
          state = state.copyWith(
            status: QueryStatus.success,
            pages: pages,
            hasPreviousPage: previousPageParamsBuilder?.call(pages) != null,
            pagesUpdatedAt: DateTime.now(),
          ),
        ));
      } catch (e) {
        notify(QueryStateUpdated(
          state = state.copyWith(
            status: QueryStatus.failure,
            error: e,
            errorUpdatedAt: DateTime.now(),
          ),
        ));
      }
    }

    try {
      await execute();
    } catch (error) {
      rethrow;
    } finally {
      isFetching = false;
    }
  }
}

class PaginatedQueryController<Data, Params>
    extends ValueNotifier<PaginatedQueryState<Data>>
    with BaseQueryObserver<PaginatedQuery<Data, Params>> {
  PaginatedQueryController() : super(PaginatedQueryState<Data>());

  PaginatedQuery<Data, Params>? _query;

  late QueryIdentifier _id;
  late PaginatedQueryFetcher<Data, Params> _fetcher;
  late PaginatedQueryParamsBuilder<Data, Params>? _nextPageParamsBuilder;
  late PaginatedQueryParamsBuilder<Data, Params>? _previousPageParamsBuilder;
  late Duration _staleDuration;

  QueryIdentifier get id => _id;
  PaginatedQueryFetcher<Data, Params> get fetcher => _fetcher;
  PaginatedQueryParamsBuilder<Data, Params>? get nextPageParamsBuilder =>
      _nextPageParamsBuilder;
  PaginatedQueryParamsBuilder<Data, Params>? get previousPageParamsBuilder =>
      _previousPageParamsBuilder;
  Duration get staleDuration => _staleDuration;

  Future<void> fetch() async {
    await _query?.fetch(
      fetcher: fetcher,
      nextPageParamsBuilder: nextPageParamsBuilder,
      previousPageParamsBuilder: previousPageParamsBuilder,
      staleDuration: staleDuration,
    );
  }

  Future<void> fetchNextPage() async {
    await _query?.fetchNextPage(
      fetcher: fetcher,
      nextPageParamsBuilder: nextPageParamsBuilder,
    );
  }

  Future<void> fetchPreviousPage() async {
    await _query?.fetchPreviousPage(
      fetcher: fetcher,
      previousPageParamsBuilder: previousPageParamsBuilder,
    );
  }

  @override
  void onNotified(PaginatedQuery<Data, Params> query, BaseQueryEvent event) {
    if (event is QueryStateUpdated<PaginatedQueryState<Data>>) {
      value = event.state;
    } else if (event
        is QueryObserverAdded<PaginatedQueryController<Data, Params>>) {
      if (event.observer == this) {
        _query = query;
        value = query.state;
      }
    } else if (event
        is QueryObserverRemoved<PaginatedQueryController<Data, Params>>) {
      if (event.observer == this) {
        _query = null;
      }
    }
  }
}

class PaginatedQueryBuilder<Data, Params> extends StatefulWidget {
  const PaginatedQueryBuilder({
    super.key,
    this.controller,
    required this.id,
    required this.fetcher,
    this.nextPageParamsBuilder,
    this.previousPageParamsBuilder,
    this.staleDuration = Duration.zero,
    required this.builder,
    this.child,
  });

  final PaginatedQueryController<Data, Params>? controller;
  final QueryIdentifier id;
  final PaginatedQueryFetcher<Data, Params> fetcher;
  final PaginatedQueryParamsBuilder<Data, Params>? nextPageParamsBuilder;
  final PaginatedQueryParamsBuilder<Data, Params>? previousPageParamsBuilder;
  final Duration staleDuration;
  final PaginatedQueryWidgetBuilder builder;
  final Widget? child;

  @override
  State<PaginatedQueryBuilder<Data, Params>> createState() =>
      _PaginatedQueryBuilderState<Data, Params>();
}

class _PaginatedQueryBuilderState<Data, Params>
    extends State<PaginatedQueryBuilder<Data, Params>> {
  final PaginatedQueryController<Data, Params> __controller =
      PaginatedQueryController<Data, Params>();

  late QueryManager _queryManager;

  PaginatedQueryController<Data, Params> get _controller =>
      widget.controller ?? __controller;

  @override
  void initState() {
    super.initState();
    _controller._id = widget.id;
    _controller._fetcher = widget.fetcher;
    _controller._nextPageParamsBuilder = widget.nextPageParamsBuilder;
    _controller._previousPageParamsBuilder = widget.previousPageParamsBuilder;
    _controller._staleDuration = widget.staleDuration;

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      await _controller.fetch();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _queryManager = QueryClientProvider.of(context).manager;
    _queryManager.addControllerToPaginatedQuery(_controller.id, _controller);
  }

  @override
  void didUpdateWidget(
      covariant PaginatedQueryBuilder<Data, Params> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller._id = widget.id;
    _controller._fetcher = widget.fetcher;
    _controller._nextPageParamsBuilder = widget.nextPageParamsBuilder;
    _controller._previousPageParamsBuilder = widget.previousPageParamsBuilder;
    _controller._staleDuration = widget.staleDuration;

    if (widget.controller != oldWidget.controller ||
        widget.id != oldWidget.id) {
      _queryManager.removeControllerFromPaginatedQuery(
        oldWidget.id,
        _controller,
      );
      _queryManager.addControllerToPaginatedQuery(widget.id, _controller);
    }

    if (widget.id != oldWidget.id ||
        widget.staleDuration != oldWidget.staleDuration) {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
        await _controller.fetch();
      });
    }
  }

  @override
  void dispose() {
    _queryManager.removeControllerFromPaginatedQuery(
      _controller.id,
      _controller,
    );
    __controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PaginatedQueryState<Data>>(
      valueListenable: _controller,
      builder: (context, value, child) {
        return widget.builder(context, value, child);
      },
      child: widget.child,
    );
  }
}
