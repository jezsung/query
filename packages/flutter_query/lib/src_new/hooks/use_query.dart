import 'dart:async';

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
    required this.isEnabled,
    // required this.failureCount,
    // required this.failureReason,
    // required this.isFetchedAfterMount,
    // required this.isPlaceholderData,
    // required this.isStale,
  });

  // Base fields
  final QueryStatus status;
  final FetchStatus fetchStatus;
  final TData? data;
  final DateTime? dataUpdatedAt;
  final TError? error;
  final DateTime? errorUpdatedAt;
  final int errorUpdateCount;
  final bool isEnabled;

  // final int failureCount; // failureCount: number
  // final TError? failureReason; // failureReason: null | TError

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

  @override
  List<Object?> get props => [
        status,
        fetchStatus,
        data,
        dataUpdatedAt,
        error,
        errorUpdatedAt,
        errorUpdateCount,
        isEnabled,
      ];
}

UseQueryResult<TData, TError> useQuery<TData, TError>({
  // queryKey: unknown[]
  required List<Object?> queryKey,
  // queryFn: (context: QueryFunctionContext) => Promise<TData>
  required Future<TData> Function() queryFn,
  // gcTime: number | Infinity
  // Duration gcTime = const Duration(minutes: 5),
  // enabled: boolean | (query: Query) => boolean
  bool enabled = true,
  // networkMode: 'online' | 'always' | 'offlineFirst'
  // NetworkMode networkMode = NetworkMode.online,
  // initialData: TData | () => TData
  // TData? initialData,
  // initialDataUpdatedAt: number | (() => number | undefined)
  // DateTime? initialDataUpdatedAt,
  // meta: Record<string, unknown>
  // Map<String, Object?>? meta,
  // notifyOnChangeProps: string[] | "all" | (() => string[] | "all" | undefined)
  // List<String>? notifyOnChangeProps,
  // placeholderData: TData | (previousValue: TData | undefined, previousQuery: Query | undefined) => TData
  // placeholderData,
  // queryKeyHashFn: (queryKey: QueryKey) => string
  // String Function()? queryKeyHashFn,
  // refetchInterval: number | false | ((query: Query) => number | false | undefined)
  // refetchInterval,
  // refetchIntervalInBackground: boolean
  // bool refetchIntervalInBackground = false,
  // refetchOnMount: boolean | "always" | ((query: Query) => boolean | "always")
  // refetchOnMount = true,
  // refetchOnReconnect: boolean | "always" | ((query: Query) => boolean | "always")
  // refetchOnReconnect = true,
  // refetchOnWindowFocus: boolean | "always" | ((query: Query) => boolean | "always")
  // refetchOnWindowFocus = true,
  // retry: boolean | number | (failureCount: number, error: TError) => boolean
  // retry,
  // retryOnMount: boolean
  // bool retryOnMount = true,
  // retryDelay: number | (retryAttempt: number, error: TError) => number
  // retryDelay,
  // select: (data: TData) => unknown
  // Object? Function(TData)? select,
  // staleTime: number | 'static' | ((query: Query) => number | 'static')
  // staleTime,
  // structuralSharing: boolean | (oldData: unknown | undefined, newData: unknown) => unknown
  // structuralSharing = true,
  // subscribed: boolean
  // bool subscribed = true,
  // throwOnError: undefined | boolean | (error: TError, query: Query) => boolean
  // throwOnError,
  // queryClient?: QueryClient
  QueryClient? queryClient,
}) {
  // Get QueryClient from context if not provided
  final client = queryClient ?? useQueryClient();

  // Create observer once per component instance
  final observer = useMemoized(
    () => QueryObserver<TData, TError>(
      client,
      QueryOptions(
        queryKey: queryKey,
        queryFn: queryFn,
        enabled: enabled,
      ),
    ),
    [],
  );

  // Update options during render (before subscribing)
  // This ensures we get the optimistic result immediately when options change
  observer.updateOptions(
    QueryOptions(
      queryKey: queryKey,
      queryFn: queryFn,
      enabled: enabled,
    ),
  );

  // Subscribe to observer stream to trigger rebuilds when result changes
  useStream(
    observer.onResultChange,
    initialData: observer.result,
  );

  // Cleanup on unmount
  useEffect(() {
    return () {
      observer.dispose();
    };
  }, []);

  // Always return the current result from the observer
  // This ensures we get the optimistic result immediately when options change
  return observer.result;
}
