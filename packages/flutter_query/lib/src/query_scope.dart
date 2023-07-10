import 'package:flutter/widgets.dart';
import 'package:flutter_query/flutter_query.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

class QueryScope extends SingleChildStatelessWidget {
  QueryScope({
    Key? key,
    this.prepare,
    this.lazy,
    Widget? child,
  }) : super(key: key, child: child);

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
      updateShouldNotify: (previous, current) => previous != current,
      lazy: lazy,
      child: child,
    );
  }
}
