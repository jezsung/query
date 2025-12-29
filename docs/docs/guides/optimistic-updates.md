---
sidebar_position: 3
---

# Optimistic Updates

Optimistic updates improve perceived performance by updating the UI before the server responds. If the mutation fails, the UI rolls back to the previous state.

## How It Works

1. **onMutate**: Update cache optimistically, save previous state
2. **Mutation runs**: Server processes the request
3. **onSuccess**: Keep the optimistic update (optionally invalidate)
4. **onError**: Rollback to previous state
5. **onSettled**: Refetch to ensure consistency

## Basic Pattern

```dart
class TodoItem extends HookWidget {
  final Todo todo;

  const TodoItem({required this.todo});

  @override
  Widget build(BuildContext context) {
    final queryClient = useQueryClient();

    final toggleMutation = useMutation<Todo, Exception, bool, List<Todo>?>(
      (completed, context) => updateTodo(todo.id, completed: completed),
      onMutate: (completed, context) async {
        // Cancel outgoing refetches
        await queryClient.cancelQueries(['todos']);

        // Snapshot previous value
        final previousTodos = queryClient.getQueryData<List<Todo>>(['todos']);

        // Optimistically update
        queryClient.setQueryData<List<Todo>>(
          ['todos'],
          (old) => old?.map((t) {
            if (t.id == todo.id) {
              return t.copyWith(completed: completed);
            }
            return t;
          }).toList() ?? [],
        );

        // Return snapshot for rollback
        return previousTodos;
      },
      onError: (error, completed, previousTodos, context) {
        // Rollback on error
        if (previousTodos != null) {
          queryClient.setQueryData(['todos'], (_) => previousTodos);
        }
      },
      onSettled: (data, error, completed, previousTodos, context) {
        // Refetch to ensure consistency
        queryClient.invalidateQueries(['todos']);
      },
    );

    return CheckboxListTile(
      value: todo.completed,
      onChanged: (value) => toggleMutation.mutate(value!),
      title: Text(todo.title),
    );
  }
}
```

## Step by Step

### 1. Cancel Outgoing Refetches

Prevent race conditions by cancelling pending requests:

```dart
onMutate: (variables, context) async {
  await queryClient.cancelQueries(['todos']);
  // ...
}
```

### 2. Snapshot Previous State

Save the current cache state for potential rollback:

```dart
onMutate: (variables, context) async {
  // ...
  final previousTodos = queryClient.getQueryData<List<Todo>>(['todos']);
  // ...
  return previousTodos;  // Passed to onError and onSettled
}
```

### 3. Update Cache Optimistically

Apply the expected change immediately:

```dart
onMutate: (variables, context) async {
  // ...
  queryClient.setQueryData<List<Todo>>(
    ['todos'],
    (old) => old?.map((t) {
      if (t.id == todo.id) {
        return t.copyWith(completed: variables);
      }
      return t;
    }).toList() ?? [],
  );
  // ...
}
```

### 4. Handle Errors with Rollback

Restore the previous state if the mutation fails:

```dart
onError: (error, variables, previousTodos, context) {
  if (previousTodos != null) {
    queryClient.setQueryData(['todos'], (_) => previousTodos);
  }
}
```

### 5. Ensure Consistency

Refetch after the mutation completes to sync with the server:

```dart
onSettled: (data, error, variables, previousTodos, context) {
  queryClient.invalidateQueries(['todos']);
}
```

## Common Patterns

### Add Item

```dart
useMutation<Todo, Exception, String, List<Todo>?>(
  (title, context) => createTodo(title),
  onMutate: (title, context) async {
    await queryClient.cancelQueries(['todos']);
    final previousTodos = queryClient.getQueryData<List<Todo>>(['todos']);

    // Add with temporary ID
    queryClient.setQueryData<List<Todo>>(
      ['todos'],
      (old) => [
        ...?old,
        Todo(id: 'temp-${DateTime.now().millisecondsSinceEpoch}', title: title),
      ],
    );

    return previousTodos;
  },
  onError: (error, title, previousTodos, context) {
    if (previousTodos != null) {
      queryClient.setQueryData(['todos'], (_) => previousTodos);
    }
  },
  onSettled: (data, error, title, previousTodos, context) {
    queryClient.invalidateQueries(['todos']);
  },
);
```

### Update Item

```dart
useMutation<Todo, Exception, Todo, List<Todo>?>(
  (updatedTodo, context) => updateTodo(updatedTodo),
  onMutate: (updatedTodo, context) async {
    await queryClient.cancelQueries(['todos']);
    final previousTodos = queryClient.getQueryData<List<Todo>>(['todos']);

    queryClient.setQueryData<List<Todo>>(
      ['todos'],
      (old) => old?.map((t) => t.id == updatedTodo.id ? updatedTodo : t).toList() ?? [],
    );

    return previousTodos;
  },
  onError: (error, updatedTodo, previousTodos, context) {
    if (previousTodos != null) {
      queryClient.setQueryData(['todos'], (_) => previousTodos);
    }
  },
  onSettled: (data, error, updatedTodo, previousTodos, context) {
    queryClient.invalidateQueries(['todos']);
  },
);
```

### Delete Item

```dart
useMutation<void, Exception, String, List<Todo>?>(
  (todoId, context) => deleteTodo(todoId),
  onMutate: (todoId, context) async {
    await queryClient.cancelQueries(['todos']);
    final previousTodos = queryClient.getQueryData<List<Todo>>(['todos']);

    // Remove the item
    queryClient.setQueryData<List<Todo>>(
      ['todos'],
      (old) => old?.where((t) => t.id != todoId).toList() ?? [],
    );

    return previousTodos;
  },
  onError: (error, todoId, previousTodos, context) {
    if (previousTodos != null) {
      queryClient.setQueryData(['todos'], (_) => previousTodos);
    }
  },
  onSettled: (data, error, todoId, previousTodos, context) {
    queryClient.invalidateQueries(['todos']);
  },
);
```

## Updating Multiple Caches

Sometimes you need to update multiple caches optimistically:

```dart
useMutation<Todo, Exception, Todo, ({List<Todo>? todos, Todo? detail})?>(
  (todo, context) => updateTodo(todo),
  onMutate: (todo, context) async {
    await queryClient.cancelQueries(['todos']);
    await queryClient.cancelQueries(['todo', todo.id]);

    final previousTodos = queryClient.getQueryData<List<Todo>>(['todos']);
    final previousDetail = queryClient.getQueryData<Todo>(['todo', todo.id]);

    // Update list
    queryClient.setQueryData<List<Todo>>(
      ['todos'],
      (old) => old?.map((t) => t.id == todo.id ? todo : t).toList() ?? [],
    );

    // Update detail
    queryClient.setQueryData<Todo>(
      ['todo', todo.id],
      (old) => todo,
    );

    return (todos: previousTodos, detail: previousDetail);
  },
  onError: (error, todo, previous, context) {
    if (previous != null) {
      if (previous.todos != null) {
        queryClient.setQueryData(['todos'], (_) => previous.todos);
      }
      if (previous.detail != null) {
        queryClient.setQueryData(['todo', todo.id], (_) => previous.detail);
      }
    }
  },
  onSettled: (data, error, todo, previous, context) {
    queryClient.invalidateQueries(['todos']);
    queryClient.invalidateQueries(['todo', todo.id]);
  },
);
```

## When to Use Optimistic Updates

**Good candidates:**
- Toggle actions (like/unlike, complete/incomplete)
- Simple field updates
- Actions that rarely fail
- Actions where instant feedback matters

**Consider carefully:**
- Complex operations with business logic
- Operations with high failure rates
- Operations where consistency is critical

## Tips

:::tip Show Visual Feedback
Consider showing visual feedback for optimistic updates:

```dart
ListTile(
  title: Text(todo.title),
  // Gray out while mutation is pending
  tileColor: toggleMutation.isPending ? Colors.grey[200] : null,
);
```
:::

:::tip Handle Network Errors Gracefully
Show a toast or snackbar when rollback occurs:

```dart
onError: (error, variables, previousState, context) {
  if (previousState != null) {
    queryClient.setQueryData(['todos'], (_) => previousState);
  }
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Failed to update. Changes reverted.')),
  );
}
```
:::
