---
sidebar_position: 2
---

# useQuery

This page documents the implemented behavior of the Flutter hook `useQuery` as found in `packages/flutter_query/lib/src/hooks/use_query.dart`.

> This reference describes only what the current source code implements. It intentionally excludes features not present in the file.

## Signature

```dart
class QueryResult<T> {
  String key;
  QueryStatus status;
  T? data;
  bool isFetching;
  Object? error;
  bool isError;
  bool isSuccess;
  bool isPending;
}

QueryResult<T> useQuery<T>({
  required Future<T> Function() queryFn,
  required List<Object> queryKey,
  double? staleTime,
  bool? enabled,
  bool? refetchOnRestart,
  bool? refetchOnReconnect,
})
```

- Returns: `QueryResult<T>` — an object representing the current state of the query (status, data, error and fetching flags).

## Overview

`useQuery` is a Flutter Hooks-based hook that:

- Reads and writes a shared in-memory cache (`cacheQuery`) keyed by a string key produced from `queryKey`.
- Returns a `QueryResult<T>` describing the current state of the query (pending / success / error) and whether it is fetching.
- Starts a fetch when needed and notifies the shared cache & registered listeners through `QueryClient.instance`.

This implementation expects a `QueryClient` (with a shared `QueryClient.instance`) and `QueryCacheListener` logic to be present in the core package.

## Parameters

- queryFn (required)
  - Type: `Future<T> Function()`
  - The asynchronous function used to fetch query data. Must return a `Future` that resolves with the data or throws on error.

- queryKey (required)
  - Type: `List<Object>`
  - The query key which will be converted to a string cache key by `queryKeyToCacheKey`. The hook will read/update the cache entry for this key and will register a listener for updates on this key.

- staleTime (optional)
  - Type: `double?`
  - Used when the hook is running its first fetch and there is an existing cache entry. If `staleTime == double.infinity`, the hook skips the staleness check. Otherwise, a null `staleTime` is treated as `0`.

- enabled (optional)
  - Type: `bool?`
  - If set to `false`, the hook does not start nor subscribe to any fetch logic. When `enabled` is null, the hook falls back to `QueryClient.instance.defaultOptions.queries.enabled`.

- refetchOnRestart / refetchOnReconnect (optional)
  - Type: `bool?`
  - Registered on the created `QueryCacheListener` and used by `QueryClient` when lifecycle events happen.

## Return value — `QueryResult<T>`

`useQuery` returns a `QueryResult<T>` object for the given `queryKey` with the following properties:

- `data: TData`  
    The last successfully resolved data for the query. Defaults to `undefined`.

- `error: null | TError`  
    The error object for the query, if an error was thrown. Defaults to `null`.

- `isFetching: boolean`  
    A derived boolean from the fetch status, provided for convenience.

- `status: QueryStatus`  
    Indicates the current state of the query:
    - `pending`: No cached data and no query attempt finished yet.
    - `error`: The query attempt resulted in an error. The `error` property contains the error received.
    - `success`: The query received a response with no errors and is ready to display its data. The `data` property contains the data from the successful fetch, or if the query's `enabled` property is set to `false` and has not been fetched yet, `data` is the initial value supplied on initialization.

- `isPending: boolean`  
    A derived boolean from the `status` variable, provided for convenience.

- `isSuccess: boolean`  
    A derived boolean from the `status` variable, provided for convenience.

- `isError: boolean`  
    A derived boolean from the `status` variable, provided for convenience.

## Small example (UI)

```dart
  final todos = useQuery<List<Todo>>(
    queryFn: () async => await fetchTodos(),
    queryKey: ['todos'],
  );

  if (todos.isFetching && todos.data == null) return CircularProgressIndicator();
  if (todos.isError) return Text('Error');

  return ListView(
    children: todos.data!.map((t) => Text(t.title)).toList(),
  );
```
