import 'package:flutter/widgets.dart';

import '../core/query_client.dart';

/// Provides a [QueryClient] to the widget tree.
///
/// This widget makes a [QueryClient] available to all descendant widgets
/// without needing to explicitly pass it through widget constructors.
///
/// Example:
/// ```dart
/// QueryClientProvider(
///   client: QueryClient(),
///   child: MyApp(),
/// )
/// ```
class QueryClientProvider extends InheritedWidget {
  const QueryClientProvider({
    required this.client,
    required super.child,
    super.key,
  });

  final QueryClient client;

  /// Retrieves the [QueryClient] from the nearest [QueryClientProvider] ancestor.
  ///
  /// Throws a [FlutterError] if no [QueryClientProvider] is found in the widget tree.
  static QueryClient of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<QueryClientProvider>();
    if (provider == null) {
      throw FlutterError(
        'QueryClientProvider not found in widget tree.\n'
        'Make sure to wrap your widget tree with QueryClientProvider:\n'
        'QueryClientProvider(\n'
        '  client: QueryClient(),\n'
        '  child: MyApp(),\n'
        ')',
      );
    }
    return provider.client;
  }

  /// Tries to retrieve the [QueryClient] from the widget tree.
  ///
  /// Returns null if no [QueryClientProvider] is found.
  static QueryClient? maybeOf(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<QueryClientProvider>();
    return provider?.client;
  }

  @override
  bool updateShouldNotify(QueryClientProvider oldWidget) {
    return client != oldWidget.client;
  }
}
