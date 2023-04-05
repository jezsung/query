import 'package:fluery/fluery.dart';
import 'package:fluery/src/fluery_error.dart';
import 'package:flutter/widgets.dart';

class QueryClientProvider extends StatefulWidget {
  const QueryClientProvider({
    super.key,
    this.cacheStorage,
    required this.child,
  });

  final QueryCacheStorage? cacheStorage;
  final Widget child;

  static QueryClient? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_QueryClientScope>()
        ?.queryClient;
  }

  static QueryClient of(BuildContext context) {
    final QueryClient? queryClient = QueryClientProvider.maybeOf(context);

    if (queryClient == null) {
      throw FlueryError(
        '''
        QueryClientProvider.of() called with a context that does not contain a QueryClientProvider.
        ''',
      );
    }

    return queryClient;
  }

  @override
  State<QueryClientProvider> createState() => _QueryClientProviderState();
}

class _QueryClientProviderState extends State<QueryClientProvider> {
  late final QueryClient _queryClient;

  @override
  void initState() {
    super.initState();
    _queryClient = QueryClient(cacheStorage: widget.cacheStorage);
  }

  @override
  void dispose() {
    _queryClient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _QueryClientScope(
      queryClient: _queryClient,
      child: widget.child,
    );
  }
}

class _QueryClientScope extends InheritedWidget {
  _QueryClientScope({
    Key? key,
    required this.queryClient,
    required Widget child,
  }) : super(key: key, child: child);

  final QueryClient queryClient;

  @override
  bool updateShouldNotify(_QueryClientScope oldWidget) {
    return queryClient != oldWidget.queryClient ||
        queryClient.cacheStorage != oldWidget.queryClient.cacheStorage ||
        queryClient.manager != oldWidget.queryClient.manager;
  }
}
