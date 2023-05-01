import 'package:fluery/fluery.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/single_child_widget.dart';
import 'package:provider/provider.dart';

import '../core/query_client.dart';

class QueryClientProvider extends SingleChildStatelessWidget {
  QueryClientProvider({
    super.key,
    required Create<QueryClient> this.create,
    this.lazy,
    super.child,
  }) : value = null;

  QueryClientProvider.value({
    super.key,
    required QueryClient this.value,
    this.lazy,
    super.child,
  }) : create = null;

  final Create<QueryClient>? create;
  final QueryClient? value;
  final bool? lazy;

  static QueryClient of(BuildContext context, {bool listen = true}) {
    return Provider.of<QueryClient>(context, listen: listen);
  }

  @override
  Widget buildWithChild(BuildContext context, Widget? child) {
    if (create != null) {
      return InheritedProvider<QueryClient>(
        create: create!,
        dispose: (context, value) => value.dispose(),
        updateShouldNotify: (previous, current) => previous != current,
        lazy: lazy,
        child: child,
      );
    }

    if (value != null) {
      return InheritedProvider<QueryClient>.value(
        value: value!,
        updateShouldNotify: (previous, current) => previous != current,
        lazy: lazy,
        child: child,
      );
    }

    throw UnimplementedError();
  }
}
