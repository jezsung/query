This code snippet very briefly illustrates the 3 core concepts of React Query:

- Queries
- Mutations
- Query Invalidation

```dart title="lib/main.dart"
import 'package:flutter/material.dart';
import 'package:flutter_query/flutter_query.dart';

void main() {
  // Create a client with default options and cache handlers
  queryClient = QueryClient(
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

  runApp(const MyApp());
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
    final addTodoMutation = useMutation(
      mutationFn: postTodo,
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