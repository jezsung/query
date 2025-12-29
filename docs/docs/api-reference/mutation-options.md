---
sidebar_position: 2
---

# Mutation Options

This page documents all configuration options for mutations.

## MutationOptions

Options passed to `useMutation`.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `mutationFn` | `MutationFn<TData, TVariables>` | required | Async function that performs the mutation. |
| `mutationKey` | `List<Object?>` | `null` | Optional key to identify the mutation. |
| `onMutate` | `MutationOnMutate` | `null` | Called before mutation starts. |
| `onSuccess` | `MutationOnSuccess` | `null` | Called when mutation succeeds. |
| `onError` | `MutationOnError` | `null` | Called when mutation fails. |
| `onSettled` | `MutationOnSettled` | `null` | Called when mutation completes (success or error). |
| `retry` | `RetryResolver<TError>` | `retryNever` | Retry logic on failure. |
| `gcDuration` | `GcDuration` | 5 minutes | Duration before garbage collection. |
| `meta` | `Map<String, dynamic>` | `null` | Custom metadata. |
| `queryClient` | `QueryClient` | inherited | Override QueryClient. |

## Callback Types

### onMutate

Called immediately when `mutate()` is invoked, before the mutation starts.

```dart
typedef MutationOnMutate<TVariables, TOnMutateResult> = Future<TOnMutateResult> Function(
  TVariables variables,
  MutationFunctionContext context,
);
```

**Use cases:**
- Optimistic updates
- Cancelling pending refetches
- Storing previous state for rollback

```dart
useMutation<Todo, Exception, String, List<Todo>?>(
  (title, context) => createTodo(title),
  onMutate: (title, context) async {
    // Cancel outgoing refetches
    await context.client.cancelQueries(['todos']);

    // Snapshot previous state
    final previous = context.client.getQueryData<List<Todo>>(['todos']);

    // Optimistic update
    context.client.setQueryData<List<Todo>>(
      ['todos'],
      (old) => [...?old, Todo(id: 'temp', title: title)],
    );

    // Return for use in onError/onSuccess/onSettled
    return previous;
  },
);
```

### onSuccess

Called when the mutation succeeds.

```dart
typedef MutationOnSuccess<TData, TVariables, TOnMutateResult> = void Function(
  TData data,
  TVariables variables,
  TOnMutateResult? onMutateResult,
  MutationFunctionContext context,
);
```

**Parameters:**
- `data`: The result returned by the mutation function
- `variables`: The variables passed to `mutate()`
- `onMutateResult`: The value returned by `onMutate`
- `context`: The mutation context with `client` and `meta`

```dart
useMutation<Todo, Exception, String, void>(
  (title, context) => createTodo(title),
  onSuccess: (newTodo, title, _, context) {
    // Invalidate and refetch
    context.client.invalidateQueries(['todos']);

    // Show success message
    showSnackBar('Created: ${newTodo.title}');
  },
);
```

### onError

Called when the mutation fails.

```dart
typedef MutationOnError<TError, TVariables, TOnMutateResult> = void Function(
  TError error,
  TVariables variables,
  TOnMutateResult? onMutateResult,
  MutationFunctionContext context,
);
```

**Parameters:**
- `error`: The error thrown by the mutation function
- `variables`: The variables passed to `mutate()`
- `onMutateResult`: The value returned by `onMutate` (for rollback)
- `context`: The mutation context

```dart
useMutation<Todo, Exception, String, List<Todo>?>(
  (title, context) => createTodo(title),
  onMutate: (title, context) async {
    // ... optimistic update
    return previousTodos;
  },
  onError: (error, title, previousTodos, context) {
    // Rollback optimistic update
    if (previousTodos != null) {
      context.client.setQueryData(['todos'], (_) => previousTodos);
    }

    // Show error message
    showSnackBar('Failed: ${error.message}');
  },
);
```

### onSettled

Called when the mutation completes, regardless of success or failure.

```dart
typedef MutationOnSettled<TData, TError, TVariables, TOnMutateResult> = void Function(
  TData? data,
  TError? error,
  TVariables variables,
  TOnMutateResult? onMutateResult,
  MutationFunctionContext context,
);
```

**Parameters:**
- `data`: The result if successful, `null` if failed
- `error`: The error if failed, `null` if successful
- `variables`: The variables passed to `mutate()`
- `onMutateResult`: The value returned by `onMutate`
- `context`: The mutation context

```dart
useMutation<Todo, Exception, String, void>(
  (title, context) => createTodo(title),
  onSettled: (data, error, title, _, context) {
    // Always refetch to ensure consistency
    context.client.invalidateQueries(['todos']);

    // Log the result
    if (error != null) {
      logger.error('Create failed', error);
    } else {
      logger.info('Created todo: ${data?.id}');
    }
  },
);
```

## MutationFunctionContext

Context passed to the mutation function and callbacks.

| Property | Type | Description |
|----------|------|-------------|
| `client` | `QueryClient` | The QueryClient instance. |
| `meta` | `Map<String, dynamic>?` | Custom metadata. |
| `mutationKey` | `List<Object?>?` | The mutation key (if provided). |

```dart
useMutation<Todo, Exception, String, void>(
  (title, context) async {
    // Access the client
    final client = context.client;

    // Access metadata
    final source = context.meta?['source'];

    return createTodo(title, source: source);
  },
  meta: {'source': 'quick_add'},
);
```

## DefaultMutationOptions

Default options applied to all mutations.

```dart
final queryClient = QueryClient(
  defaultMutationOptions: DefaultMutationOptions(
    retry: retryNever,                          // Default: no retry
    gcDuration: const GcDuration(minutes: 5),   // Default: 5 minutes
  ),
);
```

| Option | Type | Default |
|--------|------|---------|
| `retry` | `RetryResolver?` | `retryNever` |
| `gcDuration` | `GcDuration?` | 5 minutes |

## Type Parameters

The `useMutation` hook has four type parameters:

```dart
useMutation<TData, TError, TVariables, TOnMutateResult>(...)
```

| Parameter | Description |
|-----------|-------------|
| `TData` | Type of data returned by the mutation. |
| `TError` | Type of error that can occur. |
| `TVariables` | Type of variables passed to `mutate()`. |
| `TOnMutateResult` | Type returned by `onMutate` callback. |

### Examples

```dart
// Create mutation: returns Todo, takes String, no onMutate result
useMutation<Todo, Exception, String, void>(...)

// Update mutation: returns Todo, takes Todo, onMutate returns previous todos
useMutation<Todo, Exception, Todo, List<Todo>?>(...)

// Delete mutation: returns void, takes String id, no onMutate result
useMutation<void, Exception, String, void>(...)

// Complex mutation with multiple previous values
useMutation<
  Order,
  ApiError,
  CreateOrderInput,
  ({List<Order>? orders, User? user})
>(...)
```

## Complete Example

```dart
useMutation<Todo, ApiError, CreateTodoInput, List<Todo>?>(
  (input, context) async {
    final response = await api.post('/todos', body: input.toJson());
    return Todo.fromJson(response.data);
  },
  mutationKey: ['createTodo'],
  onMutate: (input, context) async {
    await context.client.cancelQueries(['todos']);
    final previous = context.client.getQueryData<List<Todo>>(['todos']);
    context.client.setQueryData<List<Todo>>(
      ['todos'],
      (old) => [...?old, Todo.fromInput(input)],
    );
    return previous;
  },
  onSuccess: (todo, input, previous, context) {
    // Update with real data from server
    context.client.setQueryData<List<Todo>>(
      ['todos'],
      (old) => old?.map((t) => t.id == 'temp' ? todo : t).toList() ?? [todo],
    );
  },
  onError: (error, input, previous, context) {
    if (previous != null) {
      context.client.setQueryData(['todos'], (_) => previous);
    }
    showErrorSnackBar(error.message);
  },
  onSettled: (data, error, input, previous, context) {
    context.client.invalidateQueries(['todos']);
  },
  retry: (count, error) {
    if (error.statusCode >= 400 && error.statusCode < 500) return null;
    if (count >= 2) return null;
    return Duration(seconds: count + 1);
  },
  gcDuration: const GcDuration(minutes: 10),
  meta: {'feature': 'todo_list'},
);
```
