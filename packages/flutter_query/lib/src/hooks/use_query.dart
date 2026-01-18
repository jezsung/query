import 'package:flutter/widgets.dart';

import 'package:flutter_hooks/flutter_hooks.dart';

import '../core/core.dart';
import 'use_query_client.dart';

QueryResult<TData, TError> useQuery<TData, TError>(
  List<Object?> queryKey,
  QueryFn<TData> queryFn, {
  bool? enabled,
  StaleDuration? staleDuration,
  GcDuration? gcDuration,
  TData? placeholder,
  RefetchOnMount? refetchOnMount,
  RefetchOnResume? refetchOnResume,
  Duration? refetchInterval,
  RetryResolver<TError>? retry,
  bool? retryOnMount,
  TData? seed,
  DateTime? seedUpdatedAt,
  Map<String, dynamic>? meta,
  QueryClient? queryClient,
}) {
  final client = useQueryClient(queryClient);

  // Create observer once per component instance
  // Client defaults are applied inside QueryObserver constructor
  final observer = useMemoized(
    () => QueryObserver<TData, TError>(
      client,
      QueryObserverOptions(
        queryKey,
        queryFn,
        enabled: enabled,
        staleDuration: staleDuration,
        gcDuration: gcDuration,
        meta: meta,
        placeholder: placeholder,
        refetchInterval: refetchInterval,
        refetchOnMount: refetchOnMount,
        refetchOnResume: refetchOnResume,
        retry: retry,
        retryOnMount: retryOnMount,
        seed: seed,
        seedUpdatedAt: seedUpdatedAt,
      ),
    ),
    [],
  );

  // Update options during render (before subscribing)
  // This ensures we get the optimistic result immediately when options change
  // Client defaults are applied inside QueryObserver.options setter
  observer.options = QueryObserverOptions(
    queryKey,
    queryFn,
    enabled: enabled,
    staleDuration: staleDuration,
    gcDuration: gcDuration,
    meta: meta,
    placeholder: placeholder,
    refetchInterval: refetchInterval,
    refetchOnMount: refetchOnMount,
    refetchOnResume: refetchOnResume,
    retry: retry,
    retryOnMount: retryOnMount,
    seed: seed,
    seedUpdatedAt: seedUpdatedAt,
  );

  // Subscribe to observer and trigger rebuilds when result changes
  // Uses direct callback subscription for synchronous updates
  final result = useState(observer.result);

  useEffect(() {
    final unsubscribe = observer.subscribe((newResult) {
      result.value = newResult;
    });
    return unsubscribe;
  }, [observer]);

  useEffect(() {
    observer.onMount();
    return observer.onUnmount;
  }, [observer]);

  useEffect(() {
    final listener = AppLifecycleListener(onResume: observer.onResume);
    return listener.dispose;
  }, [observer]);

  // Return observer.result directly to ensure synchronous updates are visible immediately.
  // The useState + subscription pattern ensures widget rebuilds when the result changes,
  // but returning observer.result directly allows tests and imperative code to see
  // updates immediately without waiting for a rebuild.
  return result.value;
}
