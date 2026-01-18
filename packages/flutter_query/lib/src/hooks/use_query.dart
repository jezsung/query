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
  QueryClient? client,
}) {
  final effectiveClient = useQueryClient(client);

  // Create observer once per component instance
  final observer = useMemoized(
    () => QueryObserver<TData, TError>(
      effectiveClient,
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
    [effectiveClient],
  );

  // Update options during render (before subscribing)
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
  // Uses useState with useEffect subscription for synchronous updates
  final result = useState(observer.result);

  useEffect(() {
    final unsubscribe = observer.subscribe((newResult) {
      result.value = newResult;
    });
    return unsubscribe;
  }, [observer]);

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

  return result.value;
}
