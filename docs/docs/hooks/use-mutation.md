---
sidebar_position: 2
---

# useMutation

`useMutation` is used for creating, updating, or deleting data. Unlike queries, mutations are not automatically executed—you trigger them manually with the `mutate` function.

## Basic Usage

```dart
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_query/flutter_query.dart';

class AddTodoButton extends HookWidget {
  const AddTodoButton({super.key});

  @override
  Widget build(BuildContext context) {
    final mutation = useMutation<Todo, Exception, String, void>(
      (title, context) async {
        final response = await http.post(
          Uri.parse('/todos'),
          body: jsonEncode({'title': title}),
        );
        return Todo.fromJson(jsonDecode(response.body));
      },
    );

    return ElevatedButton(
      onPressed: mutation.isPending
          ? null
          : () => mutation.mutate('New Todo'),
      child: mutation.isPending
          ? const CircularProgressIndicator()
          : const Text('Add Todo'),
    );
  }
}
```

## Signature

```dart
MutationResult<TData, TError, TVariables, TOnMutateResult> useMutation<TData, TError, TVariables, TOnMutateResult>(
  Future<TData> Function(TVariables, MutationFunctionContext) mutationFn, {
  MutationOnMutate<TVariables, TOnMutateResult>? onMutate,
  MutationOnSuccess<TData, TVariables, TOnMutateResult>? onSuccess,
  MutationOnError<TError, TVariables, TOnMutateResult>? onError,
  MutationOnSettled<TData, TError, TVariables, TOnMutateResult>? onSettled,
  List<Object?>? mutationKey,
  RetryResolver<TError>? retry,
  GcDuration? gcDuration,
  Map<String, dynamic>? meta,
  QueryClient? queryClient,
})
```

## Type Parameters

| Parameter | Description |
|-----------|-------------|
| `TData` | The type of data returned by the mutation. |
| `TError` | The type of error that can occur. |
| `TVariables` | The type of variables passed to `mutate()`. |
| `TOnMutateResult` | The type returned by `onMutate` callback (for optimistic updates). |

## Parameters

### Required Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `mutationFn` | `Future<TData> Function(TVariables, MutationFunctionContext)` | Async function that performs the mutation. |

### Optional Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `onMutate` | `MutationOnMutate?` | Called before mutation starts. Return value is passed to other callbacks. |
| `onSuccess` | `MutationOnSuccess?` | Called when mutation succeeds. |
| `onError` | `MutationOnError?` | Called when mutation fails. |
| `onSettled` | `MutationOnSettled?` | Called when mutation completes (success or error). |
| `mutationKey` | `List<Object?>?` | Optional key to identify this mutation. |
| `retry` | `RetryResolver<TError>?` | Retry logic on failure. Default: no retry. |
| `gcDuration` | `GcDuration?` | How long to keep mutation state after completion. |
| `meta` | `Map<String, dynamic>?` | Custom metadata accessible in callbacks. |
| `queryClient` | `QueryClient?` | Override the QueryClient from context. |

## Return Value: MutationResult

The hook returns a `MutationResult<TData, TError, TVariables, TOnMutateResult>`:

### Data & State

| Property | Type | Description |
|----------|------|-------------|
| `data` | `TData?` | The result data after a successful mutation. |
| `error` | `TError?` | The error if the mutation failed. |
| `variables` | `TVariables?` | The variables passed to the last `mutate()` call. |
| `submittedAt` | `DateTime?` | When the mutation was submitted. |
| `status` | `MutationStatus` | Current status: `idle`, `pending`, `success`, or `error`. |

### Status Booleans

| Property | Description |
|----------|-------------|
| `isIdle` | `true` before mutation is triggered. |
| `isPending` | `true` while mutation is in progress. |
| `isSuccess` | `true` if mutation succeeded. |
| `isError` | `true` if mutation failed. |
| `isPaused` | `true` if mutation is paused (e.g., offline). |

### Actions

| Method | Description |
|--------|-------------|
| `mutate(variables)` | Trigger the mutation with the given variables. |
| `reset()` | Reset the mutation state to idle. |

### Metadata

| Property | Type | Description |
|----------|------|-------------|
| `failureCount` | `int` | Number of consecutive failures. |
| `failureReason` | `TError?` | The error that caused the last failure. |

## Callbacks

### onMutate

Called immediately when `mutate()` is triggered, before the mutation starts. Use this for optimistic updates.

```dart
useMutation<Todo, Exception, String, Todo>(
  (title, context) => createTodo(title),
  onMutate: (variables, context) async {
    // Cancel outgoing refetches
    await context.client.cancelQueries(['todos']);

    // Snapshot previous value
    final previousTodos = context.client.getQueryData<List<Todo>>(['todos']);

    // Optimistically update cache
    context.client.setQueryData<List<Todo>>(
      ['todos'],
      (old) => [...?old, Todo(title: variables, id: 'temp')],
    );

    // Return snapshot for rollback
    return previousTodos;
  },
);
```

### onSuccess

Called when the mutation succeeds.

```dart
useMutation<Todo, Exception, String, void>(
  (title, context) => createTodo(title),
  onSuccess: (data, variables, onMutateResult, context) {
    // Invalidate and refetch todos
    context.client.invalidateQueries(['todos']);

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Created: ${data.title}')),
    );
  },
);
```

### onError

Called when the mutation fails. Use this for rollbacks.

```dart
useMutation<Todo, Exception, String, List<Todo>>(
  (title, context) => createTodo(title),
  onMutate: (variables, context) async {
    // ... optimistic update, return previous state
    return previousTodos;
  },
  onError: (error, variables, previousTodos, context) {
    // Rollback to previous state
    if (previousTodos != null) {
      context.client.setQueryData(['todos'], (_) => previousTodos);
    }
  },
);
```

### onSettled

Called when the mutation completes, regardless of success or failure.

```dart
useMutation<Todo, Exception, String, void>(
  (title, context) => createTodo(title),
  onSettled: (data, error, variables, onMutateResult, context) {
    // Always refetch to ensure consistency
    context.client.invalidateQueries(['todos']);
  },
);
```

## Examples

### Simple Mutation

```dart
final mutation = useMutation<void, Exception, String, void>(
  (todoId, context) => deleteTodo(todoId),
);

// Trigger it
mutation.mutate(todoId);
```

### With Invalidation

```dart
final queryClient = useQueryClient();

final mutation = useMutation<Todo, Exception, CreateTodoInput, void>(
  (input, context) => createTodo(input),
  onSuccess: (data, variables, _, context) {
    queryClient.invalidateQueries(['todos']);
  },
);
```

### Update Mutation

```dart
final mutation = useMutation<Todo, Exception, UpdateTodoInput, void>(
  (input, context) async {
    final response = await http.patch(
      Uri.parse('/todos/${input.id}'),
      body: jsonEncode(input.toJson()),
    );
    return Todo.fromJson(jsonDecode(response.body));
  },
  onSuccess: (data, variables, _, context) {
    // Invalidate specific todo and list
    context.client.invalidateQueries(['todo', variables.id]);
    context.client.invalidateQueries(['todos']);
  },
);
```

### Delete Mutation

```dart
final mutation = useMutation<void, Exception, String, void>(
  (todoId, context) async {
    await http.delete(Uri.parse('/todos/$todoId'));
  },
  onSuccess: (_, todoId, __, context) {
    context.client.invalidateQueries(['todos']);
  },
);
```

### With Loading State

```dart
Widget build(BuildContext context) {
  final mutation = useMutation<Todo, Exception, String, void>(
    (title, context) => createTodo(title),
  );

  return Column(
    children: [
      ElevatedButton(
        onPressed: mutation.isPending ? null : () => mutation.mutate('New'),
        child: mutation.isPending
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Create'),
      ),
      if (mutation.isError)
        Text('Error: ${mutation.error}', style: TextStyle(color: Colors.red)),
      if (mutation.isSuccess)
        Text('Created: ${mutation.data?.title}'),
    ],
  );
}
```

### Resetting State

```dart
final mutation = useMutation<Todo, Exception, String, void>(
  (title, context) => createTodo(title),
);

// After showing success/error message, reset
void handleDismiss() {
  mutation.reset();
}
```

## Optimistic Updates Pattern

Here's a complete optimistic update example:

```dart
class TodoList extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final queryClient = useQueryClient();
    final todos = useQuery<List<Todo>, Exception>(['todos'], fetchTodos);

    final addMutation = useMutation<Todo, Exception, String, List<Todo>?>(
      (title, context) => createTodo(title),
      onMutate: (title, context) async {
        // Cancel any outgoing refetches
        await queryClient.cancelQueries(['todos']);

        // Snapshot the previous value
        final previousTodos = queryClient.getQueryData<List<Todo>>(['todos']);

        // Optimistically update
        queryClient.setQueryData<List<Todo>>(
          ['todos'],
          (old) => [...?old, Todo(id: 'temp', title: title)],
        );

        return previousTodos;
      },
      onError: (error, title, previousTodos, context) {
        // Rollback on error
        if (previousTodos != null) {
          queryClient.setQueryData(['todos'], (_) => previousTodos);
        }
      },
      onSettled: (data, error, title, previousTodos, context) {
        // Always refetch after error or success
        queryClient.invalidateQueries(['todos']);
      },
    );

    // ... UI
  }
}
```

## Tips

:::tip Use void for No Variables
If your mutation doesn't need variables, use `void`:

```dart
final mutation = useMutation<void, Exception, void, void>(
  (_, context) => logout(),
);

mutation.mutate(null);  // or use a wrapper function
```
:::

:::tip Mutations Don't Retry by Default
Unlike queries, mutations don't retry automatically. Add retry logic explicitly if needed:

```dart
useMutation(
  mutationFn,
  retry: (count, error) => count < 3 ? Duration(seconds: count) : null,
);
```
:::
