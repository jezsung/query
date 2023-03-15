import 'package:fluery/fluery.dart';
import 'package:fluery/src/query_observer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

typedef QueryWidgetBuilder<Data> = Widget Function(
  BuildContext context,
  QueryState<Data> state,
  Widget? child,
);

class QueryBuilder<Data> extends StatefulWidget {
  const QueryBuilder({
    super.key,
    required this.queryKey,
    required this.fetcher,
    this.staleDuration = Duration.zero,
    required this.builder,
    this.child,
  });

  final QueryKey queryKey;
  final QueryFetcher<Data> fetcher;
  final Duration staleDuration;
  final QueryWidgetBuilder<Data> builder;
  final Widget? child;

  @override
  State<QueryBuilder> createState() => _QueryBuilderState<Data>();
}

class _QueryBuilderState<Data> extends State<QueryBuilder<Data>> {
  late final Query<Data> _query;
  late final QueryObserver<Data> _observer;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final QueryClient queryClient = QueryClientProvider.of(context);

    _query = queryClient.build(widget.queryKey);
    _observer = QueryObserver<Data>(
      query: _query,
      fetcher: widget.fetcher,
      staleDuration: widget.staleDuration,
    );
    _query.addObserver(_observer);

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      await _observer.fetch();
    });
  }

  @override
  void didUpdateWidget(covariant QueryBuilder<Data> oldWidget) {
    super.didUpdateWidget(oldWidget);

    final bool shouldRefetch = oldWidget.queryKey != widget.queryKey ||
        oldWidget.staleDuration != widget.staleDuration;

    if (shouldRefetch) {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
        await _observer.fetch();
      });
    }
  }

  @override
  void dispose() {
    _query.removeObserver(_observer);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<QueryState<Data>>(
      valueListenable: _query,
      builder: (context, value, child) {
        return widget.builder(context, value, child);
      },
      child: widget.child,
    );
  }
}
