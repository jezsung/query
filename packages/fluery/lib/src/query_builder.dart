import 'package:fluery/src/base_query.dart';
import 'package:fluery/src/fluery_error.dart';
import 'package:fluery/src/query_client_provider.dart';
import 'package:flutter/widgets.dart';

typedef QueryFetcher<Data> = Future<Data> Function(QueryIdentifier id);

typedef QueryWidgetBuilder<Data> = Widget Function(
  BuildContext context,
  QueryState<Data> state,
  Widget? child,
);

enum QueryStatus {
  idle,
  loading,
  success,
  failure,
}

class QueryState<Data> extends BaseQueryState {
  const QueryState({
    this.status = QueryStatus.idle,
    this.data,
    this.dataUpdatedAt,
    this.error,
    this.errorUpdatedAt,
  });

  final QueryStatus status;
  final Data? data;
  final Object? error;
  final DateTime? dataUpdatedAt;
  final DateTime? errorUpdatedAt;

  bool get hasData => data != null;

  bool get hasError => error != null;

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
  List<Object?> get props => [
        status,
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

  void setInitialData({
    required Data data,
    DateTime? updatedAt,
  }) {
    final isDataUpToDate = updatedAt != null &&
        state.dataUpdatedAt != null &&
        updatedAt.isAfter(state.dataUpdatedAt!);

    if (!state.hasData || isDataUpToDate) {
      notify(QueryStateUpdated(
        state = state.copyWith(
          status: QueryStatus.success,
          data: data,
          dataUpdatedAt: updatedAt ?? DateTime.now(),
        ),
      ));
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
    this.initialData,
    this.initialDataUpdatedAt,
    this.staleDuration = Duration.zero,
    required this.builder,
    this.child,
  });

  final QueryController<Data>? controller;
  final QueryIdentifier id;
  final QueryFetcher<Data> fetcher;
  final Data? initialData;
  final DateTime? initialDataUpdatedAt;
  final Duration staleDuration;
  final QueryWidgetBuilder<Data> builder;
  final Widget? child;

  @override
  State<QueryBuilder> createState() => _QueryBuilderState<Data>();
}

class _QueryBuilderState<Data> extends State<QueryBuilder<Data>> {
  final QueryController<Data> _controller = QueryController<Data>();

  late Query<Data> _query;

  QueryController<Data> get _effectiveController =>
      widget.controller ?? _controller;

  @override
  void initState() {
    super.initState();
    _effectiveController._id = widget.id;
    _effectiveController._fetcher = widget.fetcher;
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
        .buildQuery(_effectiveController.id);

    _query.addObserver<QueryController<Data>>(_effectiveController);

    if (widget.initialData != null) {
      _query.setInitialData(
        // ignore: null_check_on_nullable_type_parameter
        data: widget.initialData!,
        updatedAt: widget.initialDataUpdatedAt,
      );
    }
  }

  @override
  void didUpdateWidget(covariant QueryBuilder<Data> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != null && widget.controller == null) {
      _query.removeObserver<QueryController<Data>>(oldWidget.controller!);
    } else if (oldWidget.controller == null && widget.controller != null) {
      _query.removeObserver<QueryController<Data>>(_controller);
    } else if (oldWidget.controller != widget.controller) {
      _query.removeObserver<QueryController<Data>>(oldWidget.controller!);
    }

    _effectiveController._id = widget.id;
    _effectiveController._fetcher = widget.fetcher;
    _effectiveController._staleDuration = widget.staleDuration;

    if (oldWidget.controller != null && widget.controller == null) {
      _query.addObserver<QueryController<Data>>(_controller);
    } else if (oldWidget.controller == null && widget.controller != null) {
      _query.addObserver<QueryController<Data>>(widget.controller!);
    } else if (oldWidget.controller != widget.controller) {
      _query.addObserver<QueryController<Data>>(widget.controller!);
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
    _query.removeObserver<QueryController<Data>>(_effectiveController);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<QueryState<Data>>(
      valueListenable: _effectiveController,
      builder: (context, value, child) {
        return widget.builder(context, value, child);
      },
      child: widget.child,
    );
  }
}
