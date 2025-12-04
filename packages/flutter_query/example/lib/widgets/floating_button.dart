import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_query/flutter_query.dart';
import 'package:example/conf/api_conf.dart';
import 'package:example/models/todo.dart';

/// Reusable floating ``+`` button that shows a dialog with a single text field.
///
/// Use [onCreate] to receive the entered title when the user confirms.
class FloatingButton extends HookWidget {
  const FloatingButton({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = useTextEditingController();

    final addTodoMutation = useMutation(
      mutationFn: (Todo body) => CreateTodoApi.request(body),
      onSuccess: (created) {
        // invalidate the todos list so it refetches with the new item
        QueryClient.instance.invalidateQueries(queryKey: ["Infinite", GetAllTodosApi.name]);
        QueryClient.instance.invalidateQueries(queryKey: ["Classical", GetAllTodosApi.name]);
      },
    );

    return FloatingActionButton(
      tooltip: 'Add todo',
      child: const Icon(Icons.add),
      onPressed: () async {
        controller.text = '';
        await showDialog<void>(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: const Text('Create Todo'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(labelText: 'Title'),
                    autofocus: true,
                    onSubmitted: (_) async {
                      final text = controller.text.trim();
                      if (text.isEmpty) return;
                      // call the internal mutation on submit
                      addTodoMutation.mutate(Todo(id: 0, title: text, completed: false));
                      Navigator.of(ctx).pop();
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
                ElevatedButton(
                    onPressed: () async {
                      final title = controller.text.trim();
                      if (title.isEmpty) return;
                      // mutate here — backend/store will assign the id
                      addTodoMutation.mutate(Todo(id: 0, title: title, completed: false));
                      Navigator.of(ctx).pop();
                    },
                    child: const Text('Confirm'))
              ],
            );
          },
        );
      },
    );
  }
}
