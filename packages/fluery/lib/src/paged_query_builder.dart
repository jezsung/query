import 'package:equatable/equatable.dart';
import 'package:fluery/fluery.dart';
import 'package:fluery/src/base_query.dart';
import 'package:fluery/src/query_client_provider.dart';
import 'package:flutter/widgets.dart';

typedef Pages<Data> = List<Data>;

typedef PagedQueryFetcher<Data, Params> = Future<Data> Function(
  QueryIdentifier id,
  Params? params,
);

typedef PagedQueryParamsBuilder<Data, Params> = Params? Function(
  Pages<Data> pages,
);

typedef PagedQueryWidgetBuilder<Data> = Widget Function(
  BuildContext context,
  PagedQueryState<Data> state,
  Widget? child,
);

class PagedQueryState<Data> extends BaseQueryState {
  const PagedQueryState({
    this.status = QueryStatus.idle,
    this.pages = const [],
    this.isFetchingNextPage = false,
    this.isFetchingPreviousPage = false,
    this.hasNextPage = true,
    this.hasPreviousPage = false,
    this.error,
    this.dataUpdatedAt,
    this.errorUpdatedAt,
  });

  final QueryStatus status;
  final Pages<Data> pages;
  final bool isFetchingNextPage;
  final bool isFetchingPreviousPage;
  final bool hasNextPage;
  final bool hasPreviousPage;
  final Object? error;
  final DateTime? dataUpdatedAt;
  final DateTime? errorUpdatedAt;

  bool get hasData => pages.isNotEmpty;

  bool get hasError => error != null;

  PagedQueryState<Data> copyWith({
    QueryStatus? status,
    Pages<Data>? pages,
    bool? isFetchingNextPage,
    bool? isFetchingPreviousPage,
    bool? hasNextPage,
    bool? hasPreviousPage,
    Object? error,
    DateTime? dataUpdatedAt,
    DateTime? errorUpdatedAt,
  }) {
    return PagedQueryState<Data>(
      status: status ?? this.status,
      pages: pages ?? this.pages,
      isFetchingNextPage: isFetchingNextPage ?? this.isFetchingNextPage,
      isFetchingPreviousPage:
          isFetchingPreviousPage ?? this.isFetchingPreviousPage,
      hasNextPage: hasNextPage ?? this.hasNextPage,
      hasPreviousPage: hasPreviousPage ?? this.hasPreviousPage,
      error: error ?? this.error,
      dataUpdatedAt: dataUpdatedAt ?? this.dataUpdatedAt,
      errorUpdatedAt: errorUpdatedAt ?? this.errorUpdatedAt,
    );
  }

  factory PagedQueryState.fromJson(Map<String, dynamic> json) {
    // Not implemented yet.
    return PagedQueryState<Data>();
  }

  @override
  List<Object?> get props => [
        status,
        pages,
        isFetchingNextPage,
        isFetchingPreviousPage,
        hasNextPage,
        hasPreviousPage,
        error,
        dataUpdatedAt,
        errorUpdatedAt,
      ];
}

class PagedQuery<Data, Params> extends BaseQuery {
  PagedQuery({
    required QueryIdentifier id,
    PagedQueryState<Data>? initialState,
  }) : super(id) {
    state = initialState ?? PagedQueryState<Data>();
  }

  late PagedQueryState<Data> state;

  bool isFetching = false;

  Set<PagedQueryController<Data, Params>> get controllers =>
      observers.whereType<PagedQueryController<Data, Params>>().toSet();

  Future<void> fetch({
    required PagedQueryFetcher<Data, Params> fetcher,
    required PagedQueryParamsBuilder<Data, Params>? nextPageParamsBuilder,
    required PagedQueryParamsBuilder<Data, Params>? previousPageParamsBuilder,
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
      final isDataStale = state.dataUpdatedAt
              ?.isBefore(DateTime.now().subtract(staleDuration)) ??
          true;
      if (!isDataStale) {
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
            dataUpdatedAt: DateTime.now(),
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
    required PagedQueryFetcher<Data, Params> fetcher,
    required PagedQueryParamsBuilder<Data, Params>? nextPageParamsBuilder,
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
          isFetchingNextPage: true,
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
            isFetchingNextPage: false,
            hasNextPage: nextPageParamsBuilder?.call(pages) != null,
            dataUpdatedAt: DateTime.now(),
          ),
        ));
      } catch (e) {
        notify(QueryStateUpdated(
          state = state.copyWith(
            status: QueryStatus.failure,
            isFetchingNextPage: false,
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
    required PagedQueryFetcher<Data, Params> fetcher,
    required PagedQueryParamsBuilder<Data, Params>? previousPageParamsBuilder,
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
          isFetchingPreviousPage: true,
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
            isFetchingPreviousPage: false,
            hasPreviousPage: previousPageParamsBuilder?.call(pages) != null,
            dataUpdatedAt: DateTime.now(),
          ),
        ));
      } catch (e) {
        notify(QueryStateUpdated(
          state = state.copyWith(
            status: QueryStatus.failure,
            isFetchingPreviousPage: false,
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

  void setInitialData({
    required Pages<Data> pages,
    PagedQueryParamsBuilder<Data, Params>? nextPageParamsBuilder,
    PagedQueryParamsBuilder<Data, Params>? previousPageParamsBuilder,
    DateTime? updatedAt,
  }) {
    final isDataUpToDate = updatedAt != null &&
        state.dataUpdatedAt != null &&
        updatedAt.isAfter(state.dataUpdatedAt!);

    if (!state.hasData || isDataUpToDate) {
      notify(QueryStateUpdated(
        state = state.copyWith(
          status: QueryStatus.success,
          pages: pages,
          hasNextPage: nextPageParamsBuilder?.call(pages) != null,
          hasPreviousPage: previousPageParamsBuilder?.call(pages) != null,
          dataUpdatedAt: updatedAt ?? DateTime.now(),
        ),
      ));
    }
  }
}

class PagedQueryController<Data, Params>
    extends ValueNotifier<PagedQueryState<Data>>
    with BaseQueryObserver<PagedQuery<Data, Params>> {
  PagedQueryController() : super(PagedQueryState<Data>());

  PagedQuery<Data, Params>? _query;

  late QueryIdentifier _id;
  late PagedQueryFetcher<Data, Params> _fetcher;
  late PagedQueryParamsBuilder<Data, Params>? _nextPageParamsBuilder;
  late PagedQueryParamsBuilder<Data, Params>? _previousPageParamsBuilder;
  late Duration _staleDuration;

  QueryIdentifier get id => _id;
  PagedQueryFetcher<Data, Params> get fetcher => _fetcher;
  PagedQueryParamsBuilder<Data, Params>? get nextPageParamsBuilder =>
      _nextPageParamsBuilder;
  PagedQueryParamsBuilder<Data, Params>? get previousPageParamsBuilder =>
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
  void onNotified(PagedQuery<Data, Params> query, BaseQueryEvent event) {
    if (event is QueryStateUpdated<PagedQueryState<Data>>) {
      value = event.state;
    } else if (event
        is QueryObserverAdded<PagedQueryController<Data, Params>>) {
      if (event.observer == this) {
        _query = query;
        value = query.state;
      }
    } else if (event
        is QueryObserverRemoved<PagedQueryController<Data, Params>>) {
      if (event.observer == this) {
        _query = null;
      }
    }
  }
}

class PagedQueryBuilder<Data, Params> extends StatefulWidget {
  const PagedQueryBuilder({
    super.key,
    this.controller,
    required this.id,
    required this.fetcher,
    this.nextPageParamsBuilder,
    this.previousPageParamsBuilder,
    this.initialData,
    this.initialDataUpdatedAt,
    this.staleDuration = Duration.zero,
    required this.builder,
    this.child,
  });

  final PagedQueryController<Data, Params>? controller;
  final QueryIdentifier id;
  final PagedQueryFetcher<Data, Params> fetcher;
  final PagedQueryParamsBuilder<Data, Params>? nextPageParamsBuilder;
  final PagedQueryParamsBuilder<Data, Params>? previousPageParamsBuilder;
  final Pages<Data>? initialData;
  final DateTime? initialDataUpdatedAt;
  final Duration staleDuration;
  final PagedQueryWidgetBuilder builder;
  final Widget? child;

  @override
  State<PagedQueryBuilder<Data, Params>> createState() =>
      _PagedQueryBuilderState<Data, Params>();
}

class _PagedQueryBuilderState<Data, Params>
    extends State<PagedQueryBuilder<Data, Params>> {
  final PagedQueryController<Data, Params> _controller =
      PagedQueryController<Data, Params>();

  late PagedQuery<Data, Params> _query;

  PagedQueryController<Data, Params> get _effectiveController =>
      widget.controller ?? _controller;

  @override
  void initState() {
    super.initState();
    _effectiveController._id = widget.id;
    _effectiveController._fetcher = widget.fetcher;
    _effectiveController._nextPageParamsBuilder = widget.nextPageParamsBuilder;
    _effectiveController._previousPageParamsBuilder =
        widget.previousPageParamsBuilder;
    _effectiveController._staleDuration = widget.staleDuration;

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      await _effectiveController.fetch();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _query = QueryClientProvider.of(context)
        .manager
        .buildPagedQuery(_effectiveController.id);

    _query.addObserver(_effectiveController);

    if (widget.initialData != null) {
      _query.setInitialData(
        pages: widget.initialData!,
        nextPageParamsBuilder: _effectiveController.nextPageParamsBuilder,
        previousPageParamsBuilder:
            _effectiveController.previousPageParamsBuilder,
        updatedAt: widget.initialDataUpdatedAt,
      );
    }
  }

  @override
  void didUpdateWidget(covariant PagedQueryBuilder<Data, Params> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != null && widget.controller == null) {
      _query.removeObserver<PagedQueryController<Data, Params>>(
        oldWidget.controller!,
      );
    } else if (oldWidget.controller == null && widget.controller != null) {
      _query.removeObserver<PagedQueryController<Data, Params>>(
        _controller,
      );
    } else if (oldWidget.controller != widget.controller) {
      _query.removeObserver<PagedQueryController<Data, Params>>(
        oldWidget.controller!,
      );
    }

    _effectiveController._id = widget.id;
    _effectiveController._fetcher = widget.fetcher;
    _effectiveController._nextPageParamsBuilder = widget.nextPageParamsBuilder;
    _effectiveController._previousPageParamsBuilder =
        widget.previousPageParamsBuilder;
    _effectiveController._staleDuration = widget.staleDuration;

    if (oldWidget.controller != null && widget.controller == null) {
      _query.addObserver<PagedQueryController<Data, Params>>(
        _controller,
      );
    } else if (oldWidget.controller == null && widget.controller != null) {
      _query.addObserver<PagedQueryController<Data, Params>>(
        widget.controller!,
      );
    } else if (oldWidget.controller != widget.controller) {
      _query.addObserver<PagedQueryController<Data, Params>>(
        widget.controller!,
      );
    }

    if (widget.id != oldWidget.id ||
        widget.staleDuration != oldWidget.staleDuration) {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
        await _effectiveController.fetch();
      });
    }
  }

  @override
  void dispose() {
    _query.removeObserver<PagedQueryController<Data, Params>>(
      _effectiveController,
    );
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PagedQueryState<Data>>(
      valueListenable: _effectiveController,
      builder: (context, value, child) {
        return widget.builder(context, value, child);
      },
      child: widget.child,
    );
  }
}
