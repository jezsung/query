---
sidebar_position: 3
---

# useQueryClient

`useQueryClient` is a hook that returns the `QueryClient` instance from the widget tree. Use it to perform imperative operations like invalidating queries, prefetching data, or accessing cached data.

## Basic Usage

```dart
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_query/flutter_query.dart';

class RefreshButton extends HookWidget {
  const RefreshButton({super.key});

  @override
  Widget build(BuildContext context) {
    final queryClient = useQueryClient();

    return IconButton(
      icon: const Icon(Icons.refresh),
      onPressed: () {
        queryClient.invalidateQueries(['todos']);
      },
    );
  }
}
```

## Signature

```dart
QueryClient useQueryClient()
```

Returns the `QueryClient` provided by the nearest `QueryClientProvider` ancestor.

## Common Operations

### Invalidate Queries

Mark queries as stale and trigger a refetch for active queries:

```dart
final queryClient = useQueryClient();

// Invalidate a specific query
queryClient.invalidateQueries(['user', userId]);

// Invalidate all queries matching a prefix
queryClient.invalidateQueries(['user']);

// Invalidate all queries
queryClient.invalidateQueries([]);
```

### Refetch Queries

Immediately refetch queries without marking them as stale:

```dart
// Refetch specific query
queryClient.refetchQueries(['todos']);

// Refetch all active queries
queryClient.refetchQueries([]);
```

### Prefetch Queries

Fetch and cache data before it's needed:

```dart
// Prefetch user data on hover or navigation
queryClient.prefetchQuery(
  ['user', nextUserId],
  () => fetchUser(nextUserId),
);
```

### Get Cached Data

Access cached data without triggering a fetch:

```dart
final cachedUser = queryClient.getQueryData<User>(['user', userId]);

if (cachedUser != null) {
  // Use cached data
}
```

### Set Cached Data

Manually update the cache:

```dart
// Set data directly
queryClient.setQueryData<User>(
  ['user', userId],
  (old) => updatedUser,
);

// Update existing data
queryClient.setQueryData<List<Todo>>(
  ['todos'],
  (old) => [...?old, newTodo],
);
```

### Cancel Queries

Cancel in-flight requests:

```dart
// Cancel specific query
queryClient.cancelQueries(['user', userId]);

// Cancel all queries matching prefix
queryClient.cancelQueries(['user']);
```

### Fetch Query

Fetch a query imperatively (useful outside of widgets):

```dart
final user = await queryClient.fetchQuery(
  ['user', userId],
  () => fetchUser(userId),
);
```

## Examples

### Invalidate After Mutation

```dart
class AddTodoButton extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final queryClient = useQueryClient();

    final mutation = useMutation<Todo, Exception, String, void>(
      (title, context) => createTodo(title),
      onSuccess: (data, variables, _, context) {
        // Invalidate and refetch the todos list
        queryClient.invalidateQueries(['todos']);
      },
    );

    return ElevatedButton(
      onPressed: () => mutation.mutate('New Todo'),
      child: const Text('Add'),
    );
  }
}
```

### Prefetch on Navigation

```dart
class UserListItem extends HookWidget {
  final String userId;

  const UserListItem({required this.userId});

  @override
  Widget build(BuildContext context) {
    final queryClient = useQueryClient();

    return MouseRegion(
      onEnter: (_) {
        // Prefetch user details on hover
        queryClient.prefetchQuery(
          ['user', userId, 'details'],
          () => fetchUserDetails(userId),
        );
      },
      child: ListTile(
        title: Text('User $userId'),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => UserDetailsPage(userId: userId)),
        ),
      ),
    );
  }
}
```

### Optimistic Update

```dart
class LikeButton extends HookWidget {
  final String postId;

  const LikeButton({required this.postId});

  @override
  Widget build(BuildContext context) {
    final queryClient = useQueryClient();

    final mutation = useMutation<void, Exception, void, Post?>(
      (_, context) => likePost(postId),
      onMutate: (_, context) async {
        await queryClient.cancelQueries(['post', postId]);

        final previousPost = queryClient.getQueryData<Post>(['post', postId]);

        queryClient.setQueryData<Post>(
          ['post', postId],
          (old) => old?.copyWith(likes: (old.likes ?? 0) + 1),
        );

        return previousPost;
      },
      onError: (error, _, previousPost, context) {
        if (previousPost != null) {
          queryClient.setQueryData(['post', postId], (_) => previousPost);
        }
      },
    );

    return IconButton(
      icon: const Icon(Icons.thumb_up),
      onPressed: () => mutation.mutate(null),
    );
  }
}
```

### Clear All Cache

```dart
class LogoutButton extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final queryClient = useQueryClient();

    return ElevatedButton(
      onPressed: () {
        // Clear all cached data on logout
        queryClient.dispose();
        Navigator.pushReplacementNamed(context, '/login');
      },
      child: const Text('Logout'),
    );
  }
}
```

## Alternative: QueryClientProvider.of

If you're not in a `HookWidget`, you can access the `QueryClient` using the provider:

```dart
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final queryClient = QueryClientProvider.of(context);

    return ElevatedButton(
      onPressed: () => queryClient.invalidateQueries(['todos']),
      child: const Text('Refresh'),
    );
  }
}
```

Use `maybeOf` if the provider might not exist:

```dart
final queryClient = QueryClientProvider.maybeOf(context);

if (queryClient != null) {
  // QueryClient is available
}
```

## Tips

:::tip Use in Mutation Callbacks
The `MutationFunctionContext` also provides access to the `QueryClient`:

```dart
useMutation(
  mutationFn,
  onSuccess: (data, variables, _, context) {
    // Access queryClient from context
    context.client.invalidateQueries(['todos']);
  },
);
```
:::

:::tip Prefetch Wisely
Don't prefetch everything—focus on data the user is likely to need soon. Good candidates:
- Detail pages when hovering over list items
- Next page in pagination
- Data for likely navigation paths
:::
