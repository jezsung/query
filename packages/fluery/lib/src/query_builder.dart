import 'package:fluery/src/query.dart';
import 'package:fluery/src/query_client.dart';
import 'package:fluery/src/query_client_provider.dart';
import 'package:flutter/material.dart';

class QueryController<Data> extends ValueNotifier<QueryState<Data>> {
  QueryController() : super(QueryState<Data>(status: QueryStatus.idle));

  QueryKey? _key;
  QueryFetcher<Data>? _fetcher;
  Duration? _staleDuration;

  Query<Data>? _query;
  VoidCallback? _queryListener;

  QueryKey get key => _key!;
  QueryFetcher<Data> get fetcher => _fetcher!;
  Duration get staleDuration => _staleDuration!;
  Query<Data> get query => _query!;

  Future<void> fetch({
    QueryFetcher<Data>? fetcher,
    Duration? staleDuration,
  }) async {
    final effectiveFetcher = fetcher ?? _fetcher!;
    final effectiveStaleDuration = staleDuration ?? _staleDuration!;

    await _query!.fetch(
      fetcher: effectiveFetcher,
      staleDuration: effectiveStaleDuration,
    );
  }

  void _setOptions({
    required QueryKey key,
    required QueryFetcher<Data> fetcher,
    required Duration staleDuration,
  }) {
    _key = key;
    _fetcher = fetcher;
    _staleDuration = staleDuration;
  }

  void _subscribe(Query<Data> query) {
    _query = query;
    value = _query!.value;
    _queryListener = () {
      value = query.value;
    };
    _query!.addListener(_queryListener!);
  }

  @override
  void dispose() {
    if (_queryListener != null) {
      _query!.removeListener(_queryListener!);
    }
    super.dispose();
  }
}

typedef QueryWidgetBuilder<Data> = Widget Function(
  BuildContext context,
  QueryState<Data> state,
  Widget? child,
);

class QueryBuilder<Data> extends StatefulWidget {
  const QueryBuilder({
    super.key,
    this.controller,
    required this.queryKey,
    required this.fetcher,
    this.staleDuration = Duration.zero,
    required this.builder,
    this.child,
  });

  final QueryController<Data>? controller;
  final QueryKey queryKey;
  final QueryFetcher<Data> fetcher;
  final Duration staleDuration;
  final QueryWidgetBuilder<Data> builder;
  final Widget? child;

  @override
  State<QueryBuilder> createState() => _QueryBuilderState<Data>();
}

class _QueryBuilderState<Data> extends State<QueryBuilder<Data>> {
  late final QueryClient _queryClient;
  late final QueryController<Data> _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? QueryController<Data>();
    _controller._setOptions(
      key: widget.queryKey,
      fetcher: widget.fetcher,
      staleDuration: widget.staleDuration,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _queryClient = QueryClientProvider.of(context);
    final query = _queryClient.build<Data>(widget.queryKey);
    _controller._subscribe(query);
    _queryClient.addController(_controller);

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      await _controller.fetch();
    });
  }

  @override
  void didUpdateWidget(covariant QueryBuilder<Data> oldWidget) {
    super.didUpdateWidget(oldWidget);

    _queryClient.removeController(_controller);
    _controller._setOptions(
      key: widget.queryKey,
      fetcher: widget.fetcher,
      staleDuration: widget.staleDuration,
    );
    _queryClient.addController(_controller);

    final queryKeyChanged = widget.queryKey != oldWidget.queryKey;
    final fetcherChanged = widget.fetcher != oldWidget.fetcher;
    final staleDurationChanged =
        widget.staleDuration != oldWidget.staleDuration;

    final shouldRefetch =
        queryKeyChanged || fetcherChanged || staleDurationChanged;

    if (shouldRefetch) {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
        await _controller.fetch();
      });
    }
  }

  @override
  void dispose() {
    _queryClient.removeController(_controller);
    if (widget.controller == null) {
      _controller.dispose();
    }
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
