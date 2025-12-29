<p align="center">
  <img src="https://raw.githubusercontent.com/jezsung/query/main/assets/logo.svg" alt="flutter_query logo" width="120">
</p>

# flutter_query

[![Pub Version](https://img.shields.io/pub/v/flutter_query)](https://pub.dev/packages/flutter_query)
[![Pub Points](https://img.shields.io/pub/points/flutter_query)](https://pub.dev/packages/flutter_query)
[![Pub Likes](https://img.shields.io/pub/likes/flutter_query)](https://pub.dev/packages/flutter_query)
[![CI](https://github.com/jezsung/query/actions/workflows/ci.yaml/badge.svg)](https://github.com/jezsung/query/actions/workflows/ci.yaml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub Stars](https://img.shields.io/github/stars/jezsung/query)](https://github.com/jezsung/query/stargazers)

A Flutter package inspired by [TanStack Query](https://tanstack.com/query/latest) (formerly React Query). The API aligns with [TanStack Query v5](https://tanstack.com/query/v5/docs/framework/react/overview).

This package uses Flutter Hooks to provide a familiar API for developers coming from TanStack Query.

> **Note:** This package requires `flutter_hooks`.

## Installation

```yaml
dependencies:
  flutter_query: ^0.4.0
  flutter_hooks: ^0.21.3
```

## Quick Start

Wrap your app with `QueryClientProvider`:

```dart
void main() {
  runApp(
    QueryClientProvider(
      child: MyApp(),
    ),
  );
}
```

## useQuery

Use `useQuery` to fetch and cache data. The hook automatically handles loading, error, and success states.

```dart
class TodosWidget extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final result = useQuery<List<Todo>, Exception>(
      ['todos'],
      (context) async {
        final response = await http.get(Uri.parse('/api/todos'));
        return Todo.fromJsonList(response.body);
      },
    );

    if (result.isPending) {
      return CircularProgressIndicator();
    }

    if (result.isError) {
      return Text('Error: ${result.error}');
    }

    return ListView.builder(
      itemCount: result.data!.length,
      itemBuilder: (context, index) => TodoItem(result.data![index]),
    );
  }
}
```

### Query Keys

Query keys uniquely identify your data. Use arrays for hierarchical keys:

```dart
useQuery(['todos'], fetchAllTodos);
useQuery(['todos', todoId], (context) => fetchTodo(todoId));
useQuery(['todos', todoId, 'comments'], (context) => fetchComments(todoId));
```

### Query Options

```dart
useQuery<String, Exception>(
  ['user', userId],
  (context) => fetchUser(userId),
  enabled: isLoggedIn,           // Only fetch when true
  staleDuration: StaleDuration(Duration(minutes: 5)),
  refetchOnMount: RefetchOnMount.stale,
  refetchInterval: Duration(seconds: 30),
  placeholder: cachedUser,       // Show while loading
);
```

### Refetching

```dart
final result = useQuery(['todos'], fetchTodos);

// Manually refetch
await result.refetch();
```

## useMutation

Use `useMutation` for create, update, and delete operations.

```dart
class CreateTodoWidget extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final mutation = useMutation<Todo, Exception, CreateTodoInput, void>(
      (input, context) async {
        final response = await http.post(
          Uri.parse('/api/todos'),
          body: input.toJson(),
        );
        return Todo.fromJson(response.body);
      },
      onSuccess: (data, variables, onMutateResult, context) {
        // Invalidate todos query to refetch
        context.client.invalidateQueries(queryKey: ['todos']);
      },
    );

    return Column(
      children: [
        ElevatedButton(
          onPressed: mutation.isPending
              ? null
              : () => mutation.mutate(CreateTodoInput(title: 'New Todo')),
          child: Text(mutation.isPending ? 'Creating...' : 'Create Todo'),
        ),
        if (mutation.isError) Text('Error: ${mutation.error}'),
        if (mutation.isSuccess) Text('Created: ${mutation.data!.title}'),
      ],
    );
  }
}
```

### Mutation Callbacks

```dart
useMutation<Todo, Exception, CreateTodoInput, PreviousData>(
  (input, context) => createTodo(input),
  onMutate: (variables, context) async {
    // Called before mutation, return value passed to other callbacks
    return previousData;
  },
  onSuccess: (data, variables, onMutateResult, context) {
    // Called on success
  },
  onError: (error, variables, onMutateResult, context) {
    // Called on error
  },
  onSettled: (data, error, variables, onMutateResult, context) {
    // Called on success or error
  },
);
```

## QueryResult Properties

| Property       | Type          | Description                         |
| -------------- | ------------- | ----------------------------------- |
| `data`         | `TData?`      | The resolved data                   |
| `error`        | `TError?`     | The error if one occurred           |
| `status`       | `QueryStatus` | `pending`, `success`, or `error`    |
| `fetchStatus`  | `FetchStatus` | `fetching`, `paused`, or `idle`     |
| `isPending`    | `bool`        | Status is pending                   |
| `isSuccess`    | `bool`        | Status is success                   |
| `isError`      | `bool`        | Status is error                     |
| `isFetching`   | `bool`        | Currently fetching                  |
| `isLoading`    | `bool`        | Pending and fetching (initial load) |
| `isRefetching` | `bool`        | Fetching but not pending            |
| `refetch`      | `Function`    | Manually trigger a refetch          |

## MutationResult Properties

| Property    | Type             | Description                              |
| ----------- | ---------------- | ---------------------------------------- |
| `data`      | `TData?`         | The result data                          |
| `error`     | `TError?`        | The error if one occurred                |
| `status`    | `MutationStatus` | `idle`, `pending`, `success`, or `error` |
| `isIdle`    | `bool`           | Not yet triggered                        |
| `isPending` | `bool`           | Currently executing                      |
| `isSuccess` | `bool`           | Completed successfully                   |
| `isError`   | `bool`           | Resulted in error                        |
| `mutate`    | `Function`       | Trigger the mutation                     |
| `reset`     | `Function`       | Reset to idle state                      |
