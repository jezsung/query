## Unreleased

- Added `ensureQueryData` method to `QueryClient`. This method returns cached data if available (even if stale) or fetches it if missing. It also supports a `revalidateIfStale` option to trigger a background refetch if the cached data is stale.

## 0.6.0 (2025-02-03)

This release contains breaking changes to improve API consistency and usability.

- Added `useMutationState` hook that returns mutation states from the mutation cache. Useful for tracking mutation progress across your application.

  ```dart
  // Get all mutation states
  final states = useMutationState();

  // Filter by mutation key
  final todoMutations = useMutationState(mutationKey: ['todos']);

  // Filter with predicate (e.g., pending mutations)
  final pending = useMutationState(
    predicate: (key, state) => state.status == MutationStatus.pending,
  );
  ```

- Added `networkMode` option to `useQuery`, `useInfiniteQuery`, and `useMutation` for controlling behavior based on network connectivity. Requires passing a `connectivityChanges` stream to `QueryClient`.
  - `NetworkMode.online` (default): Pauses when offline, resumes when online
  - `NetworkMode.always`: Never pauses, ignores network state
  - `NetworkMode.offlineFirst`: First execution runs regardless of network, retries pause when offline

- Added `useIsFetching` hook that returns the count of queries currently fetching.

- Added `useIsMutating` hook that returns the count of mutations currently pending.

- **BREAKING**: The `mutate` function returned by `useMutation` is now fire-and-forget. It returns `void` and does not throw errors. Use `mutateAsync` to await the result or handle errors directly.

  ```dart
  // Before
  final result = useMutation(...);
  try {
    final data = await result.mutate(variables);
  } catch (e) {
    // handle error
  }

  // After (fire-and-forget)
  result.mutate(variables); // returns void, errors handled via onError callback

  // After (async with error handling)
  try {
    final data = await result.mutateAsync(variables);
  } catch (e) {
    // handle error
  }
  ```

- Added `refetchOnReconnect` option to `useQuery` and `useInfiniteQuery` for controlling refetch behavior when network connectivity is restored. Requires passing a `connectivityChanges` stream to `QueryClient`.

- Added `meta` property to `DefaultQueryOptions` and `DefaultMutationOptions` for setting default metadata across all queries and mutations. This metadata is deep-merged with query/mutation-specific meta and observer meta.

- **BREAKING**: Simplified `getQueryData<TData>()` and `getInfiniteQueryData<TData, TPageParam>()` signatures by removing the `TError` generic type parameter. The error type is not needed when retrieving cached data.

  ```dart
  // Before
  final data = client.getQueryData<String, Error>(const ['key']);
  final infiniteData = client.getInfiniteQueryData<String, Error, int>(const ['key']);

  // After
  final data = client.getQueryData<String>(const ['key']);
  final infiniteData = client.getInfiniteQueryData<String, int>(const ['key']);
  ```

- **BREAKING**: `QueryCache` and `MutationCache` are no longer part of the public API. The `cache` and `mutationCache` constructor parameters have been removed from `QueryClient`. The caches are now created and managed internally.

- **BREAKING**: `Query`, `Mutation`, `QueryObserver`, and `MutationObserver` are no longer part of the public API.

- **BREAKING**: Renamed `InfiniteQueryObserverOptions` to `InfiniteQueryOptions`.

- Fixed gc timer to start after fetch completes rather than at query creation time.

- Added `resetQueries` method on `QueryClient` for resetting queries to their initial state. Unlike `invalidateQueries` (which marks queries as stale), `resetQueries` completely resets the query state - queries with seed data are reset to that seed, while queries without seed have their data cleared. Active queries are automatically refetched after reset.

- Added `removeQueries` method on `QueryClient` for removing queries from the cache. Unlike `invalidateQueries`, removed queries are completely discarded and must be fetched from scratch when accessed again.

- Added `getQueryState` method on `QueryClient` for retrieving the full query state (status, error, dataUpdatedAt, etc.) instead of just the data.

- Added `setQueryData` method on `QueryClient` for imperatively setting or updating cached query data. Useful for optimistic updates in mutation callbacks.

- **BREAKING**: `fetchQuery`, `prefetchQuery`, `fetchInfiniteQuery`, and `prefetchInfiniteQuery` now take `queryKey` and `queryFn` as positional parameters instead of named parameters.

  ```dart
  // Before
  await client.fetchQuery<String, Object>(
    queryKey: const ['users', id],
    queryFn: (context) async => fetchUser(id),
  );

  // After
  await client.fetchQuery<String, Object>(
    const ['users', id],
    (context) async => fetchUser(id),
  );
  ```

- **BREAKING**: Removed `RefetchType` enum. `invalidateQueries()` now only marks queries as stale without automatically refetching. Call `refetchQueries()` separately with a predicate to refetch specific queries.

  ```dart
  // Before
  await client.invalidateQueries(refetchType: RefetchType.active);

  // After
  client.invalidateQueries();
  await client.refetchQueries(predicate: (state) => state.isActive);
  ```

- **BREAKING**: Predicate callbacks now receive immutable `QueryState` and `MutationState` objects instead of `Query` and `Mutation` instances, with the key passed as a separate first parameter.

  ```dart
  // Before
  client.invalidateQueries(predicate: (query) => query.key.first == 'users');

  // After
  client.invalidateQueries(predicate: (key, state) => key.first == 'users');
  ```

- **BREAKING**: `MutationFunctionContext.meta` is now a non-nullable `Map<String, dynamic>` (defaults to an empty map when not provided in options).

- **BREAKING**: The `queryClient` parameter on `useQuery`, `useMutation`, and `useInfiniteQuery` hooks has been renamed to `client` for simplicity.

- **BREAKING**: `QueryClientProvider` API changed. The `client` parameter has been replaced with a `create` factory function. Use `QueryClientProvider.value()` for existing clients.

  ```dart
  // Before
  QueryClientProvider(
    client: queryClient,
    child: MyApp(),
  )

  // After (managed lifecycle)
  QueryClientProvider(
    create: (context) => QueryClient(),
    child: MyApp(),
  )

  // After (existing client)
  QueryClientProvider.value(
    queryClient,
    child: MyApp(),
  )
  ```

- `QueryClientProvider` now supports lazy initialization via the `lazy` parameter
- `QueryClientProvider` now automatically clears the `QueryClient` when removed from the widget tree (when using the default constructor)

## 0.5.1 (2025-01-14)

This release adds support for infinite/paginated queries.

- `useInfiniteQuery` hook for paginated data fetching with automatic page accumulation
- `fetchNextPage` and `fetchPreviousPage` for bidirectional pagination
- `hasNextPage` and `hasPreviousPage` state for pagination controls
- `maxPages` option to limit the number of accumulated pages
- Full support for all standard query options (caching, refetching, retry, etc.)

## 0.4.0 (2025-01-08)

This release aligns the API with TanStack Query v5.

- `useQuery` hook for data fetching with caching, refetching, and cancellation
- `useMutation` hook for mutations with optimistic updates
- `useQueryClient` hook for imperative cache operations
- Client-level default options for queries and mutations

## 0.3.7 and earlier

Legacy codebase. Not maintained.
