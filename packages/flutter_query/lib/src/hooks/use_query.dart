import 'dart:async';

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
    required this.isEnabled,
    required StaleDurationValue staleDuration,
    required this.isPlaceholderData,
    // required this.failureCount,
    // required this.failureReason,
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
  final bool isEnabled;
  final bool isPlaceholderData;
  final StaleDurationValue _staleDuration;

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
  bool get isStale {
    // Data is stale if there's no dataUpdatedAt
    if (dataUpdatedAt == null) return true;

    final age = clock.now().difference(dataUpdatedAt!);

    return switch (_staleDuration) {
      // Check if age exceeds or equals staleDuration (>= for zero staleDuration)
      StaleDuration duration => age >= duration,
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
        isEnabled,
        isPlaceholderData,
        _staleDuration,
      ];
}

UseQueryResult<TData, TError> useQuery<TData, TError>({
  // queryKey: unknown[]
  required List<Object?> queryKey,
  // queryFn: (context: QueryFunctionContext) => Promise<TData>
  required Future<TData> Function() queryFn,
  // gcTime: number | Infinity
  GcDurationValue gcDuration = const GcDuration(minutes: 5),
  // enabled: boolean | (query: Query) => boolean
  bool enabled = true,
  // networkMode: 'online' | 'always' | 'offlineFirst'
  // NetworkMode networkMode = NetworkMode.online,
  // initialData: TData
  TData? initialData,
  // initialDataUpdatedAt: DateTime
  DateTime? initialDataUpdatedAt,
  // placeholderData: TData
  TData? placeholderData,
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
  // staleDuration: StaleDuration<TData, TError>
  StaleDurationBase staleDuration = StaleDuration.zero,
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
        queryKey,
        queryFn,
        enabled: enabled,
        staleDuration: staleDuration,
        gcDuration: gcDuration,
        initialData: initialData,
        initialDataUpdatedAt: initialDataUpdatedAt,
        placeholderData: placeholderData,
      ),
    ),
    [],
  );

  // Update options during render (before subscribing)
  // This ensures we get the optimistic result immediately when options change
  observer.updateOptions(
    QueryOptions(
      queryKey,
      queryFn,
      enabled: enabled,
      staleDuration: staleDuration,
      gcDuration: gcDuration,
      initialData: initialData,
      initialDataUpdatedAt: initialDataUpdatedAt,
      placeholderData: placeholderData,
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

/// Base class for stale duration configuration.
sealed class StaleDurationBase {}

/// A concrete stale duration value (not a function).
sealed class StaleDurationValue implements StaleDurationBase {}

class StaleDuration extends Duration implements StaleDurationValue {
  /// Data becomes stale after the specified duration
  ///
  /// This is the default constructor matching Duration's constructor.
  ///
  /// Example:
  /// ```dart
  /// StaleDuration(minutes: 5)
  /// StaleDuration(seconds: 30)
  /// StaleDuration(hours: 1, minutes: 30)
  /// ```
  const StaleDuration({
    super.days,
    super.hours,
    super.minutes,
    super.seconds,
    super.milliseconds,
    super.microseconds,
  });

  /// Zero duration - data is immediately stale
  static const StaleDuration zero = StaleDuration(seconds: 0);

  /// Data never becomes stale via time-based staleness.
  ///
  /// Note: Can still be invalidated manually when invalidation is implemented.
  /// Sets duration to maximum possible value internally.
  static const StaleDurationInfinity infinity = StaleDurationInfinity._();

  /// Data never becomes stale (equivalent to TanStack's 'static')
  static const StaleDurationStatic static = StaleDurationStatic._();

  /// Compute stale duration dynamically based on the query state
  ///
  /// Example:
  /// ```dart
  /// StaleDuration.resolveWith((query) {
  ///   // If query has error, make it stale immediately
  ///   if (query.state.error != null) {
  ///     return StaleDuration.zero();
  ///   }
  ///   // Otherwise, 10 minutes
  ///   return StaleDuration(minutes: 10);
  /// })
  /// ```
  static StaleDurationResolver resolveWith<TData, TError>(
    StaleDurationValue Function(Query<TData, TError> query) callback,
  ) {
    return StaleDurationResolver<TData, TError>._(callback);
  }
}

class StaleDurationInfinity implements StaleDurationValue {
  const StaleDurationInfinity._();

  @override
  bool operator ==(Object other) => other is StaleDurationInfinity;

  @override
  int get hashCode => 0;
}

class StaleDurationStatic implements StaleDurationValue {
  const StaleDurationStatic._();

  @override
  bool operator ==(Object other) => other is StaleDurationStatic;

  @override
  int get hashCode => 0;
}

/// A dynamic stale duration that is computed based on query state.
class StaleDurationResolver<TData, TError> implements StaleDurationBase {
  const StaleDurationResolver._(this._callback);

  final StaleDurationValue Function(Query<TData, TError> query) _callback;

  StaleDurationValue resolve(Query<TData, TError> query) => _callback(query);
}

/// A concrete gc duration value.
sealed class GcDurationValue {}

/// Garbage collection duration configuration.
///
/// Controls how long unused/inactive cache data remains in memory before being
/// garbage collected. When a query's cache becomes unused or inactive, that
/// cache data will be garbage collected after this duration.
class GcDuration extends Duration implements GcDurationValue {
  /// Cache is garbage collected after the specified duration
  ///
  /// This is the default constructor matching Duration's constructor.
  ///
  /// Example:
  /// ```dart
  /// GcDuration(minutes: 5)  // Default in TanStack Query
  /// GcDuration(seconds: 30)
  /// GcDuration(hours: 1, minutes: 30)
  /// ```
  const GcDuration({
    super.days,
    super.hours,
    super.minutes,
    super.seconds,
    super.milliseconds,
    super.microseconds,
  });

  /// Zero duration - cache is garbage collected immediately when unused
  static const GcDuration zero = GcDuration(seconds: 0);

  /// Cache is never garbage collected.
  ///
  /// Equivalent to TanStack Query's `Infinity` gcTime value.
  /// Useful for data that should persist for the lifetime of the application.
  static const GcDurationInfinity infinity = GcDurationInfinity._();
}

/// Represents infinity - cache is never garbage collected.
class GcDurationInfinity implements GcDurationValue {
  const GcDurationInfinity._();

  @override
  bool operator ==(Object other) => other is GcDurationInfinity;

  @override
  int get hashCode => 0;
}

/// Extension to add comparison operators for GcDurationValue.
extension GcDurationValueComparison on GcDurationValue {
  /// Compares this GcDurationValue to another.
  ///
  /// Returns:
  /// - a negative value if this < other
  /// - zero if this == other
  /// - a positive value if this > other
  ///
  /// GcDurationInfinity is always greater than any GcDuration.
  int compareTo(GcDurationValue other) {
    return switch ((this, other)) {
      (GcDurationInfinity(), GcDurationInfinity()) => 0,
      (GcDurationInfinity(), GcDuration()) => 1,
      (GcDuration(), GcDurationInfinity()) => -1,
      (GcDuration a, GcDuration b) => a.compareTo(b),
    };
  }

  bool operator <(GcDurationValue other) => compareTo(other) < 0;
  bool operator <=(GcDurationValue other) => compareTo(other) <= 0;
  bool operator >(GcDurationValue other) => compareTo(other) > 0;
  bool operator >=(GcDurationValue other) => compareTo(other) >= 0;
}

typedef PlaceholderDataBuilder<TData, TError> = TData? Function(
  TData? previousValue,
  Query<TData, TError>? previousQuery,
);

/// Base class for placeholder data options.
sealed class PlaceholderDataOption<TData, TError> {}

/// Concrete placeholder data value.
class PlaceholderData<TData, TError>
    implements PlaceholderDataOption<TData, TError> {
  const PlaceholderData(this.value);

  final TData value;

  static PlaceholderDataProvider<TData, TError> resolveWith<TData, TError>(
    PlaceholderDataBuilder<TData, TError> callback,
  ) {
    return PlaceholderDataProvider._(callback);
  }
}

/// Placeholder data computed from previous value/query.
class PlaceholderDataProvider<TData, TError>
    implements PlaceholderDataOption<TData, TError> {
  const PlaceholderDataProvider._(this._callback);

  final PlaceholderDataBuilder<TData, TError> _callback;

  TData? resolve(TData? previousValue, Query<TData, TError>? previousQuery) =>
      _callback(previousValue, previousQuery);
}
