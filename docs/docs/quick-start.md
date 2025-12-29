---
sidebar_position: 3
---

# Quick Start

This guide walks you through building your first query with Flutter Query. By the end, you'll understand how to fetch data, handle loading and error states, and perform mutations.

## Prerequisites

Make sure you've completed the [Installation](./installation) steps and have a `QueryClientProvider` set up in your app.

## Your First Query

Let's fetch a list of todos from a REST API.

### 1. Create a HookWidget

Flutter Query hooks can only be used inside `HookWidget` or `HookBuilder`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_query/flutter_query.dart';

class TodoList extends HookWidget {
  const TodoList({super.key});

  @override
  Widget build(BuildContext context) {
    // We'll add our query here
    return Container();
  }
}
```

### 2. Add the Query

Use `useQuery` to fetch data. You need to provide:
- A **query key** - a unique identifier for this query
- A **query function** - an async function that fetches the data

```dart
class TodoList extends HookWidget {
  const TodoList({super.key});

  @override
  Widget build(BuildContext context) {
    final result = useQuery<List<Todo>, Exception>(
      ['todos'],  // Query key
      (context) async {
        final response = await http.get(
          Uri.parse('https://api.example.com/todos'),
        );
        final json = jsonDecode(response.body) as List;
        return json.map((e) => Todo.fromJson(e)).toList();
      },
    );

    // We'll handle the result next
    return Container();
  }
}
```

### 3. Handle the Result

The `QueryResult` contains the data, loading state, and any errors. Use Dart 3 pattern matching to handle each state:

```dart
@override
Widget build(BuildContext context) {
  final result = useQuery<List<Todo>, Exception>(
    ['todos'],
    (context) => fetchTodos(),
  );

  return Scaffold(
    appBar: AppBar(title: const Text('Todos')),
    body: switch (result) {
      // Show loading indicator while fetching
      QueryResult(isPending: true) => const Center(
        child: CircularProgressIndicator(),
      ),

      // Show error message if something went wrong
      QueryResult(:final error?) => Center(
        child: Text('Error: ${error.toString()}'),
      ),

      // Show the data when available
      QueryResult(:final data?) => ListView.builder(
        itemCount: data.length,
        itemBuilder: (context, index) => ListTile(
          title: Text(data[index].title),
        ),
      ),
    },
  );
}
```

## Refetching Data

The `QueryResult` includes a `refetch` function to manually refresh the data:

```dart
@override
Widget build(BuildContext context) {
  final result = useQuery<List<Todo>, Exception>(
    ['todos'],
    (context) => fetchTodos(),
  );

  return Scaffold(
    appBar: AppBar(
      title: const Text('Todos'),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: result.refetch,
        ),
      ],
    ),
    body: // ... rest of the UI
  );
}
```

## Your First Mutation

Mutations are used to create, update, or delete data. Use `useMutation` to perform mutations.

```dart
class AddTodoButton extends HookWidget {
  const AddTodoButton({super.key});

  @override
  Widget build(BuildContext context) {
    final queryClient = useQueryClient();

    final mutation = useMutation<Todo, Exception, String, void>(
      (title, context) async {
        final response = await http.post(
          Uri.parse('https://api.example.com/todos'),
          body: jsonEncode({'title': title}),
        );
        return Todo.fromJson(jsonDecode(response.body));
      },
      onSuccess: (data, variables, _, context) {
        // Invalidate the todos query to refetch after adding
        queryClient.invalidateQueries(['todos']);
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

## Query Keys

Query keys identify and cache your queries. They can be simple strings or complex arrays:

```dart
// Simple key
useQuery(['todos'], ...);

// Key with parameters
useQuery(['todos', 'completed'], ...);

// Key with dynamic values
useQuery(['todo', todoId], ...);

// Hierarchical key
useQuery(['user', userId, 'posts'], ...);
```

Queries with different keys are cached separately. Queries with the same key share the cached data.

## Complete Example

Here's a complete example putting it all together:

```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_query/flutter_query.dart';
import 'package:http/http.dart' as http;

void main() {
  final queryClient = QueryClient();

  runApp(
    QueryClientProvider(
      client: queryClient,
      child: const MaterialApp(home: TodoScreen()),
    ),
  );
}

class TodoScreen extends HookWidget {
  const TodoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final result = useQuery<List<Todo>, Exception>(
      ['todos'],
      (context) async {
        final response = await http.get(
          Uri.parse('https://jsonplaceholder.typicode.com/todos'),
        );
        final json = jsonDecode(response.body) as List;
        return json.map((e) => Todo.fromJson(e)).toList();
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Todos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: result.refetch,
          ),
        ],
      ),
      body: switch (result) {
        QueryResult(isPending: true) => const Center(
          child: CircularProgressIndicator(),
        ),
        QueryResult(:final error?) => Center(
          child: Text('Error: $error'),
        ),
        QueryResult(:final data?) => ListView.builder(
          itemCount: data.length,
          itemBuilder: (context, index) => ListTile(
            title: Text(data[index].title),
            leading: Checkbox(
              value: data[index].completed,
              onChanged: null,
            ),
          ),
        ),
      },
    );
  }
}

class Todo {
  final int id;
  final String title;
  final bool completed;

  Todo({required this.id, required this.title, required this.completed});

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'],
      title: json['title'],
      completed: json['completed'],
    );
  }
}
```

## Next Steps

Now that you've built your first query and mutation, explore these topics:

- [Query Keys](./core-concepts/query-keys) - Learn about query key patterns
- [Staleness & Caching](./core-concepts/staleness-caching) - Understand caching behavior
- [useQuery Hook](./hooks/use-query) - Full API reference
- [useMutation Hook](./hooks/use-mutation) - Full mutation API
