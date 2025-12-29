---
sidebar_position: 1
---

# Query Keys

Query keys are the foundation of Flutter Query's caching system. They uniquely identify each query and determine how data is cached and shared across your application.

## What is a Query Key?

A query key is a `List<Object?>` that uniquely identifies a query. Flutter Query uses query keys to:

- **Cache data** - Each unique key has its own cache entry
- **Share data** - Components using the same key share the same cached data
- **Invalidate queries** - You can invalidate specific queries or groups of queries by key
- **Deduplicate requests** - Multiple components mounting with the same key share a single request

## Basic Keys

The simplest query key is a list with a single string:

```dart
useQuery(['todos'], ...);
useQuery(['users'], ...);
useQuery(['posts'], ...);
```

## Keys with Parameters

Add parameters to create more specific keys:

```dart
// Fetch a specific user
useQuery(['user', userId], ...);

// Fetch todos with a filter
useQuery(['todos', 'completed'], ...);
useQuery(['todos', 'active'], ...);

// Fetch posts for a specific user
useQuery(['user', userId, 'posts'], ...);
```

## Dynamic Keys

Query keys can include any type that implements proper equality:

```dart
// With numbers
useQuery(['user', 123], ...);

// With enums
useQuery(['todos', TodoStatus.completed], ...);

// With multiple parameters
useQuery(['search', query, page, limit], ...);
```

:::warning
Objects in query keys are compared by value using `DeepCollectionEquality`. Make sure your objects implement proper `==` and `hashCode` if you use them in keys.
:::

## Hierarchical Keys

Structure your keys hierarchically to enable powerful invalidation patterns:

```dart
// User-related queries
['user', userId]                    // User profile
['user', userId, 'posts']           // User's posts
['user', userId, 'posts', postId]   // Specific post
['user', userId, 'comments']        // User's comments

// You can then invalidate all user-related queries:
queryClient.invalidateQueries(['user', userId]);

// Or just the posts:
queryClient.invalidateQueries(['user', userId, 'posts']);
```

## Key Matching

When invalidating or refetching queries, Flutter Query matches keys from the beginning:

```dart
// These queries exist:
// ['user', 1]
// ['user', 1, 'posts']
// ['user', 1, 'comments']
// ['user', 2]

// Invalidates ['user', 1], ['user', 1, 'posts'], ['user', 1, 'comments']
queryClient.invalidateQueries(['user', 1]);

// Invalidates only ['user', 1, 'posts']
queryClient.invalidateQueries(['user', 1, 'posts']);

// Invalidates all user queries
queryClient.invalidateQueries(['user']);
```

## Best Practices

### Use Descriptive Key Prefixes

Start keys with a descriptive resource name:

```dart
// Good
['todos', todoId]
['users', userId]
['posts', postId]

// Avoid
[todoId]
['data', todoId]
```

### Include All Dependencies

Include all values that affect the query result:

```dart
// Good - includes all dependencies
useQuery(
  ['todos', status, sortBy, page],
  (context) => fetchTodos(status: status, sortBy: sortBy, page: page),
);

// Bad - missing dependencies means wrong cache hits
useQuery(
  ['todos'],
  (context) => fetchTodos(status: status, sortBy: sortBy, page: page),
);
```

### Keep Keys Serializable

Use simple, serializable values in keys:

```dart
// Good
['user', userId]
['search', 'flutter', 1, 10]

// Avoid - functions and complex objects
['user', fetchUserCallback]
['search', searchOptions]  // Unless searchOptions has proper equality
```

### Use Constants for Static Keys

For queries without parameters, consider using constants:

```dart
abstract class QueryKeys {
  static const todos = ['todos'];
  static const users = ['users'];
  static List<Object?> user(String id) => ['user', id];
  static List<Object?> userPosts(String userId) => ['user', userId, 'posts'];
}

// Usage
useQuery(QueryKeys.todos, ...);
useQuery(QueryKeys.user(userId), ...);
```

## Accessing the Key in Query Function

The query key is available in the query function through the context:

```dart
useQuery(
  ['user', userId],
  (context) async {
    final key = context.queryKey;  // ['user', userId]
    final id = key[1] as String;   // userId
    return fetchUser(id);
  },
);
```

This is useful for creating reusable query functions:

```dart
Future<User> fetchUser(QueryFunctionContext context) async {
  final userId = context.queryKey[1] as String;
  final response = await http.get(Uri.parse('/users/$userId'));
  return User.fromJson(jsonDecode(response.body));
}

// Can be reused with different keys
useQuery(['user', '1'], fetchUser);
useQuery(['user', '2'], fetchUser);
```
