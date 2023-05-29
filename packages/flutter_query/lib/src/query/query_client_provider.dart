part of 'query.dart';


class QueryClientProvider extends SingleChildStatelessWidget {
  QueryClientProvider({
    Key? key,
    required Create<QueryClient> this.create,
    this.lazy,
    Widget? child,
  })  : value = null,
        super(key: key, child: child);

  QueryClientProvider.value({
    Key? key,
    required QueryClient this.value,
    this.lazy,
    Widget? child,
  })  : create = null,
        super(key: key, child: child);

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
        dispose: (context, value) => value.close(),
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
