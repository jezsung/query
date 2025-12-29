---
sidebar_position: 1
---

# useQuery

`useQuery` is the primary hook for fetching and caching data. It handles loading states, errors, caching, refetching, and more.

## Basic Usage

```dart
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_query/flutter_query.dart';

class UserProfile extends HookWidget {
  final String userId;

  const UserProfile({required this.userId});

  @override
  Widget build(BuildContext context) {
    final result = useQuery<User, Exception>(
      ['user', userId],
      (context) => fetchUser(userId),
    );

    return switch (result) {
      QueryResult(:final data?) => Text(data.name),
      QueryResult(isPending: true) => const CircularProgressIndicator(),
      QueryResult(:final error?) => Text('Error: $error'),
    };
  }
}
```

## Signature

```dart
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
})
```

## Parameters

### Required Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `queryKey` | `List<Object?>` | Unique identifier for this query. Used for caching and invalidation. |
| `queryFn` | `QueryFn<TData>` | Async function that fetches the data. Receives a `QueryFunctionContext`. |

### Optional Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `enabled` | `bool?` | `true` | Whether the query should automatically run. Set to `false` to disable. |
| `staleDuration` | `StaleDuration?` | `StaleDuration.zero` | How long until cached data is considered stale. |
| `gcDuration` | `GcDuration?` | - | How long to keep unused data in cache before garbage collection. |
| `placeholder` | `TData?` | `null` | Data to show while the query is loading (before first fetch). |
| `refetchOnMount` | `RefetchOnMount?` | `stale` | When to refetch on component mount. |
| `refetchOnResume` | `RefetchOnResume?` | `stale` | When to refetch when app resumes from background. |
| `refetchInterval` | `Duration?` | `null` | Interval for automatic refetching. `null` disables. |
| `retry` | `RetryResolver<TError>?` | exponential | Function that determines retry behavior on failure. |
| `retryOnMount` | `bool?` | `true` | Whether to retry failed queries when component remounts. |
| `seed` | `TData?` | `null` | Initial data to populate the cache. |
| `seedUpdatedAt` | `DateTime?` | `null` | Timestamp for the seed data. |
| `meta` | `Map<String, dynamic>?` | `null` | Custom metadata accessible in the query function. |
| `queryClient` | `QueryClient?` | inherited | Override the QueryClient from context. |

## Return Value: QueryResult

The hook returns a `QueryResult<TData, TError>` with the following properties:

### Data & Error

| Property | Type | Description |
|----------|------|-------------|
| `data` | `TData?` | The resolved data, or `null` if not yet loaded or errored. |
| `error` | `TError?` | The error if the query failed, or `null` if successful/loading. |
| `dataUpdatedAt` | `DateTime?` | When the data was last updated. |
| `errorUpdatedAt` | `DateTime?` | When the error was last updated. |

### Status

| Property | Type | Description |
|----------|------|-------------|
| `status` | `QueryStatus` | Overall status: `pending`, `success`, or `error`. |
| `fetchStatus` | `FetchStatus` | Fetch status: `fetching`, `paused`, or `idle`. |

### Derived Status Booleans

| Property | Description |
|----------|-------------|
| `isPending` | `true` if status is `pending` (no data yet). |
| `isSuccess` | `true` if status is `success`. |
| `isError` | `true` if status is `error`. |
| `isFetching` | `true` if currently fetching (initial or background). |
| `isLoading` | `true` if `isPending && isFetching` (first load). |
| `isRefetching` | `true` if fetching but already have data. |
| `isLoadingError` | `true` if error occurred during initial load. |
| `isRefetchError` | `true` if error occurred during refetch. |
| `isStale` | `true` if cached data is stale. |
| `isFetchedAfterMount` | `true` if data was fetched after this observer mounted. |
| `isPlaceholderData` | `true` if currently showing placeholder data. |

### Actions

| Method | Description |
|--------|-------------|
| `refetch()` | Manually trigger a refetch. |

### Metadata

| Property | Type | Description |
|----------|------|-------------|
| `dataUpdateCount` | `int` | Number of times data has been updated. |
| `errorUpdateCount` | `int` | Number of times error has been updated. |
| `failureCount` | `int` | Number of consecutive failures. |

## Query Function Context

The query function receives a `QueryFunctionContext`:

```dart
useQuery(
  ['user', userId],
  (context) async {
    // Access the query key
    final key = context.queryKey;  // ['user', userId]

    // Access the QueryClient
    final client = context.client;

    // Access custom metadata
    final meta = context.meta;

    // Access the abort signal for cancellation
    final signal = context.signal;

    return fetchUser(key[1] as String);
  },
);
```

## Examples

### Basic Query

```dart
final result = useQuery<List<Todo>, Exception>(
  ['todos'],
  (context) async {
    final response = await http.get(Uri.parse('/todos'));
    return parseTodos(response.body);
  },
);
```

### Query with Parameters

```dart
final result = useQuery<User, Exception>(
  ['user', userId],
  (context) => fetchUser(userId),
);
```

### Disabled Query

```dart
final result = useQuery<User, Exception>(
  ['user', userId],
  (context) => fetchUser(userId),
  enabled: userId != null,  // Only fetch when userId is available
);
```

### With Placeholder Data

```dart
final result = useQuery<User, Exception>(
  ['user', userId],
  (context) => fetchUser(userId),
  placeholder: User.empty(),  // Show while loading
);
```

### With Stale Duration

```dart
final result = useQuery<Config, Exception>(
  ['config'],
  (context) => fetchConfig(),
  staleDuration: const StaleDuration(minutes: 30),
);
```

### With Refetch Interval

```dart
final result = useQuery<StockPrice, Exception>(
  ['stock', symbol],
  (context) => fetchStockPrice(symbol),
  refetchInterval: const Duration(seconds: 5),
);
```

### With Custom Retry

```dart
final result = useQuery<Data, ApiError>(
  ['data'],
  (context) => fetchData(),
  retry: (retryCount, error) {
    if (error.statusCode == 404) return null;  // Don't retry 404s
    if (retryCount >= 3) return null;  // Max 3 retries
    return Duration(seconds: retryCount * 2);  // 2s, 4s, 6s
  },
);
```

### With Seed Data

```dart
final result = useQuery<User, Exception>(
  ['user', userId],
  (context) => fetchUser(userId),
  seed: cachedUser,  // Pre-populate from local storage
  seedUpdatedAt: cachedUserTimestamp,
);
```

## Pattern Matching

Dart 3's pattern matching works great with `QueryResult`:

```dart
Widget build(BuildContext context) {
  final result = useQuery(['todos'], fetchTodos);

  return switch (result) {
    // Loading state (first load)
    QueryResult(isLoading: true) => const LoadingSpinner(),

    // Error state
    QueryResult(:final error?) => ErrorWidget(error: error),

    // Success with data
    QueryResult(:final data?) => TodoList(todos: data),
  };
}
```

### With Refetching Indicator

```dart
return switch (result) {
  QueryResult(isLoading: true) => const LoadingSpinner(),
  QueryResult(:final error?, data: null) => ErrorWidget(error: error),
  QueryResult(:final data?) => Stack(
    children: [
      TodoList(todos: data),
      if (result.isRefetching) const RefetchingIndicator(),
    ],
  ),
};
```

## Tips

:::tip Dependent Queries
Use `enabled` to create dependent queries:

```dart
final userResult = useQuery(['user', userId], fetchUser);
final postsResult = useQuery(
  ['posts', userId],
  fetchUserPosts,
  enabled: userResult.data != null,  // Only fetch when user is loaded
);
```
:::

:::tip Prefetching
Prefetch data before it's needed:

```dart
// In a parent widget or on hover
queryClient.prefetchQuery(['user', nextUserId], () => fetchUser(nextUserId));
```
:::
