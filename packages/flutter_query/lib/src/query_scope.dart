import 'package:flutter/widgets.dart';
import 'package:flutter_query/flutter_query.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

class QueryScope extends SingleChildStatelessWidget {
  QueryScope({
    super.key,
    this.prepare,
    this.lazy,
    super.child,
  });

  final void Function(QueryClient client)? prepare;
  final bool? lazy;

  @override
  Widget buildWithChild(BuildContext context, Widget? child) {
    return InheritedProvider<QueryClient>(
      create: (context) {
        final queryClient = QueryClient();
        prepare?.call(queryClient);
        return queryClient;
      },
      dispose: (context, value) => value.cache.close(),
      updateShouldNotify: (previous, current) => previous != current,
      lazy: lazy,
      child: child,
    );
  }
}
