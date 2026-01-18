import 'package:flutter/widgets.dart';

import 'package:flutter_hooks/flutter_hooks.dart';

import '../core/core.dart';
import '../widgets/query_client_provider.dart';

/// A hook that retrieves the [QueryClient] from the widget tree.
///
/// If [client] is provided, it is returned directly. Otherwise, this hook
/// reads the [QueryClient] from the nearest [QueryClientProvider] ancestor
/// in the widget tree.
///
/// Throws a [FlutterError] if no [QueryClientProvider] is found and [client]
/// is not provided.
///
/// Example:
/// ```dart
/// Widget build(BuildContext context) {
///   final queryClient = useQueryClient();
///   // Use queryClient...
/// }
/// ```
QueryClient useQueryClient([QueryClient? client]) {
  final inheritedClient = use(const _UseQueryClientHook());

  if (client != null) {
    return client;
  }

  if (inheritedClient == null) {
    throw FlutterError(
      'QueryClientProvider not found in widget tree.\n'
      'Make sure to wrap your widget tree with QueryClientProvider:\n'
      'QueryClientProvider(\n'
      '  create: (context) => QueryClient(),\n'
      '  child: MyApp(),\n'
      ')',
    );
  }

  return inheritedClient;
}

class _UseQueryClientHook extends Hook<QueryClient?> {
  const _UseQueryClientHook();

  @override
  HookState<QueryClient?, Hook<QueryClient?>> createState() =>
      _UseQueryClientHookState();
}

class _UseQueryClientHookState
    extends HookState<QueryClient?, _UseQueryClientHook> {
  @override
  QueryClient? build(BuildContext context) {
    return QueryClientProvider.maybeOf(context);
  }

  @override
  String get debugLabel => 'useQueryClient';
}
