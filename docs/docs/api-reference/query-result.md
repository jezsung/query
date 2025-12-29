---
sidebar_position: 3
---

# QueryResult

`QueryResult<TData, TError>` is the return type of `useQuery`. It contains the query data, error state, and status information.

## Properties

### Data Properties

| Property | Type | Description |
|----------|------|-------------|
| `data` | `TData?` | The resolved data, or `null` if not yet loaded or errored. |
| `error` | `TError?` | The error if the query failed, or `null` if successful/loading. |
| `dataUpdatedAt` | `DateTime?` | When the data was last successfully updated. |
| `errorUpdatedAt` | `DateTime?` | When the error was last updated. |
| `dataUpdateCount` | `int` | Number of times data has been updated. |
| `errorUpdateCount` | `int` | Number of times error has been updated. |

### Status Properties

| Property | Type | Description |
|----------|------|-------------|
| `status` | `QueryStatus` | Overall query status. |
| `fetchStatus` | `FetchStatus` | Current fetch status. |

## QueryStatus

The overall status of the query:

| Value | Description |
|-------|-------------|
| `QueryStatus.pending` | No data yet (initial state or after error). |
| `QueryStatus.success` | Data was successfully fetched. |
| `QueryStatus.error` | An error occurred. |

## FetchStatus

The current fetch status:

| Value | Description |
|-------|-------------|
| `FetchStatus.fetching` | Currently fetching data. |
| `FetchStatus.paused` | Fetch is paused (e.g., offline). |
| `FetchStatus.idle` | Not currently fetching. |

## Derived Status Booleans

Convenience getters derived from `status` and `fetchStatus`:

| Property | Condition | Description |
|----------|-----------|-------------|
| `isPending` | `status == pending` | No data available yet. |
| `isSuccess` | `status == success` | Data was fetched successfully. |
| `isError` | `status == error` | An error occurred. |
| `isFetching` | `fetchStatus == fetching` | Currently fetching (initial or background). |
| `isLoading` | `isPending && isFetching` | First load in progress. |
| `isRefetching` | `!isPending && isFetching` | Refetching with existing data. |
| `isLoadingError` | `isError && dataUpdateCount == 0` | Error on initial load. |
| `isRefetchError` | `isError && dataUpdateCount > 0` | Error on refetch (has stale data). |
| `isStale` | computed | Data is considered stale. |
| `isPlaceholderData` | computed | Currently showing placeholder data. |
| `isFetchedAfterMount` | computed | Data was fetched after this observer mounted. |

## Status Matrix

| State | isPending | isSuccess | isError | isFetching | isLoading |
|-------|-----------|-----------|---------|------------|-----------|
| Initial loading | ✓ | | | ✓ | ✓ |
| Success (idle) | | ✓ | | | |
| Success (refetching) | | ✓ | | ✓ | |
| Error (initial) | ✓ | | ✓ | | |
| Error (has stale data) | | | ✓ | | |

## Actions

| Method | Description |
|--------|-------------|
| `refetch()` | Manually trigger a refetch of the query. |

```dart
final result = useQuery(['todos'], fetchTodos);

// Manually refetch
ElevatedButton(
  onPressed: result.refetch,
  child: const Text('Refresh'),
)
```

## Metadata

| Property | Type | Description |
|----------|------|-------------|
| `failureCount` | `int` | Number of consecutive failures. |

## Pattern Matching

`QueryResult` works great with Dart 3 pattern matching:

### Basic Pattern

```dart
Widget build(BuildContext context) {
  final result = useQuery(['todos'], fetchTodos);

  return switch (result) {
    QueryResult(isLoading: true) => const CircularProgressIndicator(),
    QueryResult(:final error?) => Text('Error: $error'),
    QueryResult(:final data?) => TodoList(todos: data),
  };
}
```

### With Status Checks

```dart
return switch (result) {
  // Initial loading
  QueryResult(isLoading: true) => const LoadingSpinner(),

  // Error with no data
  QueryResult(isLoadingError: true, :final error?) => ErrorWidget(error: error),

  // Error but has stale data
  QueryResult(isRefetchError: true, :final data?, :final error?) => Stack(
    children: [
      TodoList(todos: data),
      ErrorBanner(error: error),
    ],
  ),

  // Success (possibly refetching)
  QueryResult(:final data?) => Stack(
    children: [
      TodoList(todos: data),
      if (result.isRefetching) const RefetchingIndicator(),
    ],
  ),
};
```

### With Placeholder Data

```dart
return switch (result) {
  QueryResult(isLoading: true, isPlaceholderData: false) =>
    const LoadingSpinner(),
  QueryResult(:final data?) => TodoList(
    todos: data,
    isPlaceholder: result.isPlaceholderData,
  ),
  QueryResult(:final error?) => ErrorWidget(error: error),
};
```

## Examples

### Show Loading State

```dart
if (result.isLoading) {
  return const CircularProgressIndicator();
}
```

### Show Error

```dart
if (result.isError) {
  return Text('Error: ${result.error}');
}
```

### Access Data Safely

```dart
final data = result.data;
if (data != null) {
  return Text('Count: ${data.length}');
}
```

### Show Refetching Indicator

```dart
Stack(
  children: [
    if (result.data != null) TodoList(todos: result.data!),
    if (result.isRefetching)
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: LinearProgressIndicator(),
      ),
  ],
)
```

### Check Staleness

```dart
if (result.isStale) {
  // Data might be outdated
  showRefreshPrompt();
}
```

### Handle Retry State

```dart
if (result.failureCount > 0 && result.isFetching) {
  return Text('Retrying (attempt ${result.failureCount + 1})...');
}
```

### Track Data Updates

```dart
// First time data is fetched
if (result.dataUpdateCount == 1) {
  analytics.logFirstLoad();
}
```

## Complete Example

```dart
class TodoScreen extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final result = useQuery<List<Todo>, ApiError>(
      ['todos'],
      (context) => fetchTodos(),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Todos'),
        actions: [
          if (result.isRefetching)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: result.refetch,
            ),
        ],
      ),
      body: switch (result) {
        QueryResult(isLoading: true) => const Center(
          child: CircularProgressIndicator(),
        ),

        QueryResult(isLoadingError: true, :final error?) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Failed to load: ${error.message}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: result.refetch,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),

        QueryResult(:final data?) => RefreshIndicator(
          onRefresh: () async => result.refetch(),
          child: ListView.builder(
            itemCount: data.length,
            itemBuilder: (context, index) => TodoTile(todo: data[index]),
          ),
        ),

        _ => const SizedBox.shrink(),
      },
    );
  }
}
```
