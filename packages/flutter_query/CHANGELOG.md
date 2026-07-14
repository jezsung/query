## 0.11.1 (2026-07-14)

- **Fix:** `invalidateQueries`, `refetchQueries`, and `resetQueries` threw a
  runtime type error (`type '(int, TError) => Duration?' is not a subtype of
  type '((int, dynamic) => Duration?)?'`) when refetching a query whose
  observer had a `retry` resolver with a non-`dynamic` `TError`.

## 0.11.0 (2026-07-12)

- **Breaking:** The `seed` and `seedUpdatedAt` options on `useQuery`,
  `useInfiniteQuery`, `QueryOptions`, `InfiniteQueryOptions`, and the
  `QueryClient` fetch/prefetch/ensure methods now take the sealed types
  `Seed<TData>` and `SeedUpdatedAt`, which add a lazy callback form
  alongside the plain value form.

  Seed application semantics have also changed: a seed (either form) is
  applied only while the query has no data yet.
  Previously, a seed could overwrite data already in the cache — including
  fetched data — when the seed value differed or carried a newer
  `seedUpdatedAt`; now cached data is never overwritten by a seed.

  ```dart
  // Before:
  useQuery(['user'], fetchUser, seed: cachedUser);

  // After:
  useQuery(['user'], fetchUser, seed: Seed.value(cachedUser));

  // Or lazily — invoked only when the query has no data yet; returning
  // null skips seeding:
  useQuery(
    ['user', id],
    fetchUser,
    seed: Seed.lazy(() => client
        .getQueryData<List<User>>(['users'])
        ?.firstWhereOrNull((user) => user.id == id)),
    seedUpdatedAt: SeedUpdatedAt.lazy(
      () => client.getQueryState(['users'])?.dataUpdatedAt,
    ),
  );
  ```

  On Dart 3.12+ the constructors work with dot shorthand:
  `seed: .value(cachedUser)` / `seed: .lazy(() => ...)`.

- **Breaking:** The `placeholder` option on `useQuery`, `useInfiniteQuery`,
  `QueryOptions`, and `InfiniteQueryOptions` now takes the sealed type
  `Placeholder<TData>`, which adds a lazy callback form alongside the plain
  value form.

  ```dart
  // Before:
  useQuery(['user'], fetchUser, placeholder: User.anonymous());

  // After:
  useQuery(['user'], fetchUser, placeholder: Placeholder.value(User.anonymous()));

  // Or lazily — the callback receives the data of the last query the hook
  // had data for (e.g. before the query key changed); returning null shows
  // no placeholder:
  useQuery(
    ['results', page],
    fetchResults,
    placeholder: Placeholder.lazy((previous) => previous),
  );
  ```

  The keep-previous-data pattern shown above is also available as the
  constant `Placeholder.keepPrevious`, which keeps the previous query key's
  data on screen while the new query fetches:

  ```dart
  useQuery(['results', page], fetchResults, placeholder: Placeholder.keepPrevious);
  ```

  On Dart 3.12+ the constructors work with dot shorthand:
  `placeholder: .value(user)` / `placeholder: .keepPrevious`.

  Note: the name `Placeholder` collides with Flutter's `Placeholder` widget.
  In files that use flutter_query's `Placeholder`, import Flutter with
  `import 'package:flutter/material.dart' hide Placeholder;` (or refer to the
  widget through an import prefix).

- **Breaking:** Graduated the sealed snapshot API out of
  `experiments.dart` and made it the main API. `useQuery`,
  `useInfiniteQuery`, and `useMutation` (and their options-object
  counterparts) now return the pattern-matchable `QuerySnapshot`,
  `InfiniteQuerySnapshot`, and `MutationSnapshot` respectively, in place of
  the flat `QueryResult` / `InfiniteQueryResult` / `MutationResult` classes,
  which have been removed along with the `package:flutter_query/experiments.dart`
  entry point.

  ```dart
  // Before:
  import 'package:flutter_query/experiments.dart';
  import 'package:flutter_query/flutter_query.dart'
      hide useQuery, useMutation, useInfiniteQuery;

  // After — a single import:
  import 'package:flutter_query/flutter_query.dart';

  final result = useQuery(['greeting'], fetchGreeting);
  return switch (result) {
    QuerySuccess(:final data) => Text(data),
    QueryPending() => const Text('Loading...'),
    QueryError(:final error) => Text('Error: $error'),
  };
  ```

  A `switch` over a snapshot is checked for exhaustiveness, `data` is
  non-nullable on the success variant, and `error` is non-nullable on the
  error variant.

  Migrating from the flat API: read last-known data via `dataOrNull` (instead
  of `data`); replace `status == QueryStatus.success` with `isSuccess` (and
  likewise `isPending` / `isError`); read a definite `error` by matching the
  `QueryError` variant. Placeholder data now presents as a `QuerySuccess` with
  `isPlaceholder: true`. `refetch()` / `fetchNextPage()` /
  `fetchPreviousPage()` now complete with the corresponding snapshot type.

- Fixed a "`ValueNotifier` used after being disposed" crash when a widget
  observing a query unmounted between a build-phase update and the deferred
  post-frame callback that delivers it — for example, scrolling a list whose
  items share a query key. The deferred write now bails when the observing
  element is no longer mounted. Affects `useQuery`, `useInfiniteQuery`, and
  their `useQueryOptions` / `useInfiniteQueryOptions` forms.

## 0.10.0 (2026-06-25)

- Added an optional `shouldRebuild` parameter to `useQuery` and
  `useInfiniteQuery`. It is a `bool Function(TResult previous, TResult next)` predicate that
  decides, per result update, whether the observing widget rebuilds —
  returning `true` to rebuild or `false` to suppress. When omitted, the
  widget rebuilds on every change, exactly as before.

  ```dart
  // Rebuild only when the data changes; ignore background-fetch flips.
  useQuery(
    ['todos'],
    fetchTodos,
    shouldRebuild: (previous, next) => previous.data != next.data,
  );
  ```

  `previous` is always the last _accepted_ result (the value the widget is
  currently showing), so a suppressed update is invisible to later
  comparisons. `(_, __) => false` subscribes and fetches without ever
  rebuilding. The experimental variants type the predicate over
  `QuerySnapshot` / `InfiniteQuerySnapshot`.

  This mirrors the `shouldRebuild` / `buildWhen` predicates already
  established by `provider` and `flutter_bloc`.

## 0.9.0 (2026-06-24)

- Expanded the experimental, pattern-matchable snapshot API (opt in via
  `import 'package:flutter_query/experiments.dart';`) to cover mutations and
  infinite queries alongside `useQuery`:
  - `useMutation` now returns a `sealed` `MutationSnapshot` with four
    variants matching `MutationStatus` (`MutationIdle`, `MutationPending`,
    `MutationSuccess`, `MutationError`), exposing non-null `variables` on
    every variant except idle.
  - `useInfiniteQuery` now returns a `sealed` `InfiniteQuerySnapshot` with
    `InfiniteQueryPending`, `InfiniteQuerySuccess`, and `InfiniteQueryError`
    variants, with page-level fetch flags on the base class.

  Because the experimental library reuses the canonical hook names, hide them
  when importing it alongside the main library:

  ```dart
  import 'package:flutter_query/flutter_query.dart'
      hide
          useQuery,
          useMutation,
          useInfiniteQuery;
  import 'package:flutter_query/experiments.dart';
  ```

  As part of this work, `QuerySnapshot` now exposes the activity axis via a
  single `fetchStatus` enum, with `isFetching`/`isPaused`/`isIdle` retained
  as derived conveniences. These types remain experimental and may change in
  a future minor release.

## 0.8.0 (2026-06-23)

- Added an experimental, Dart-idiomatic query API, opt in via
  `import 'package:flutter_query/experiments.dart';`. It exposes a `useQuery`
  that returns a `QuerySnapshot`: a `sealed` hierarchy (`QueryPending`,
  `QuerySuccess`, `QueryError`) supporting exhaustive `switch` matching, with
  non-nullable `data`/`error` on the success/error variants and the activity
  axis exposed via `isFetching`/`isPaused`/`isIdle`.

  ```dart
  import 'package:flutter_query/flutter_query.dart' hide useQuery;
  import 'package:flutter_query/experiments.dart';

  final snapshot = useQuery(['user', id], () => fetchUser(id));
  final widget = switch (snapshot) {
    QueryPending() => const CircularProgressIndicator(),
    QuerySuccess(:final data) => Text(data.name),
    QueryError(:final error) => Text('$error'),
  };
  ```

  This API is annotated `@experimental` and may change in a future minor
  release.

## 0.7.0 (2026-03-08)

- Fixed crashes when multiple screens share the same query key ([#40](https://github.com/jezsung/query/issues/40)).

- Added `ensureQueryData` method to `QueryClient`. This method returns cached data if available (even if stale) or fetches it if missing. It also supports a `revalidateIfStale` option to trigger a background refetch if the cached data is stale.

- Exposed `MutateFn` typedef.

- **BREAKING**: Restored `RefetchType` enum. `invalidateQueries()` is now async again and accepts a `refetchType` parameter (defaults to `RefetchType.active`) to control which queries are automatically refetched after invalidation.

  ```dart
  // Invalidate and refetch active queries (default)
  await client.invalidateQueries(queryKey: ['users']);

  // Invalidate without refetching
  client.invalidateQueries(
    queryKey: ['users'],
    refetchType: RefetchType.none,
  );
  ```

## 0.6.0 (2026-02-03)

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

## 0.5.1 (2026-01-14)

This release adds support for infinite/paginated queries.

- `useInfiniteQuery` hook for paginated data fetching with automatic page accumulation
- `fetchNextPage` and `fetchPreviousPage` for bidirectional pagination
- `hasNextPage` and `hasPreviousPage` state for pagination controls
- `maxPages` option to limit the number of accumulated pages
- Full support for all standard query options (caching, refetching, retry, etc.)

## 0.4.0 (2026-01-08)

This release aligns the API with TanStack Query v5.

- `useQuery` hook for data fetching with caching, refetching, and cancellation
- `useMutation` hook for mutations with optimistic updates
- `useQueryClient` hook for imperative cache operations
- Client-level default options for queries and mutations

## 0.3.7 and earlier

Legacy codebase. Not maintained.
