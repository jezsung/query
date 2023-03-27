import 'package:fluery/src/base_query.dart';
import 'package:fluery/src/fluery_error.dart';
import 'package:fluery/src/query_client_provider.dart';
import 'package:fluery/src/query_manager.dart';
import 'package:flutter/widgets.dart';

typedef QueryFetcher<Data> = Future<Data> Function(QueryIdentifier id);

typedef QueryWidgetBuilder<Data> = Widget Function(
  BuildContext context,
  QueryState<Data> state,
  Widget? child,
);

class QueryState<Data> extends BaseQueryState {
  const QueryState({
    QueryStatus status = QueryStatus.idle,
    this.data,
    this.dataUpdatedAt,
    this.error,
    this.errorUpdatedAt,
  }) : super(status);

  final Data? data;
  final Object? error;
  final DateTime? dataUpdatedAt;
  final DateTime? errorUpdatedAt;

  QueryState<Data> copyWith({
    QueryStatus? status,
    Data? data,
    Object? error,
    DateTime? dataUpdatedAt,
    DateTime? errorUpdatedAt,
  }) {
    return QueryState<Data>(
      status: status ?? this.status,
      data: data ?? this.data,
      error: error ?? this.error,
      dataUpdatedAt: dataUpdatedAt ?? this.dataUpdatedAt,
      errorUpdatedAt: errorUpdatedAt ?? this.errorUpdatedAt,
    );
  }

  factory QueryState.fromJson(Map<String, dynamic> json) {
    // Not implemented yet.
    return QueryState();
  }

  @override
  List<Object?> get props =>
      super.props +
      [
        data,
        error,
        dataUpdatedAt,
        errorUpdatedAt,
      ];
}

class Query<Data> extends BaseQuery {
  Query({
    required QueryIdentifier id,
    QueryState<Data>? initialState,
  }) : super(id) {
    state = initialState ?? QueryState<Data>();
  }

  late QueryState<Data> state;

  bool _isFetching = false;

  Set<QueryController<Data>> get controllers =>
      observers.whereType<QueryController<Data>>().toSet();

  Future<void> fetch({
    required QueryFetcher fetcher,
    required Duration staleDuration,
  }) async {
    if (observers.isEmpty) {
      return;
    }

    if (_isFetching) {
      return;
    } else {
      _isFetching = true;
    }

    Future<void> execute() async {
      final isDataStale = state.dataUpdatedAt
              ?.isBefore(DateTime.now().subtract(staleDuration)) ??
          true;
      if (!isDataStale) {
        return;
      }

      notify(QueryStateUpdated<QueryState<Data>>(
        state = state.copyWith(
          status: QueryStatus.loading,
        ),
      ));

      try {
        final data = await fetcher(id);
        notify(QueryStateUpdated<QueryState<Data>>(
          state = state.copyWith(
            status: QueryStatus.success,
            data: data,
            dataUpdatedAt: DateTime.now(),
          ),
        ));
      } catch (e) {
        notify(QueryStateUpdated<QueryState<Data>>(
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
      _isFetching = false;
    }
  }
}

class QueryController<Data> extends ValueNotifier<QueryState<Data>>
    with BaseQueryObserver<Query<Data>> {
  QueryController() : super(QueryState<Data>());

  Query? _query;

  late QueryIdentifier _id;
  late QueryFetcher<Data> _fetcher;
  late Duration _staleDuration;

  QueryIdentifier get id => _id;
  QueryFetcher<Data> get fetcher => _fetcher;
  Duration get staleDuration => _staleDuration;

  Future<void> fetch() async {
    if (_query == null) {
      throw FlueryError('query is null');
    }
    await _query!.fetch(
      fetcher: _fetcher,
      staleDuration: _staleDuration,
    );
  }

  @override
  void onNotified(Query<Data> query, BaseQueryEvent event) {
    if (event is QueryStateUpdated<QueryState<Data>>) {
      value = event.state;
    } else if (event is QueryObserverAdded<QueryController<Data>>) {
      if (event.observer == this) {
        _query = query;
        value = query.state;
      }
    } else if (event is QueryObserverRemoved<QueryController<Data>>) {
      if (event.observer == this) {
        _query = null;
      }
    }
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
    _queryManager.addControllerToQuery(_controller.id, _controller);
  }

  @override
  void didUpdateWidget(covariant QueryBuilder<Data> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller._id = widget.id;
    _controller._fetcher = widget.fetcher;
    _controller._staleDuration = widget.staleDuration;

    if (widget.controller != oldWidget.controller ||
        widget.id != oldWidget.id) {
      _queryManager.removeControllerFromQuery(oldWidget.id, _controller);
      _queryManager.addControllerToQuery(widget.id, _controller);
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
    _queryManager.removeControllerFromQuery(_controller.id, _controller);
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
