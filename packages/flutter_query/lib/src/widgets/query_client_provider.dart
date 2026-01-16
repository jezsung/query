import 'package:flutter/widgets.dart';

import '../core/query_client.dart';

/// Provides a [QueryClient] to the widget tree.
///
/// This widget makes a [QueryClient] available to all descendant widgets
/// without needing to explicitly pass it through widget constructors.
///
/// There are two ways to use this provider:
///
/// **Default constructor** - Creates and manages a [QueryClient]:
/// ```dart
/// QueryClientProvider(
///   create: (context) => QueryClient(),
///   child: MyApp(),
/// )
/// ```
/// The [QueryClient] returned from [create] will be automatically cleared
/// when the provider is removed from the widget tree.
///
/// Use [lazy] to defer creation until the [QueryClient] is first accessed:
/// ```dart
/// QueryClientProvider(
///   create: (context) => QueryClient(),
///   lazy: true,
///   child: MyApp(),
/// )
/// ```
///
/// **Value constructor** - Uses an existing [QueryClient]:
/// ```dart
/// QueryClientProvider.value(
///   QueryClient(),
///   child: MyApp(),
/// )
/// ```
/// The [QueryClient] will NOT be cleared when the provider is removed.
/// Use this when you want to manage the [QueryClient] lifecycle yourself.
class QueryClientProvider extends StatefulWidget {
  /// Creates a [QueryClientProvider] that creates and manages a [QueryClient].
  ///
  /// The [create] function is called to create the [QueryClient]. When the
  /// provider is removed from the widget tree, the [QueryClient] will be
  /// automatically cleared.
  ///
  /// If [lazy] is true (default is false), the [create] function will not be
  /// called until the [QueryClient] is first accessed via [of] or [maybeOf].
  const QueryClientProvider({
    required QueryClient Function(BuildContext context) create,
    required this.child,
    this.lazy = false,
    super.key,
  })  : _create = create,
        _value = null;

  /// Creates a [QueryClientProvider] from an existing [QueryClient].
  ///
  /// The [QueryClient] will NOT be cleared when the provider is removed
  /// from the widget tree. Use this constructor when you want to manage
  /// the [QueryClient] lifecycle yourself.
  const QueryClientProvider.value(
    QueryClient value, {
    required this.child,
    super.key,
  })  : _value = value,
        _create = null,
        lazy = false;

  final QueryClient Function(BuildContext context)? _create;
  final QueryClient? _value;

  /// Whether to defer creation of the [QueryClient] until it's first accessed.
  ///
  /// Only applies when using the default constructor with [create].
  /// Defaults to false.
  final bool lazy;

  /// The widget below this widget in the tree.
  final Widget child;

  /// Retrieves the [QueryClient] from the nearest [QueryClientProvider] ancestor.
  ///
  /// Throws a [FlutterError] if no [QueryClientProvider] is found in the widget tree.
  static QueryClient of(BuildContext context) {
    final inherited = context
        .dependOnInheritedWidgetOfExactType<_InheritedQueryClientProvider>();
    if (inherited == null) {
      throw FlutterError(
        'QueryClientProvider not found in widget tree.\n'
        'Make sure to wrap your widget tree with QueryClientProvider:\n'
        'QueryClientProvider(\n'
        '  create: (context) => QueryClient(),\n'
        '  child: MyApp(),\n'
        ')',
      );
    }
    return inherited.state._getClient();
  }

  /// Tries to retrieve the [QueryClient] from the widget tree.
  ///
  /// Returns null if no [QueryClientProvider] is found.
  static QueryClient? maybeOf(BuildContext context) {
    final inherited = context
        .dependOnInheritedWidgetOfExactType<_InheritedQueryClientProvider>();
    return inherited?.state._getClient();
  }

  @override
  State<QueryClientProvider> createState() => _QueryClientProviderState();
}

class _QueryClientProviderState extends State<QueryClientProvider> {
  QueryClient? _client;
  bool _shouldClear = false;

  @override
  void initState() {
    super.initState();
    if (widget._value != null) {
      _client = widget._value;
      _shouldClear = false;
    } else if (!widget.lazy) {
      _createQueryClient();
    }
  }

  @override
  void dispose() {
    if (_shouldClear && _client != null) {
      _client!.clear();
    }
    super.dispose();
  }

  void _createQueryClient() {
    if (_client == null && widget._create != null) {
      _client = widget._create!(context);
      _shouldClear = true;
    }
  }

  QueryClient _getClient() {
    if (_client == null) {
      _createQueryClient();
    }
    return _client!;
  }

  @override
  Widget build(BuildContext context) {
    return _InheritedQueryClientProvider(
      state: this,
      child: widget.child,
    );
  }
}

class _InheritedQueryClientProvider extends InheritedWidget {
  const _InheritedQueryClientProvider({
    required this.state,
    required super.child,
  });

  final _QueryClientProviderState state;

  @override
  bool updateShouldNotify(_InheritedQueryClientProvider oldWidget) {
    return state != oldWidget.state;
  }
}
