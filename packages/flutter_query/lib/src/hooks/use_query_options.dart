import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'package:flutter_hooks/flutter_hooks.dart';

import '../core/core.dart';
import 'use_effect_event.dart';
import 'use_query_client.dart';

/// A hook for fetching, caching, and subscribing to async data from a
/// pre-built [QueryOptions] object.
///
/// This is the object-first counterpart to [useQuery]. Bundle a query's key,
/// fetch function, and configuration into a [QueryOptions] instance — often via
/// a factory such as `todoQueryOptions(id)` — and pass it here. This keeps a
/// query definition in one place, separate from the widget that observes it.
///
/// The [client] parameter, if provided, takes precedence over the nearest
/// [QueryClientProvider] ancestor. It is supplied separately because it is an
/// environmental concern, not part of the query definition carried by
/// [options].
///
/// The [shouldRebuild] callback, if provided, decides per update whether the
/// observing widget rebuilds. It receives the last accepted result and the new
/// result, and returns `true` to rebuild or `false` to suppress. When omitted,
/// the widget rebuilds on every change.
///
/// Returns a [QuerySnapshot] containing the current state of the query.
///
/// See also:
///
/// - [useQuery] for the inline key/function form
/// - [QueryOptions] for the bundled definition this hook consumes
QuerySnapshot<TData, TError> useQueryOptions<TData, TError>(
  QueryOptions<TData, TError> options, {
  ShouldRebuild<QuerySnapshot<TData, TError>>? shouldRebuild,
  QueryClient? client,
}) {
  final effectiveClient = useQueryClient(client);

  // Create observer once per component instance
  final observer = useMemoized(
    () => QueryObserver<TData, TError>(effectiveClient, options),
    [effectiveClient],
  );

  // Mount observer and cleanup on unmount
  useEffect(() {
    observer.onMount();
    return observer.onUnmount;
  }, [observer]);

  // Handle app lifecycle resume events
  useEffect(() {
    final listener = AppLifecycleListener(onResume: observer.onResume);
    return listener.dispose;
  }, [observer]);

  // Update options during render (before subscribing)
  observer.options = options;

  // Subscribe to observer and trigger rebuilds when the predicate accepts.
  final result = useState(observer.result);

  // Always-latest view of the predicate for use inside the subscribe effect,
  // whose closure is captured once per [observer] change.
  final accept = useEffectEvent<bool Function(QuerySnapshot<TData, TError>)>(
    (next) => shouldRebuild == null || shouldRebuild(result.value, next),
  );

  // In-build catch-up: a sibling observing the same key may have advanced the
  // observer between builds. Adopt the newer result only if the predicate
  // accepts it, so result.value always holds the last accepted result.
  if (result.value != observer.result &&
      (shouldRebuild == null || shouldRebuild(result.value, observer.result))) {
    result.value = observer.result;
  }

  useEffect(() {
    final unsubscribe = observer.subscribe((newResult) {
      // During the build phase, another widget sharing the same query key may
      // trigger a state change. Setting result.value here would call
      // markNeedsBuild on this element while a different element is building,
      // which Flutter forbids. Deferring to a post-frame callback avoids the
      // error while still delivering the update in the next frame.
      if (SchedulerBinding.instance.schedulerPhase ==
          SchedulerPhase.persistentCallbacks) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (accept.call(newResult)) {
            result.value = newResult;
          }
        });
      } else {
        if (accept.call(newResult)) {
          result.value = newResult;
        }
      }
    });
    return unsubscribe;
  }, [observer]);

  return result.value;
}
