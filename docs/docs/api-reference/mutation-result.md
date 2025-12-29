---
sidebar_position: 4
---

# MutationResult

`MutationResult<TData, TError, TVariables, TOnMutateResult>` is the return type of `useMutation`. It contains the mutation state, data, and the `mutate` function to trigger the mutation.

## Properties

### Data Properties

| Property | Type | Description |
|----------|------|-------------|
| `data` | `TData?` | The result data after a successful mutation. |
| `error` | `TError?` | The error if the mutation failed. |
| `variables` | `TVariables?` | The variables passed to the last `mutate()` call. |
| `submittedAt` | `DateTime?` | When the mutation was submitted. |

### Status Properties

| Property | Type | Description |
|----------|------|-------------|
| `status` | `MutationStatus` | Current mutation status. |

## MutationStatus

| Value | Description |
|-------|-------------|
| `MutationStatus.idle` | Mutation has not been triggered yet, or was reset. |
| `MutationStatus.pending` | Mutation is in progress. |
| `MutationStatus.success` | Mutation completed successfully. |
| `MutationStatus.error` | Mutation failed. |

## Status Booleans

| Property | Condition | Description |
|----------|-----------|-------------|
| `isIdle` | `status == idle` | Mutation hasn't been triggered. |
| `isPending` | `status == pending` | Mutation is in progress. |
| `isSuccess` | `status == success` | Mutation succeeded. |
| `isError` | `status == error` | Mutation failed. |
| `isPaused` | computed | Mutation is paused (e.g., offline). |

## Actions

| Method | Description |
|--------|-------------|
| `mutate(variables)` | Trigger the mutation with the given variables. |
| `reset()` | Reset the mutation state to idle. |

## Metadata

| Property | Type | Description |
|----------|------|-------------|
| `failureCount` | `int` | Number of consecutive failures. |
| `failureReason` | `TError?` | The error that caused the last failure. |

## Using mutate()

The `mutate` function triggers the mutation:

```dart
final mutation = useMutation<Todo, Exception, String, void>(
  (title, context) => createTodo(title),
);

// Trigger the mutation
mutation.mutate('Buy groceries');
```

## Using reset()

Reset the mutation state to `idle`:

```dart
final mutation = useMutation<Todo, Exception, String, void>(
  (title, context) => createTodo(title),
);

// After showing success/error message
void handleDismiss() {
  mutation.reset();
}
```

## Pattern Matching

```dart
Widget build(BuildContext context) {
  final mutation = useMutation<Todo, Exception, String, void>(
    (title, context) => createTodo(title),
  );

  return switch (mutation) {
    MutationResult(isIdle: true) => ElevatedButton(
      onPressed: () => mutation.mutate('New Todo'),
      child: const Text('Create'),
    ),

    MutationResult(isPending: true) => const ElevatedButton(
      onPressed: null,
      child: CircularProgressIndicator(),
    ),

    MutationResult(isSuccess: true, :final data?) => Column(
      children: [
        Text('Created: ${data.title}'),
        TextButton(
          onPressed: mutation.reset,
          child: const Text('Create Another'),
        ),
      ],
    ),

    MutationResult(isError: true, :final error?) => Column(
      children: [
        Text('Error: $error'),
        ElevatedButton(
          onPressed: () => mutation.mutate('New Todo'),
          child: const Text('Retry'),
        ),
      ],
    ),
  };
}
```

## Examples

### Basic Button with Loading State

```dart
class CreateTodoButton extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final mutation = useMutation<Todo, Exception, String, void>(
      (title, context) => createTodo(title),
    );

    return ElevatedButton(
      onPressed: mutation.isPending
          ? null
          : () => mutation.mutate('New Todo'),
      child: mutation.isPending
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('Create'),
    );
  }
}
```

### With Success/Error Feedback

```dart
class CreateTodoForm extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final titleController = useTextEditingController();

    final mutation = useMutation<Todo, Exception, String, void>(
      (title, context) => createTodo(title),
      onSuccess: (data, variables, _, context) {
        titleController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Created: ${data.title}')),
        );
      },
    );

    return Column(
      children: [
        TextField(
          controller: titleController,
          enabled: !mutation.isPending,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: mutation.isPending
              ? null
              : () => mutation.mutate(titleController.text),
          child: mutation.isPending
              ? const CircularProgressIndicator()
              : const Text('Create'),
        ),
        if (mutation.isError)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Error: ${mutation.error}',
              style: const TextStyle(color: Colors.red),
            ),
          ),
      ],
    );
  }
}
```

### Access Last Variables

```dart
class DeleteConfirmation extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final mutation = useMutation<void, Exception, String, void>(
      (todoId, context) => deleteTodo(todoId),
    );

    if (mutation.isSuccess) {
      return Text('Deleted todo: ${mutation.variables}');
    }

    return ElevatedButton(
      onPressed: () => mutation.mutate('todo-123'),
      child: const Text('Delete'),
    );
  }
}
```

### Retry on Error

```dart
class RetryableMutation extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final mutation = useMutation<Data, Exception, Input, void>(
      (input, context) => submitData(input),
    );

    return Column(
      children: [
        if (mutation.isError) ...[
          Text('Failed: ${mutation.error}'),
          if (mutation.variables != null)
            ElevatedButton(
              onPressed: () => mutation.mutate(mutation.variables!),
              child: const Text('Retry'),
            ),
        ],
        // ...
      ],
    );
  }
}
```

### Sequential Mutations

```dart
class MultiStepProcess extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final step1 = useMutation<String, Exception, void, void>(
      (_, context) => processStep1(),
    );

    final step2 = useMutation<String, Exception, String, void>(
      (step1Result, context) => processStep2(step1Result),
    );

    Future<void> runProcess() async {
      step1.mutate(null);
      // Note: For sequential mutations, you'd typically
      // use onSuccess callbacks to chain them
    }

    return Column(
      children: [
        Text('Step 1: ${step1.status.name}'),
        Text('Step 2: ${step2.status.name}'),
        ElevatedButton(
          onPressed: step1.isPending || step2.isPending ? null : runProcess,
          child: const Text('Start'),
        ),
      ],
    );
  }
}
```

## Complete Example

```dart
class TodoCreator extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final titleController = useTextEditingController();
    final queryClient = useQueryClient();

    final mutation = useMutation<Todo, ApiError, CreateTodoInput, void>(
      (input, context) async {
        final response = await api.post('/todos', body: input.toJson());
        return Todo.fromJson(response.data);
      },
      onSuccess: (todo, input, _, context) {
        titleController.clear();
        queryClient.invalidateQueries(['todos']);
      },
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: titleController,
              enabled: !mutation.isPending,
              decoration: InputDecoration(
                labelText: 'New Todo',
                errorText: mutation.isError ? mutation.error?.message : null,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: mutation.isPending
                  ? null
                  : () {
                      if (titleController.text.isNotEmpty) {
                        mutation.mutate(
                          CreateTodoInput(title: titleController.text),
                        );
                      }
                    },
              child: mutation.isPending
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Creating...'),
                      ],
                    )
                  : const Text('Create Todo'),
            ),
            if (mutation.isSuccess && mutation.data != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(Icons.check, color: Colors.green),
                    const SizedBox(width: 8),
                    Text('Created: ${mutation.data!.title}'),
                    const Spacer(),
                    TextButton(
                      onPressed: mutation.reset,
                      child: const Text('Dismiss'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```
