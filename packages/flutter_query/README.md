flutter_query — follow the React Query (tanstack v5) for javascript

This package provides a Flutter implementation of the query/cache patterns used by
[tanstack/react-query v5](https://tanstack.com/query/latest/docs/framework/react/overview). It focuses on
fetching, caching, invalidation and background updates while mirroring the high level
concepts and APIs you're used to from React Query.

Key concepts
- QueryClient — the root object that owns the cache and global defaults.
- QueryCache / MutationCache — caches owned by the core that can broadcast errors/success globally.
- useQuery / useInfiniteQuery / useMutation — Flutter hooks to interact with the cache from widgets.

Getting started

Instantiate a basic `QueryClient` for your app. Example:

```dart
// Create a client with default options and cache handlers
final queryClient = QueryClient(
  defaultOptions: const DefaultOptions(
    queries: QueryDefaultOptions(
      enabled: true,
      staleTime: 0,
      refetchOnRestart: false,
      refetchOnReconnect: false,
    ),
  ),
  queryCache: QueryCache(config: QueryCacheConfig(onError: (e) => print(e))),
  mutationCache: MutationCache(config: MutationCacheConfig(onError: (e) => print(e))),
);
```
Example: Queries, Mutations and Invalidation (tanstack style)

This short example demonstrates the three core concepts used by React Query:
Queries, Mutations and Query Invalidation. It uses `useQuery` to fetch todos,
`useMutation` to add a todo, and `QueryClient.instance.invalidateQueries` to
refetch after a successful mutation.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_query/flutter_query.dart';

// Fake API helpers used in the example. Replace with your real networking code.
Future<List<Map<String, dynamic>>> getTodos() async {
  await Future.delayed(Duration(milliseconds: 150));
  return [
    {'id': 1, 'title': 'Buy milk'},
    {'id': 2, 'title': 'Walk dog'},
  ];
}

Future<Map<String, dynamic>> postTodo(Map<String, dynamic> todo) async {
  await Future.delayed(Duration(milliseconds: 150));
  return todo; // in a real app you'd POST and return the created item
}

final queryClient = QueryClient();

void main() {
  runApp(
    QueryClientProvider(
      create: (_) => queryClient,
      child: MaterialApp(home: Todos()),
    ),
  );
}

class Todos extends HookWidget {
  @override
  Widget build(BuildContext context) {
    // Queries
    final todosQuery = useQuery<List<Map<String, dynamic>>>(
      queryKey: ['todos'],
      queryFn: getTodos,
    );

    // Mutations
    final addTodoMutation = useMutation<Map<String, dynamic>, Map<String, dynamic>>(
      postTodo,
      onSuccess: (_) {
        // Invalidate and refetch the todos query after successful mutation
        QueryClient.instance.invalidateQueries(['todos']);
      },
    );

    if (todosQuery.isPending) return const Center(child: Text('Loading...'));
    if (todosQuery.isError) return Center(child: Text('Error: ${todosQuery.error}'));

    final todos = todosQuery.data ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Todos')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: todos.map((t) => ListTile(title: Text(t['title'] ?? ''))).toList(),
              ),
            ),
            ElevatedButton(
              child: const Text('Add Todo'),
              onPressed: () {
                addTodoMutation.mutate({'id': DateTime.now().millisecondsSinceEpoch, 'title': 'Do Laundry'});
              },
            )
          ],
        ),
      ),
    );
  }
}
```

Other useful API notes
- QueryClient.instance is used internally by hooks to find the active client.
- QueryClient provides helper methods like `invalidateQueries` and `clear` to trigger refetches or wipe cache.
- The core `query_core` package contains `DefaultOptions`, `QueryCacheConfig` and `MutationCacheConfig` types.

Further reading
- React Query (tanstack) docs: https://tanstack.com/query/latest/docs
- See the `packages/flutter_query/example` folder for end-to-end examples.

If you'd like, I can add more examples (mutations, optimistic updates, cache manipulation) to this README.
