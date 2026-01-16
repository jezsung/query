import 'package:flutter/widgets.dart';

import 'package:flutter_hooks/flutter_hooks.dart';

import '../core/core.dart';
import '../widgets/query_client_provider.dart';

/// A hook that retrieves the [QueryClient] from the widget tree.
///
/// This hook reads the [QueryClient] from the nearest [QueryClientProvider]
/// ancestor in the widget tree.
///
/// Throws a [FlutterError] if no [QueryClientProvider] is found.
///
/// Example:
/// ```dart
/// Widget build(BuildContext context) {
///   final queryClient = useQueryClient();
///   // Use queryClient...
/// }
/// ```
QueryClient useQueryClient() {
  return use(const _UseQueryClientHook());
}

class _UseQueryClientHook extends Hook<QueryClient> {
  const _UseQueryClientHook();

  @override
  HookState<QueryClient, Hook<QueryClient>> createState() =>
      _UseQueryClientHookState();
}

class _UseQueryClientHookState
    extends HookState<QueryClient, _UseQueryClientHook> {
  @override
  QueryClient build(BuildContext context) {
    return QueryClientProvider.of(context);
  }

  @override
  String get debugLabel => 'useQueryClient';
}
