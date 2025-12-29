---
sidebar_position: 2
---

# QueryClient API Reference

The `QueryClient` provides methods for imperative cache operations. These are useful for invalidating queries, prefetching data, and manually updating the cache.

## Query Operations

### fetchQuery

Fetches a query and returns the data. If the query is already in the cache and is not stale, returns the cached data without fetching.

```dart
Future<TData> fetchQuery<TData>(
  List<Object?> queryKey,
  QueryFn<TData> queryFn, {
  StaleDuration? staleDuration,
  GcDuration? gcDuration,
  TData? seed,
  DateTime? seedUpdatedAt,
  RetryResolver? retry,
  Map<String, dynamic>? meta,
})
```

**Example:**

```dart
final user = await queryClient.fetchQuery(
  ['user', userId],
  (context) => fetchUser(userId),
);
```

### prefetchQuery

Similar to `fetchQuery`, but doesn't return the data and silently ignores errors. Use for preloading data.

```dart
Future<void> prefetchQuery<TData>(
  List<Object?> queryKey,
  QueryFn<TData> queryFn, {
  StaleDuration? staleDuration,
  GcDuration? gcDuration,
  TData? seed,
  DateTime? seedUpdatedAt,
  RetryResolver? retry,
  Map<String, dynamic>? meta,
})
```

**Example:**

```dart
// Prefetch next page while user is on current page
queryClient.prefetchQuery(
  ['posts', page + 1],
  (context) => fetchPosts(page + 1),
);
```

### getQueryData

Returns the cached data for a query, or `null` if not found.

```dart
TData? getQueryData<TData>(List<Object?> queryKey)
```

**Example:**

```dart
final user = queryClient.getQueryData<User>(['user', userId]);

if (user != null) {
  print('Cached user: ${user.name}');
}
```

### setQueryData

Updates the cached data for a query.

```dart
void setQueryData<TData>(
  List<Object?> queryKey,
  TData Function(TData? old) updater,
)
```

**Example:**

```dart
// Set new data
queryClient.setQueryData<User>(
  ['user', userId],
  (old) => newUser,
);

// Update existing data
queryClient.setQueryData<List<Todo>>(
  ['todos'],
  (old) => [...?old, newTodo],
);

// Remove an item
queryClient.setQueryData<List<Todo>>(
  ['todos'],
  (old) => old?.where((t) => t.id != deletedId).toList() ?? [],
);
```

### invalidateQueries

Marks queries as stale and optionally triggers a refetch. Queries are matched by prefix.

```dart
Future<void> invalidateQueries(
  List<Object?> queryKey, {
  RefetchType refetchType = RefetchType.active,
})
```

**RefetchType values:**

| Value | Description |
|-------|-------------|
| `RefetchType.none` | Mark as stale but don't refetch. |
| `RefetchType.active` | Refetch queries with active observers (default). |
| `RefetchType.inactive` | Refetch queries without active observers. |
| `RefetchType.all` | Refetch all matching queries. |

**Example:**

```dart
// Invalidate and refetch active queries
await queryClient.invalidateQueries(['todos']);

// Invalidate all user-related queries
await queryClient.invalidateQueries(['user', userId]);

// Invalidate but don't refetch
await queryClient.invalidateQueries(
  ['todos'],
  refetchType: RefetchType.none,
);
```

### refetchQueries

Immediately refetches queries without marking them as stale.

```dart
Future<void> refetchQueries(
  List<Object?> queryKey, {
  RefetchType refetchType = RefetchType.active,
})
```

**Example:**

```dart
// Refetch all active queries
await queryClient.refetchQueries([]);

// Refetch specific query
await queryClient.refetchQueries(['todos']);
```

### cancelQueries

Cancels in-flight requests for matching queries.

```dart
Future<void> cancelQueries(List<Object?> queryKey)
```

**Example:**

```dart
// Cancel before making optimistic update
await queryClient.cancelQueries(['todos']);
```

## Cache Access

### queryCache

Access the underlying `QueryCache` for advanced operations:

```dart
final cache = queryClient.queryCache;
```

### mutationCache

Access the underlying `MutationCache`:

```dart
final cache = queryClient.mutationCache;
```

## Lifecycle

### dispose

Clears all caches and cancels all queries. Call when the `QueryClient` is no longer needed.

```dart
void dispose()
```

**Example:**

```dart
@override
void dispose() {
  queryClient.dispose();
  super.dispose();
}
```

## Query Key Matching

All operations that accept a `queryKey` use prefix matching:

```dart
// These queries exist:
// ['user', 1]
// ['user', 1, 'posts']
// ['user', 1, 'comments']
// ['user', 2]
// ['todos']

// Matches: ['user', 1], ['user', 1, 'posts'], ['user', 1, 'comments']
queryClient.invalidateQueries(['user', 1]);

// Matches: ['user', 1, 'posts']
queryClient.invalidateQueries(['user', 1, 'posts']);

// Matches: all 'user' queries
queryClient.invalidateQueries(['user']);

// Matches: all queries
queryClient.invalidateQueries([]);
```

## Complete Examples

### After Create Mutation

```dart
useMutation<Todo, Exception, String, void>(
  (title, context) => createTodo(title),
  onSuccess: (data, variables, _, context) async {
    // Option 1: Invalidate and refetch
    await context.client.invalidateQueries(['todos']);

    // Option 2: Update cache directly
    context.client.setQueryData<List<Todo>>(
      ['todos'],
      (old) => [...?old, data],
    );
  },
);
```

### After Update Mutation

```dart
useMutation<Todo, Exception, Todo, void>(
  (todo, context) => updateTodo(todo),
  onSuccess: (data, variables, _, context) async {
    // Update the specific item in cache
    context.client.setQueryData<Todo>(
      ['todo', data.id],
      (old) => data,
    );

    // Update the list cache
    context.client.setQueryData<List<Todo>>(
      ['todos'],
      (old) => old?.map((t) => t.id == data.id ? data : t).toList() ?? [],
    );
  },
);
```

### After Delete Mutation

```dart
useMutation<void, Exception, String, void>(
  (todoId, context) => deleteTodo(todoId),
  onSuccess: (_, todoId, __, context) {
    // Remove from list cache
    context.client.setQueryData<List<Todo>>(
      ['todos'],
      (old) => old?.where((t) => t.id != todoId).toList() ?? [],
    );
  },
);
```

### Optimistic Update with Rollback

```dart
useMutation<Todo, Exception, Todo, List<Todo>?>(
  (todo, context) => updateTodo(todo),
  onMutate: (todo, context) async {
    // Cancel outgoing refetches
    await context.client.cancelQueries(['todos']);

    // Snapshot previous value
    final previousTodos = context.client.getQueryData<List<Todo>>(['todos']);

    // Optimistically update
    context.client.setQueryData<List<Todo>>(
      ['todos'],
      (old) => old?.map((t) => t.id == todo.id ? todo : t).toList() ?? [],
    );

    return previousTodos;
  },
  onError: (error, todo, previousTodos, context) {
    // Rollback on error
    if (previousTodos != null) {
      context.client.setQueryData(['todos'], (_) => previousTodos);
    }
  },
  onSettled: (data, error, todo, previousTodos, context) {
    // Refetch to ensure consistency
    context.client.invalidateQueries(['todos']);
  },
);
```

### Prefetching on Hover

```dart
class UserCard extends HookWidget {
  final String userId;

  const UserCard({required this.userId});

  @override
  Widget build(BuildContext context) {
    final queryClient = useQueryClient();

    return MouseRegion(
      onEnter: (_) {
        queryClient.prefetchQuery(
          ['user', userId, 'details'],
          (context) => fetchUserDetails(userId),
        );
      },
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserDetailsPage(userId: userId),
          ),
        ),
        child: Card(child: Text('User $userId')),
      ),
    );
  }
}
```
