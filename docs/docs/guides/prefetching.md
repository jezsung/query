---
sidebar_position: 2
---

# Prefetching

Prefetching loads data into the cache before it's needed, making navigation feel instant. When a user navigates to a screen with prefetched data, the cached result is shown immediately.

## Basic Prefetching

```dart
final queryClient = useQueryClient();

// Prefetch data
queryClient.prefetchQuery(
  ['user', userId],
  (context) => fetchUser(userId),
);
```

`prefetchQuery` is fire-and-forget—it doesn't return data and silently ignores errors.

## When to Prefetch

### On Hover

Prefetch when users hover over a link or button:

```dart
class UserListItem extends HookWidget {
  final String userId;

  const UserListItem({required this.userId});

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
      child: ListTile(
        title: Text('User $userId'),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserDetailsPage(userId: userId),
          ),
        ),
      ),
    );
  }
}
```

### On Screen Load

Prefetch data for likely next actions:

```dart
class TodoListScreen extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final queryClient = useQueryClient();
    final todos = useQuery(['todos'], fetchTodos);

    // When todos load, prefetch the first few details
    useEffect(() {
      if (todos.data != null) {
        for (final todo in todos.data!.take(3)) {
          queryClient.prefetchQuery(
            ['todo', todo.id],
            (context) => fetchTodoDetails(todo.id),
          );
        }
      }
    }, [todos.data]);

    return // ... UI
  }
}
```

### Pagination - Prefetch Next Page

```dart
class PaginatedList extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final queryClient = useQueryClient();
    final page = useState(1);
    final posts = useQuery(['posts', page.value], () => fetchPosts(page.value));

    // Prefetch next page
    useEffect(() {
      if (posts.data != null && posts.data!.hasNextPage) {
        queryClient.prefetchQuery(
          ['posts', page.value + 1],
          (context) => fetchPosts(page.value + 1),
        );
      }
    }, [posts.data, page.value]);

    return ListView.builder(
      itemCount: posts.data?.items.length ?? 0,
      itemBuilder: (context, index) {
        return ListTile(title: Text(posts.data!.items[index].title));
      },
    );
  }
}
```

### On Navigation Intent

Prefetch during navigation transitions:

```dart
void navigateToUserProfile(BuildContext context, String userId) {
  final queryClient = QueryClientProvider.of(context);

  // Start prefetching immediately
  queryClient.prefetchQuery(
    ['user', userId],
    (context) => fetchUser(userId),
  );

  // Navigate
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => UserProfilePage(userId: userId)),
  );
}
```

## Prefetch vs Fetch

| Method | Returns Data | Handles Errors | Use Case |
|--------|--------------|----------------|----------|
| `prefetchQuery` | No | Silently ignores | Background preloading |
| `fetchQuery` | Yes | Throws | When you need the data |

```dart
// Prefetch - fire and forget
queryClient.prefetchQuery(['user', userId], fetchUser);

// Fetch - get the data
final user = await queryClient.fetchQuery(['user', userId], fetchUser);
```

## With Stale Duration

Prefetched data respects stale duration. If data is already cached and fresh, no request is made:

```dart
queryClient.prefetchQuery(
  ['user', userId],
  (context) => fetchUser(userId),
  staleDuration: const StaleDuration(minutes: 5),
);
```

## Prefetching Multiple Queries

Prefetch several queries in parallel:

```dart
Future<void> prefetchUserData(QueryClient client, String userId) async {
  await Future.wait([
    client.prefetchQuery(['user', userId], (context) => fetchUser(userId)),
    client.prefetchQuery(['user', userId, 'posts'], (context) => fetchUserPosts(userId)),
    client.prefetchQuery(['user', userId, 'followers'], (context) => fetchFollowers(userId)),
  ]);
}
```

## Route-Based Prefetching

Prefetch data for routes before navigation:

```dart
class AppRouter {
  final QueryClient queryClient;

  AppRouter(this.queryClient);

  void prefetchRouteData(String routeName, Map<String, dynamic> params) {
    switch (routeName) {
      case '/user':
        queryClient.prefetchQuery(
          ['user', params['userId']],
          (context) => fetchUser(params['userId']),
        );
        break;
      case '/post':
        queryClient.prefetchQuery(
          ['post', params['postId']],
          (context) => fetchPost(params['postId']),
        );
        break;
    }
  }
}
```

## Tips

:::tip Don't Over-Prefetch
Only prefetch data users are likely to need. Prefetching everything wastes bandwidth and battery:

```dart
// Good: prefetch likely next action
queryClient.prefetchQuery(['user', hoveredUserId], fetchUser);

// Bad: prefetch all users on page load
for (final user in allUsers) {
  queryClient.prefetchQuery(['user', user.id], fetchUser);
}
```
:::

:::tip Combine with Stale Duration
Set appropriate stale durations to avoid unnecessary refetches:

```dart
// User profile doesn't change often
queryClient.prefetchQuery(
  ['user', userId],
  fetchUser,
  staleDuration: const StaleDuration(minutes: 10),
);
```
:::

:::tip Check Before Prefetching
Skip prefetching if data is already cached and fresh:

```dart
final cached = queryClient.getQueryData<User>(['user', userId]);
if (cached == null) {
  queryClient.prefetchQuery(['user', userId], fetchUser);
}
```
:::
