import 'package:flutter/widgets.dart';

import 'package:flutter_hooks/flutter_hooks.dart';

import '../core/core.dart';
import 'use_query_client.dart';

QueryResult<TData, TError> useQuery<TData, TError>({
  required List<Object?> queryKey,
  required QueryFn<TData> queryFn,
  bool? enabled,
  Expiry? expiresIn,
  GcDuration? gcDuration,
  TData? placeholder,
  Duration? refetchInterval,
  RefetchOnMount? refetchOnMount,
  RefetchOnResume? refetchOnResume,
  RetryResolver<TError>? retry,
  bool? retryOnMount,
  TData? seed,
  DateTime? seedUpdatedAt,
  QueryClient? queryClient,
}) {
  // Get QueryClient from context if not provided
  final client = queryClient ?? useQueryClient();

  // Create observer once per component instance
  // Client defaults are applied inside QueryObserver constructor
  final observer = useMemoized(
    () => QueryObserver<TData, TError>(
      client,
      QueryOptions(
        queryKey,
        queryFn,
        enabled: enabled,
        expiresIn: expiresIn,
        gcDuration: gcDuration,
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
  // Client defaults are applied inside QueryObserver.updateOptions()
  observer.updateOptions(
    QueryOptions(
      queryKey,
      queryFn,
      enabled: enabled,
      expiresIn: expiresIn,
      gcDuration: gcDuration,
      placeholder: placeholder,
      refetchInterval: refetchInterval,
      refetchOnMount: refetchOnMount,
      refetchOnResume: refetchOnResume,
      retry: retry,
      retryOnMount: retryOnMount,
      seed: seed,
      seedUpdatedAt: seedUpdatedAt,
    ),
  );

  // Subscribe to observer and trigger rebuilds when result changes
  // Uses direct callback subscription for synchronous updates
  final result = useState(observer.result);

  useEffect(() {
    final unsubscribe = observer.subscribe((newResult) {
      result.value = newResult;
    });
    return unsubscribe;
  }, []);

  // Refetch on app resume based on refetchOnResume option
  useEffect(() {
    final listener = AppLifecycleListener(onResume: observer.onResume);
    return listener.dispose;
  }, [observer]);

  // Cleanup on unmount
  useEffect(() {
    return () {
      observer.dispose();
    };
  }, []);

  // Return observer.result directly to ensure synchronous updates are visible immediately.
  // The useState + subscription pattern ensures widget rebuilds when the result changes,
  // but returning observer.result directly allows tests and imperative code to see
  // updates immediately without waiting for a rebuild.
  return result.value;
}
