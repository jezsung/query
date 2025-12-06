import 'package:equatable/equatable.dart';

enum QueryStatus { pending, error, success }

enum FetchStatus { fetching, paused, idle }

enum NetworkMode { online, always, offlineFirst }

class UseQueryResult<TData, TError> with EquatableMixin {
  const UseQueryResult({
    required this.data,
    required this.dataUpdatedAt,
    required this.error,
    required this.errorUpdatedAt,
    required this.errorUpdateCount,
    required this.failureCount,
    required this.failureReason,
    required this.fetchStatus,
    required this.isError,
    required this.isFetched,
    required this.isFetchedAfterMount,
    required this.isFetching,
    required this.isInitialLoading,
    required this.isLoading,
    required this.isLoadingError,
    required this.isPaused,
    required this.isPending,
    required this.isPlaceholderData,
    required this.isRefetchError,
    required this.isRefetching,
    required this.isStale,
    required this.isSuccess,
    required this.isEnabled,
    // required this.promise,
    // required this.refetch,
    required this.status,
  });

  // data: TData *defaults to "undefined"
  final TData? data;
  // dataUpdatedAt: number
  final DateTime dataUpdatedAt;
  // error: null | TError
  final TError? error;
  // errorUpdatedAt: number
  final DateTime errorUpdatedAt;
  // errorUpdateCount: number
  final int errorUpdateCount;
  // failureCount: number
  final int failureCount;
  // failureReason: null | TError
  final TError? failureReason;
  final FetchStatus fetchStatus;
  final bool isError;
  final bool isFetched;
  final bool isFetchedAfterMount;
  final bool isFetching;
  final bool isInitialLoading;
  final bool isLoading;
  final bool isLoadingError;
  final bool isPaused;
  final bool isPending;
  final bool isPlaceholderData;
  final bool isRefetchError;
  final bool isRefetching;
  final bool isStale;
  final bool isSuccess;
  final bool isEnabled;
  // promise: Promise<TData>
  // final T promise;
  // refetch: (options: { throwOnError: boolean, cancelRefetch: boolean }) => Promise<UseQueryResult>
  // final T refetch;
  // status: QueryStatus
  final QueryStatus status;

  @override
  List<Object?> get props => [
        data,
        dataUpdatedAt,
        error,
        errorUpdatedAt,
        errorUpdateCount,
        failureCount,
        failureReason,
        fetchStatus,
        isError,
        isFetched,
        isFetchedAfterMount,
        isFetching,
        isInitialLoading,
        isLoading,
        isLoadingError,
        isPaused,
        isPending,
        isPlaceholderData,
        isRefetchError,
        isRefetching,
        isStale,
        isSuccess,
        isEnabled,
        // promise,
        // refetch,
        status,
      ];
}

UseQueryResult useQuery<TData>({
  // queryKey: unknown[]
  required List<Object?> queryKey,
  // queryFn: (context: QueryFunctionContext) => Promise<TData>
  required Future<TData> Function() queryFn,
  // gcTime: number | Infinity
  Duration gcTime = const Duration(minutes: 5),
  // enabled: boolean | (query: Query) => boolean
  bool enabled = true,
  // networkMode: 'online' | 'always' | 'offlineFirst'
  NetworkMode networkMode = NetworkMode.online,
  // initialData: TData | () => TData
  TData? initialData,
  // initialDataUpdatedAt: number | (() => number | undefined)
  DateTime? initialDataUpdatedAt,
  // meta: Record<string, unknown>
  Map<String, Object?>? meta,
  // notifyOnChangeProps: string[] | "all" | (() => string[] | "all" | undefined)
  List<String>? notifyOnChangeProps,
  // placeholderData: TData | (previousValue: TData | undefined, previousQuery: Query | undefined) => TData
  placeholderData,
  // queryKeyHashFn: (queryKey: QueryKey) => string
  String Function()? queryKeyHashFn,
  // refetchInterval: number | false | ((query: Query) => number | false | undefined)
  refetchInterval,
  // refetchIntervalInBackground: boolean
  bool refetchIntervalInBackground = false,
  // refetchOnMount: boolean | "always" | ((query: Query) => boolean | "always")
  refetchOnMount = true,
  // refetchOnReconnect: boolean | "always" | ((query: Query) => boolean | "always")
  refetchOnReconnect = true,
  // refetchOnWindowFocus: boolean | "always" | ((query: Query) => boolean | "always")
  refetchOnWindowFocus = true,
  // retry: boolean | number | (failureCount: number, error: TError) => boolean
  retry,
  // retryOnMount: boolean
  bool retryOnMount = true,
  // retryDelay: number | (retryAttempt: number, error: TError) => number
  retryDelay,
  // select: (data: TData) => unknown
  Object? Function(TData)? select,
  // staleTime: number | 'static' | ((query: Query) => number | 'static')
  staleTime,
  // structuralSharing: boolean | (oldData: unknown | undefined, newData: unknown) => unknown
  structuralSharing = true,
  // subscribed: boolean
  bool subscribed = true,
  // throwOnError: undefined | boolean | (error: TError, query: Query) => boolean
  throwOnError,
  // queryClient?: QueryClient
  queryClient,
}) {
  throw UnimplementedError('useQuery is not yet implemented');
}
