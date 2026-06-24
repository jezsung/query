import 'package:flutter_hooks/flutter_hooks.dart';

import '../core/core.dart';
import 'use_query_client.dart';

/// A hook for performing mutations from a pre-built [MutationOptions] object.
///
/// This is the object-first counterpart to [useMutation]. Bundle a mutation's
/// function, lifecycle callbacks, and configuration into a [MutationOptions]
/// instance — often via a factory such as `updateTodoMutationOptions()` — and
/// pass it here. This keeps a mutation definition in one place, separate from
/// the widget that triggers it.
///
/// The [client] parameter, if provided, takes precedence over the nearest
/// [QueryClientProvider] ancestor. It is supplied separately because it is an
/// environmental concern, not part of the mutation definition carried by
/// [options].
///
/// Returns a [MutationResult] containing the mutation state and control
/// methods. The widget rebuilds automatically when the mutation state changes.
///
/// See also:
///
/// - [useMutation] for the inline argument form
/// - [MutationOptions] for the bundled definition this hook consumes
MutationResult<TData, TError, TVariables, TOnMutateResult>
    useMutationOptions<TData, TError, TVariables, TOnMutateResult>(
  MutationOptions<TData, TError, TVariables, TOnMutateResult> options, {
  QueryClient? client,
}) {
  final effectiveClient = useQueryClient(client);

  // Create observer once per component instance
  final observer = useMemoized(
    () => MutationObserver<TData, TError, TVariables, TOnMutateResult>(
      effectiveClient,
      options,
    ),
    [effectiveClient],
  );

  // Mount observer and cleanup on unmount
  useEffect(() {
    observer.onMount();
    return observer.onUnmount;
  }, [observer]);

  // Update options during render (before subscribing)
  observer.options = options;

  // Subscribe to observer and trigger rebuilds when result changes
  // Uses useState with useEffect subscription for synchronous updates
  final result = useState(observer.result);

  useEffect(() {
    final unsubscribe = observer.subscribe((newResult) {
      result.value = newResult;
    });
    return unsubscribe;
  }, [observer]);

  return result.value;
}
