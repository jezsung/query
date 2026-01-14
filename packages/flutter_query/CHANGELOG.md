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
