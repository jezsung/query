---
sidebar_position: 5
---

# Request Cancellation

Flutter Query supports cancelling in-flight requests. This is useful for preventing race conditions during optimistic updates and cleaning up when components unmount.

## AbortSignal

The `QueryFunctionContext` includes an `AbortSignal` that triggers when the request should be cancelled:

```dart
useQuery(
  ['user', userId],
  (context) async {
    final signal = context.signal;

    // Check if cancelled before starting
    if (signal.aborted) {
      throw AbortedException();
    }

    final response = await fetchUser(userId);

    // Check if cancelled after fetch
    if (signal.aborted) {
      throw AbortedException();
    }

    return response;
  },
);
```

## When Cancellation Occurs

A query is cancelled when:

1. **New request starts**: A refetch starts while the previous request is still pending
2. **Query is invalidated**: `cancelQueries` or `invalidateQueries` is called
3. **Component unmounts**: The last observer unsubscribes

## Listening to Abort Events

Use `signal.onAbort` to register a callback:

```dart
useQuery(
  ['data'],
  (context) async {
    final controller = StreamController<Data>();

    // Cancel the stream when aborted
    context.signal.onAbort(() {
      controller.close();
    });

    // Set up data stream...
    return controller.stream.first;
  },
);
```

## With HTTP Requests

### Using dio

```dart
useQuery(
  ['user', userId],
  (context) async {
    final cancelToken = CancelToken();

    // Cancel the request when aborted
    context.signal.onAbort(() {
      cancelToken.cancel();
    });

    final response = await dio.get(
      '/users/$userId',
      cancelToken: cancelToken,
    );

    return User.fromJson(response.data);
  },
);
```

### Using http Package

The `http` package doesn't support cancellation directly, but you can check the signal:

```dart
useQuery(
  ['user', userId],
  (context) async {
    if (context.signal.aborted) {
      throw AbortedException();
    }

    final response = await http.get(Uri.parse('/users/$userId'));

    // Check after response (in case cancelled during request)
    if (context.signal.aborted) {
      throw AbortedException();
    }

    return User.fromJson(jsonDecode(response.body));
  },
);
```

## Cancelling Queries Programmatically

### cancelQueries

Cancel specific queries:

```dart
final queryClient = useQueryClient();

// Cancel a specific query
await queryClient.cancelQueries(['user', userId]);

// Cancel all user queries
await queryClient.cancelQueries(['user']);

// Cancel all queries
await queryClient.cancelQueries([]);
```

### During Optimistic Updates

Cancel before making optimistic updates to prevent race conditions:

```dart
useMutation<Todo, Exception, Todo, List<Todo>?>(
  (todo, context) => updateTodo(todo),
  onMutate: (todo, context) async {
    // Cancel any in-flight refetches
    await context.client.cancelQueries(['todos']);

    // Now safe to update cache
    final previousTodos = context.client.getQueryData<List<Todo>>(['todos']);
    context.client.setQueryData<List<Todo>>(
      ['todos'],
      (old) => old?.map((t) => t.id == todo.id ? todo : t).toList() ?? [],
    );

    return previousTodos;
  },
  // ...
);
```

## Race Condition Prevention

Without cancellation, you might encounter race conditions:

```
User types: "flutter"

Request 1: "f" starts
Request 2: "fl" starts
Request 3: "flu" starts
...
Request 7: "flutter" starts

Request 3 completes → UI shows "flu" results
Request 7 completes → UI shows "flutter" results ✓
Request 1 completes → UI shows "f" results ✗ (wrong!)
```

With cancellation, earlier requests are cancelled:

```
User types: "flutter"

Request 1: "f" starts → cancelled
Request 2: "fl" starts → cancelled
...
Request 7: "flutter" starts → completes → UI shows "flutter" ✓
```

## Debounced Queries

For search inputs, combine debouncing with cancellation:

```dart
class SearchWidget extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final searchText = useState('');
    final debouncedText = useDebounced(searchText.value, Duration(milliseconds: 300));

    final result = useQuery(
      ['search', debouncedText],
      (context) async {
        if (debouncedText.isEmpty) return [];

        // Cancellation is automatic when debouncedText changes
        final response = await searchApi(debouncedText);
        return response;
      },
      enabled: debouncedText.isNotEmpty,
    );

    return Column(
      children: [
        TextField(
          onChanged: (value) => searchText.value = value,
        ),
        // ... results
      ],
    );
  }
}
```

## AbortedException

When you detect cancellation, throw `AbortedException`:

```dart
useQuery(
  ['data'],
  (context) async {
    if (context.signal.aborted) {
      throw AbortedException();
    }

    // ... fetch data
  },
);
```

Flutter Query handles `AbortedException` specially—it doesn't count as an error and doesn't trigger error states.

## Best Practices

### Always Check Before Processing

```dart
useQuery(
  ['data'],
  (context) async {
    final data = await fetchData();

    // Check before expensive processing
    if (context.signal.aborted) {
      throw AbortedException();
    }

    final processed = expensiveProcessing(data);
    return processed;
  },
);
```

### Clean Up Resources

```dart
useQuery(
  ['realtime'],
  (context) async {
    final subscription = realtimeService.subscribe();

    context.signal.onAbort(() {
      subscription.cancel();
    });

    return subscription.firstValue;
  },
);
```

### Propagate Cancellation to Sub-Requests

```dart
useQuery(
  ['aggregated'],
  (context) async {
    // Pass signal to helper functions
    final users = await fetchUsers(signal: context.signal);
    final posts = await fetchPosts(signal: context.signal);

    return AggregatedData(users: users, posts: posts);
  },
);

Future<List<User>> fetchUsers({AbortSignal? signal}) async {
  if (signal?.aborted ?? false) {
    throw AbortedException();
  }
  // ... fetch
}
```
