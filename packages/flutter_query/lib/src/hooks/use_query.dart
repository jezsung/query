import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:clock/clock.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../core/core.dart';
import 'use_query_client.dart';

// enum NetworkMode { online, always, offlineFirst }

class UseQueryResult<TData, TError> with EquatableMixin {
  const UseQueryResult({
    required this.status,
    required this.fetchStatus,
    required this.data,
    required this.dataUpdatedAt,
    required this.error,
    required this.errorUpdatedAt,
    required this.errorUpdateCount,
    required this.failureCount,
    required this.failureReason,
    required this.isEnabled,
    required StaleDuration staleDuration,
    required this.isPlaceholderData,
    // required this.isFetchedAfterMount,
  }) : _staleDuration = staleDuration;

  // Base fields
  final QueryStatus status;
  final FetchStatus fetchStatus;
  final TData? data;
  final DateTime? dataUpdatedAt;
  final TError? error;
  final DateTime? errorUpdatedAt;
  final int errorUpdateCount;
  final int failureCount;
  final TError? failureReason;
  final bool isEnabled;
  final bool isPlaceholderData;
  final StaleDuration _staleDuration;

  // final bool isFetchedAfterMount;
  // final bool isPlaceholderData;
  // final bool isStale;
  // final T promise; // promise: Promise<TData>
  // final T refetch; // refetch: (options: { throwOnError: boolean, cancelRefetch: boolean }) => Promise<UseQueryResult>

  // Derived fields - computed from base fields
  bool get isError => status == QueryStatus.error;
  bool get isSuccess => status == QueryStatus.success;
  bool get isPending => status == QueryStatus.pending;
  bool get isFetching => fetchStatus == FetchStatus.fetching;
  bool get isPaused => fetchStatus == FetchStatus.paused;
  bool get isFetched => dataUpdatedAt != null;
  bool get isLoading => isPending && isFetching;
  bool get isInitialLoading => isLoading && !isFetched;
  bool get isLoadingError => isError && data == null;
  bool get isRefetchError => isError && data != null;
  bool get isRefetching => isFetching && !isPending;
  bool get isStale {
    // Data is stale if there's no dataUpdatedAt
    if (dataUpdatedAt == null) return true;

    final age = clock.now().difference(dataUpdatedAt!);

    return switch (_staleDuration) {
      // Check if age exceeds or equals staleDuration (>= for zero staleDuration)
      StaleDurationDuration duration => age >= duration,
      // If staleDuration is StaleDurationInfinity, never stale (unless invalidated)
      StaleDurationInfinity() => false,
      // If staleDuration is StaleDurationStatic, never stale
      StaleDurationStatic() => false,
    };
  }

  @override
  List<Object?> get props => [
        status,
        fetchStatus,
        data,
        dataUpdatedAt,
        error,
        errorUpdatedAt,
        errorUpdateCount,
        failureCount,
        failureReason,
        isEnabled,
        isPlaceholderData,
        _staleDuration,
      ];
}

UseQueryResult<TData, TError> useQuery<TData, TError>({
  required List<Object?> queryKey,
  required Future<TData> Function(QueryContext context) queryFn,
  GcDurationOption? gcDuration,
  bool? enabled,
  TData? initialData,
  DateTime? initialDataUpdatedAt,
  PlaceholderData<TData, TError>? placeholderData,
  Duration? refetchInterval,
  RefetchOnMount? refetchOnMount,
  RefetchOnResume? refetchOnResume,
  Retry<TError>? retry,
  bool? retryOnMount,
  RetryDelay<TError>? retryDelay,
  StaleDuration? staleDuration,
  StaleDurationResolver<TData, TError>? staleDurationResolver,
  QueryClient? queryClient,
  // networkMode: 'online' | 'always' | 'offlineFirst'
  // NetworkMode networkMode = NetworkMode.online,
  // meta: Record<string, unknown>
  // Map<String, Object?>? meta,
  // notifyOnChangeProps: string[] | "all" | (() => string[] | "all" | undefined)
  // List<String>? notifyOnChangeProps,
  // queryKeyHashFn: (queryKey: QueryKey) => string
  // String Function()? queryKeyHashFn,
  // refetchOnMount: boolean | "always" | ((query: Query) => boolean | "always")
  // refetchOnMount = true,
  // refetchOnReconnect: boolean | "always" | ((query: Query) => boolean | "always")
  // refetchOnReconnect = true,
  // refetchOnWindowFocus: boolean | "always" | ((query: Query) => boolean | "always")
  // refetchOnWindowFocus = true,
  // select: (data: TData) => unknown
  // Object? Function(TData)? select,
  // structuralSharing: boolean | (oldData: unknown | undefined, newData: unknown) => unknown
  // structuralSharing = true,
  // subscribed: boolean
  // bool subscribed = true,
  // throwOnError: undefined | boolean | (error: TError, query: Query) => boolean
  // throwOnError,
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
        gcDuration: gcDuration,
        enabled: enabled,
        initialData: initialData,
        initialDataUpdatedAt: initialDataUpdatedAt,
        placeholderData: placeholderData,
        refetchInterval: refetchInterval,
        refetchOnMount: refetchOnMount,
        refetchOnResume: refetchOnResume,
        retry: retry,
        retryOnMount: retryOnMount,
        retryDelay: retryDelay,
        staleDuration: staleDuration,
        staleDurationResolver: staleDurationResolver,
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
      gcDuration: gcDuration,
      enabled: enabled,
      initialData: initialData,
      initialDataUpdatedAt: initialDataUpdatedAt,
      placeholderData: placeholderData,
      refetchInterval: refetchInterval,
      refetchOnMount: refetchOnMount,
      refetchOnResume: refetchOnResume,
      retry: retry,
      retryOnMount: retryOnMount,
      retryDelay: retryDelay,
      staleDuration: staleDuration,
      staleDurationResolver: staleDurationResolver,
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
