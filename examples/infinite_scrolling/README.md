# Infinite Scrolling Example

This example demonstrates how to implement infinite scrolling using the `useInfiniteQuery` hook from `flutter_query` combined with the `infinite_scroll_pagination` package.

## Features

- Fetches posts from JSONPlaceholder API with pagination
- Automatically loads more posts when scrolling near the bottom
- Shows loading indicators during initial load and when fetching more pages
- Handles errors automatically
- Displays end-of-list indicator when all content has been loaded

## Key Concepts

### useInfiniteQuery Hook

```dart
final result = useInfiniteQuery<List<Post>, Exception, int>(
  const ['posts'],
  (context) => fetchPosts(page: context.pageParam, limit: 10),
  initialPageParam: 0,
  nextPageParamBuilder: (data) {
    if (data.pages.last.length < 10) return null;
    return data.pageParams.last + 1;
  },
);
```

### Mapping to PagingState

The `useInfiniteQuery` result maps directly to `PagingState` for use with `PagedListView`:

```dart
PagingState<int, Post>(
  pages: result.pages,
  keys: result.pageParams,
  hasNextPage: result.hasNextPage,
  isLoading: result.isFetchingNextPage,
  error: result.error,
)
```

### PagedListView Integration

```dart
PagedListView<int, Post>.separated(
  state: PagingState<int, Post>(
    pages: result.pages,
    keys: result.pageParams,
    hasNextPage: result.hasNextPage,
    isLoading: result.isFetchingNextPage,
    error: result.error,
  ),
  fetchNextPage: () {
    if (result.isFetchingNextPage) return;
    result.fetchNextPage();
  },
  separatorBuilder: (context, index) => const Divider(height: 1),
  builderDelegate: PagedChildBuilderDelegate(
    itemBuilder: (context, post, index) {
      return ListTile(
        leading: Text('${post.id}'),
        title: Text(post.title),
      );
    },
  ),
)
```

## Running the Example

```bash
cd examples/infinite_scrolling
flutter pub get
flutter run
```
