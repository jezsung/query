## 0.6.0 (2025-01-18)

This release contains breaking changes to improve API consistency and usability.

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
