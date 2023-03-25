import 'package:fluery/src/base_query.dart';
import 'package:fluery/src/query_cache_storage.dart';
import 'package:fluery/src/query_client_provider.dart';
import 'package:fluery/src/query_manager.dart';
import 'package:flutter/material.dart';

typedef QueryFetcher<Data> = Future<Data> Function(QueryIdentifier id);

typedef QueryWidgetBuilder<Data> = Widget Function(
  BuildContext context,
  QueryState<Data> state,
  Widget? child,
);

class QueryState<Data> extends BaseQueryState {
  QueryState({
    QueryStatus status = QueryStatus.idle,
    this.data,
    Object? error,
  }) : super(
          status: status,
          error: error,
        );

  final Data? data;

  QueryState<Data> copyWith({
    QueryStatus? status,
    Data? data,
    Object? error,
  }) {
    return QueryState<Data>(
      status: status ?? this.status,
      data: data ?? this.data,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => super.props + [data];
}

class Query<Data>
    extends BaseQuery<Query<Data>, QueryController<Data>, QueryState<Data>> {
  Query({
    required QueryIdentifier id,
    required QueryCacheStorage cacheStorage,
  }) : super(
          id: id,
          cacheStorage: cacheStorage,
        ) {
    state = QueryState<Data>();
  }

  bool _isFetching = false;

  @override
  Future<void> fetch({
    QueryFetcher? fetcher,
    Duration? staleDuration,
  }) async {
    if (controllers.isEmpty) {
      return;
    }

    if (_isFetching) {
      return;
    } else {
      _isFetching = true;
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

      final cacheState = cacheStorage.get<Data>(id);
      final shouldFetch = cacheState?.isStale(effectiveStaleDuration) ?? true;
      if (!shouldFetch) {
        notify(state = state.copyWith(
          status: QueryStatus.success,
          data: cacheState!.data,
        ));
        return;
      }

      notify(state = state.copyWith(status: QueryStatus.loading));
      try {
        final data = await effectiveFetcher(id);
        cacheStorage.set<Data>(id, data);
        notify(state = state.copyWith(
          status: QueryStatus.success,
          data: data,
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
      _isFetching = false;
    }
  }
}

class QueryController<Data> extends BaseQueryController<Query<Data>,
    QueryController<Data>, QueryState<Data>> {
  QueryController() : super(QueryState<Data>());

  late QueryIdentifier _id;
  late QueryFetcher<Data> _fetcher;
  late Duration _staleDuration;

  QueryIdentifier get id => _id;
  QueryFetcher<Data> get fetcher => _fetcher;
  Duration get staleDuration => _staleDuration;

  Future<void> fetch() async {
    await query.fetch(
      fetcher: fetcher,
      staleDuration: staleDuration,
    );
  }
}

class QueryBuilder<Data> extends StatefulWidget {
  const QueryBuilder({
    super.key,
    this.controller,
    required this.id,
    required this.fetcher,
    this.staleDuration = Duration.zero,
    required this.builder,
    this.child,
  });

  final QueryController<Data>? controller;
  final QueryIdentifier id;
  final QueryFetcher<Data> fetcher;
  final Duration staleDuration;
  final QueryWidgetBuilder<Data> builder;
  final Widget? child;

  @override
  State<QueryBuilder> createState() => _QueryBuilderState<Data>();
}

class _QueryBuilderState<Data> extends State<QueryBuilder<Data>> {
  final QueryController<Data> __controller = QueryController<Data>();

  late QueryManager _queryManager;

  QueryController<Data> get _controller => widget.controller ?? __controller;

  @override
  void initState() {
    super.initState();
    _controller._id = widget.id;
    _controller._fetcher = widget.fetcher;
    _controller._staleDuration = widget.staleDuration;

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      await _controller.fetch();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _queryManager = QueryClientProvider.of(context).manager;
    _queryManager.subscribeToQuery(_controller.id, _controller);
  }

  @override
  void didUpdateWidget(covariant QueryBuilder<Data> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller._id = widget.id;
    _controller._fetcher = widget.fetcher;
    _controller._staleDuration = widget.staleDuration;

    if (widget.controller != oldWidget.controller ||
        widget.id != oldWidget.id) {
      _queryManager.unsubscribe(oldWidget.id, _controller);
      _queryManager.subscribeToQuery(widget.id, _controller);
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
    _queryManager.unsubscribe(_controller.id, _controller);
    __controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<QueryState<Data>>(
      valueListenable: _controller,
      builder: (context, value, child) {
        return widget.builder(context, value, child);
      },
      child: widget.child,
    );
  }
}
