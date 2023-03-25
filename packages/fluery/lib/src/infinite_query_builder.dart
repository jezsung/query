import 'package:equatable/equatable.dart';
import 'package:fluery/src/base_query.dart';
import 'package:fluery/src/query_builder.dart';
import 'package:fluery/src/query_cache_storage.dart';
import 'package:fluery/src/query_client_provider.dart';
import 'package:fluery/src/query_manager.dart';
import 'package:flutter/widgets.dart';

typedef Pages<Data> = List<Data>;

typedef InfiniteQueryFetcher<Data, Params> = Future<Data> Function(
  QueryIdentifier id,
  Params? params,
);

typedef InfiniteQueryParamsBuilder<Data, Params> = Params? Function(
  Pages<Data> pages,
);

typedef InfiniteQueryWidgetBuilder<Data> = Widget Function(
  BuildContext context,
  InfiniteQueryState<Data> state,
  Widget? child,
);

class InfiniteQueryState<Data> extends BaseQueryState {
  const InfiniteQueryState({
    QueryStatus status = QueryStatus.idle,
    this.pages = const [],
    this.hasNextPage = true,
    this.hasPreviousPage = false,
    Object? error,
  }) : super(
          status: status,
          error: error,
        );

  final Pages<Data> pages;
  final bool hasNextPage;
  final bool hasPreviousPage;

  InfiniteQueryState<Data> copyWith({
    QueryStatus? status,
    Pages<Data>? pages,
    bool? hasNextPage,
    bool? hasPreviousPage,
    Object? error,
  }) {
    return InfiniteQueryState<Data>(
      status: status ?? this.status,
      pages: pages ?? this.pages,
      hasNextPage: hasNextPage ?? this.hasNextPage,
      hasPreviousPage: hasPreviousPage ?? this.hasPreviousPage,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props =>
      super.props +
      [
        pages,
        hasNextPage,
        hasPreviousPage,
      ];
}

class InfiniteQuery<Data, Params> extends BaseQuery<InfiniteQuery<Data, Params>,
    InfiniteQueryController<Data, Params>, InfiniteQueryState<Data>> {
  InfiniteQuery({
    required QueryIdentifier id,
    required QueryCacheStorage cacheStorage,
  }) : super(id: id, cacheStorage: cacheStorage) {
    state = InfiniteQueryState<Data>();
  }

  bool isFetching = false;

  @override
  Future<void> fetch({
    InfiniteQueryFetcher<Data, Params>? fetcher,
    InfiniteQueryParamsBuilder<Data, Params>? nextPageParamsBuilder,
    InfiniteQueryParamsBuilder<Data, Params>? previousPageParamsBuilder,
    Duration? staleDuration,
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
      final effectiveFetcher = fetcher ?? controllers.first.fetcher;
      final effectiveStaleDuration = staleDuration ??
          controllers.fold<Duration>(
            controllers.first.staleDuration,
            (duration, controller) => controller.staleDuration < duration
                ? controller.staleDuration
                : duration,
          );

      final cacheState = cacheStorage.get<Pages<Data>>(id);
      final shouldFetch = cacheState?.isStale(effectiveStaleDuration) ?? true;
      if (!shouldFetch) {
        final pages = cacheState!.data;

        notify(state = state.copyWith(
          status: QueryStatus.success,
          pages: pages,
          hasNextPage: nextPageParamsBuilder?.call(pages) != null,
          hasPreviousPage: previousPageParamsBuilder?.call(pages) != null,
        ));
        return;
      }

      notify(state = state.copyWith(status: QueryStatus.loading));

      try {
        final data = await effectiveFetcher(id, null);
        final pages = [data];

        cacheStorage.set<Pages<Data>>(id, pages);

        notify(state = state.copyWith(
          status: QueryStatus.success,
          pages: pages,
          hasNextPage: nextPageParamsBuilder?.call(pages) != null,
          hasPreviousPage: previousPageParamsBuilder?.call(pages) != null,
        ));
      } catch (e) {
        notify(state = state.copyWith(
          status: QueryStatus.failure,
          error: e,
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
    InfiniteQueryFetcher<Data, Params>? fetcher,
    InfiniteQueryParamsBuilder<Data, Params>? nextPageParamsBuilder,
    InfiniteQueryParamsBuilder<Data, Params>? previousPageParamsBuilder,
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
      final effectiveFetcher = fetcher ?? controllers.first.fetcher;

      notify(state = state.copyWith(status: QueryStatus.loading));

      try {
        final params = nextPageParamsBuilder?.call(state.pages);
        final data = await effectiveFetcher(id, params);
        final pages = [...state.pages, data];

        cacheStorage.set<Pages<Data>>(id, pages);

        notify(state = state.copyWith(
          status: QueryStatus.success,
          pages: pages,
          hasNextPage: nextPageParamsBuilder?.call(pages) != null,
          hasPreviousPage: previousPageParamsBuilder?.call(pages) != null,
        ));
      } catch (e) {
        notify(state = state.copyWith(
          status: QueryStatus.failure,
          error: e,
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
    InfiniteQueryFetcher<Data, Params>? fetcher,
    InfiniteQueryParamsBuilder<Data, Params>? nextPageParamsBuilder,
    InfiniteQueryParamsBuilder<Data, Params>? previousPageParamsBuilder,
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
      final effectiveFetcher = fetcher ?? controllers.first.fetcher;

      notify(state = state.copyWith(status: QueryStatus.loading));

      try {
        final params = previousPageParamsBuilder?.call(state.pages);
        final data = await effectiveFetcher(id, params);
        final pages = [data, ...state.pages];

        cacheStorage.set<Pages<Data>>(id, pages);

        notify(state = state.copyWith(
          status: QueryStatus.success,
          pages: pages,
          hasNextPage: nextPageParamsBuilder?.call(pages) != null,
          hasPreviousPage: previousPageParamsBuilder?.call(pages) != null,
        ));
      } catch (e) {
        notify(state = state.copyWith(
          status: QueryStatus.failure,
          error: e,
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

class InfiniteQueryController<Data, Params> extends BaseQueryController<
    InfiniteQuery<Data, Params>,
    InfiniteQueryController<Data, Params>,
    InfiniteQueryState<Data>> {
  InfiniteQueryController() : super(InfiniteQueryState<Data>());

  late QueryIdentifier _id;
  late InfiniteQueryFetcher<Data, Params> _fetcher;
  late InfiniteQueryParamsBuilder<Data, Params>? _nextPageParamsBuilder;
  late InfiniteQueryParamsBuilder<Data, Params>? _previousPageParamsBuilder;
  late Duration _staleDuration;

  QueryIdentifier get id => _id;
  InfiniteQueryFetcher<Data, Params> get fetcher => _fetcher;
  InfiniteQueryParamsBuilder<Data, Params>? get nextPageParamsBuilder =>
      _nextPageParamsBuilder;
  InfiniteQueryParamsBuilder<Data, Params>? get previousPageParamsBuilder =>
      _previousPageParamsBuilder;
  Duration get staleDuration => _staleDuration;

  Future<void> fetch() async {
    query.fetch(
      fetcher: fetcher,
      nextPageParamsBuilder: nextPageParamsBuilder,
      previousPageParamsBuilder: previousPageParamsBuilder,
      staleDuration: staleDuration,
    );
  }

  Future<void> fetchNextPage() async {
    query.fetchNextPage(
      fetcher: fetcher,
      nextPageParamsBuilder: nextPageParamsBuilder,
      previousPageParamsBuilder: previousPageParamsBuilder,
    );
  }

  Future<void> fetchPreviousPage() async {
    query.fetchPreviousPage(
      fetcher: fetcher,
      nextPageParamsBuilder: nextPageParamsBuilder,
      previousPageParamsBuilder: previousPageParamsBuilder,
    );
  }
}

class InfiniteQueryBuilder<Data, Params> extends StatefulWidget {
  const InfiniteQueryBuilder({
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

  final InfiniteQueryController<Data, Params>? controller;
  final QueryIdentifier id;
  final InfiniteQueryFetcher<Data, Params> fetcher;
  final InfiniteQueryParamsBuilder<Data, Params>? nextPageParamsBuilder;
  final InfiniteQueryParamsBuilder<Data, Params>? previousPageParamsBuilder;
  final Duration staleDuration;
  final InfiniteQueryWidgetBuilder builder;
  final Widget? child;

  @override
  State<InfiniteQueryBuilder<Data, Params>> createState() =>
      _InfiniteQueryBuilderState<Data, Params>();
}

class _InfiniteQueryBuilderState<Data, Params>
    extends State<InfiniteQueryBuilder<Data, Params>> {
  final InfiniteQueryController<Data, Params> __controller =
      InfiniteQueryController<Data, Params>();

  late QueryManager _queryManager;

  InfiniteQueryController<Data, Params> get _controller =>
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
    _queryManager.subscribeToInfiniteQuery(_controller.id, _controller);
  }

  @override
  void didUpdateWidget(covariant InfiniteQueryBuilder<Data, Params> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller._id = widget.id;
    _controller._fetcher = widget.fetcher;
    _controller._nextPageParamsBuilder = widget.nextPageParamsBuilder;
    _controller._previousPageParamsBuilder = widget.previousPageParamsBuilder;
    _controller._staleDuration = widget.staleDuration;

    if (widget.controller != oldWidget.controller ||
        widget.id != oldWidget.id) {
      _queryManager.unsubscribe(oldWidget.id, _controller);
      _queryManager.subscribeToInfiniteQuery(widget.id, _controller);
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
    _queryManager.get(_controller.id)?.unsubscribe(_controller);
    __controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<InfiniteQueryState<Data>>(
      valueListenable: _controller,
      builder: (context, value, child) {
        return widget.builder(context, value, child);
      },
      child: widget.child,
    );
  }
}
