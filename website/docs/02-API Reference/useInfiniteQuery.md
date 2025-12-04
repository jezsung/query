---
sidebar_position: 3
---

# useInfiniteQuery

This page documents the implemented behavior of `useInfiniteQuery` in `packages/flutter_query/lib/src/hooks/use_infinite_query.dart`.

> This reference is strictly based on the file implementation — it intentionally excludes features that are not present in the source.

## Signature

```dart
class InfiniteQueryResult<T> extends QueryResult<List<T>> {
  bool isFetchingNextPage;
  Function? fetchNextPage;
  ... QueryResult Properties
}

InfiniteQueryResult<T> useInfiniteQuery<T>({
  required List<Object> queryKey,
  required Future<T?> Function(int pageParam) queryFn,
  bool? enabled,
  required int initialPageParam,
  int Function(T lastResult)? getNextPageParam,
  Duration? debounceTime,
})
```

- Returns: `InfiniteQueryResult<T>` — a specialized `QueryResult<List<T>>` representing a paged list of pages and the fetching state.

## Parameters

- queryKey (required)
  - Type: `List<Object>` — used to compute a cache key via `queryKeyToCacheKey` and to register listeners.

- queryFn (required)
  - Type: `Future<T?> Function(int pageParam)` — the function used to fetch a single page of results. The hook will call it with an integer `pageParam` (page number) and expects either a `T` (page data) or null; non-T values are ignored by the implementation.

- initialPageParam (required)
  - Type: `int` — the page parameter used for the initial (first) fetch page. The hook tracks the currentPage internally (starting from this value) and fetches subsequent pages with `fetchNextPage`.

- getNextPageParam (optional)
  - Type: `int Function(T lastResult)?` — a function that receives the last page's result and should compute/return the next page number. If not provided the currentPage number is used.

- debounceTime (optional)
  - Type: `Duration?` — used to debounce the initial fetch when the hook is mounted: if `debounceTime` is provided and it is not the first request, fetch is delayed by the specified duration. If `debounceTime` is null or this is the first request, the hook fetches immediately.

## Return value — `InfiniteQueryResult<T>`

`InfiniteQueryResult<T>` extends `QueryResult<List<T>>` and includes these additional properties:

- **data**: `List<T>`  
  Array containing all fetched pages.

- **isFetchingNextPage**: `bool`  
  Will be true while fetching the next page with `fetchNextPage`.

- **fetchNextPage**: `(options?: FetchNextPageOptions) => Future<InfiniteQueryResult<T>>`  
  This function allows you to fetch the next "page" of results.