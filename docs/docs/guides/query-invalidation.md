---
sidebar_position: 1
---

# Query Invalidation

Query invalidation marks cached data as stale and optionally triggers a refetch. This is the primary way to update your UI after mutations or when you know data has changed.

## Why Invalidate?

When data changes on the server (through a mutation or external event), your cached data becomes outdated. Invalidation tells Flutter Query to:

1. Mark the cached data as stale
2. Refetch if there are active observers (components using the data)
3. Update the UI with fresh data

## Basic Invalidation

```dart
final queryClient = useQueryClient();

// Invalidate a specific query
queryClient.invalidateQueries(['todos']);

// Invalidate after a mutation
useMutation<Todo, Exception, String, void>(
  (title, context) => createTodo(title),
  onSuccess: (data, variables, _, context) {
    context.client.invalidateQueries(['todos']);
  },
);
```

## Query Key Matching

Invalidation uses prefix matching on query keys:

```dart
// Queries in cache:
// ['user', 1]
// ['user', 1, 'posts']
// ['user', 1, 'comments']
// ['user', 2]
// ['todos']

// Invalidates: ['user', 1], ['user', 1, 'posts'], ['user', 1, 'comments']
queryClient.invalidateQueries(['user', 1]);

// Invalidates: all 'user' queries
queryClient.invalidateQueries(['user']);

// Invalidates: all queries
queryClient.invalidateQueries([]);
```

## Refetch Types

Control which queries are refetched after invalidation:

```dart
// Only refetch active queries (default)
queryClient.invalidateQueries(
  ['todos'],
  refetchType: RefetchType.active,
);

// Refetch all matching queries, including inactive ones
queryClient.invalidateQueries(
  ['todos'],
  refetchType: RefetchType.all,
);

// Mark as stale but don't refetch
queryClient.invalidateQueries(
  ['todos'],
  refetchType: RefetchType.none,
);
```

| RefetchType | Description |
|-------------|-------------|
| `active` | Refetch queries with active observers (default) |
| `inactive` | Refetch queries without active observers |
| `all` | Refetch all matching queries |
| `none` | Mark as stale but don't refetch |

## Common Patterns

### After Create

```dart
useMutation<Todo, Exception, CreateTodoInput, void>(
  (input, context) => createTodo(input),
  onSuccess: (newTodo, variables, _, context) {
    // Invalidate the list to include the new item
    context.client.invalidateQueries(['todos']);
  },
);
```

### After Update

```dart
useMutation<Todo, Exception, UpdateTodoInput, void>(
  (input, context) => updateTodo(input),
  onSuccess: (updatedTodo, variables, _, context) {
    // Invalidate the specific item and the list
    context.client.invalidateQueries(['todo', updatedTodo.id]);
    context.client.invalidateQueries(['todos']);
  },
);
```

### After Delete

```dart
useMutation<void, Exception, String, void>(
  (todoId, context) => deleteTodo(todoId),
  onSuccess: (_, todoId, __, context) {
    // Invalidate the list
    context.client.invalidateQueries(['todos']);
  },
);
```

### Invalidate Related Data

When one action affects multiple queries:

```dart
useMutation<void, Exception, void, void>(
  (_, context) => markAllTodosComplete(),
  onSuccess: (_, __, ___, context) {
    // Invalidate all todo-related queries
    context.client.invalidateQueries(['todos']);
    context.client.invalidateQueries(['todo']);  // All individual todo queries
    context.client.invalidateQueries(['stats']);  // Dashboard stats
  },
);
```

## Invalidation vs Refetch

| Method | Behavior |
|--------|----------|
| `invalidateQueries` | Marks as stale, refetches active queries |
| `refetchQueries` | Immediately refetches without marking stale |

```dart
// Use invalidateQueries when data might have changed
queryClient.invalidateQueries(['todos']);

// Use refetchQueries for forced refresh (e.g., pull-to-refresh)
queryClient.refetchQueries(['todos']);
```

## Invalidation vs Direct Cache Update

You have two options when data changes:

### 1. Invalidate and Refetch

```dart
onSuccess: (data, variables, _, context) {
  context.client.invalidateQueries(['todos']);
}
```

**Pros:**
- Always gets the latest server state
- Simple to implement
- No risk of cache inconsistency

**Cons:**
- Requires a network request
- Brief loading state

### 2. Direct Cache Update

```dart
onSuccess: (data, variables, _, context) {
  context.client.setQueryData<List<Todo>>(
    ['todos'],
    (old) => [...?old, data],
  );
}
```

**Pros:**
- Instant UI update
- No network request

**Cons:**
- Cache might not match server state
- More complex to implement

### Recommended: Combine Both

```dart
onSuccess: (data, variables, _, context) {
  // Update cache immediately for fast UI
  context.client.setQueryData<List<Todo>>(
    ['todos'],
    (old) => [...?old, data],
  );

  // Invalidate to ensure consistency (will refetch in background)
  context.client.invalidateQueries(['todos']);
}
```

## Waiting for Invalidation

`invalidateQueries` returns a `Future` that resolves when all refetches complete:

```dart
onSuccess: (data, variables, _, context) async {
  // Wait for refetch to complete
  await context.client.invalidateQueries(['todos']);

  // Navigate after data is updated
  Navigator.pop(context);
}
```

## Tips

:::tip Invalidate Broadly, Fetch Specifically
It's better to invalidate a broad set of queries than risk stale data:

```dart
// Good: invalidate all user-related data after profile update
queryClient.invalidateQueries(['user', userId]);

// Risky: only invalidating one query might miss related data
queryClient.invalidateQueries(['user', userId, 'profile']);
```
:::

:::tip Use onSettled for Cleanup
Use `onSettled` to invalidate after both success and error:

```dart
useMutation(
  mutationFn,
  onSettled: (data, error, variables, _, context) {
    // Always refetch to ensure consistency
    context.client.invalidateQueries(['todos']);
  },
);
```
:::
