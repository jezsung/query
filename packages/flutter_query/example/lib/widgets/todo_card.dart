import 'package:example/models/check.dart';
import 'package:example/models/todo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_query/flutter_query.dart';
import 'package:example/conf/api_conf.dart';

/// A reusable card widget representing a single Todo item.
///
/// - Shows the title and id of the todo
/// - Displays and controls a checkbox for completion state
/// - Calls [onTap] when the card is tapped
/// - Calls [onChanged] when the checkbox is toggled
class TodoCard extends HookWidget {
  final Todo todo;

  const TodoCard({
    super.key,
    required this.todo,
  });

  @override
  Widget build(BuildContext context) {
    final check = useState<bool>(todo.completed);

    // mutation hooks for editing and deleting todos
    final editMutation = useMutation<Todo, Todo>(
      mutationFn: (Todo body) => UpdateTodoApi.request(body),
      onSuccess: (deleted) {
        // Invalidate the todos query to refetch the updated list
        QueryClient.instance.invalidateQueries(["Infinite", GetAllTodosApi.name]);
        QueryClient.instance.invalidateQueries(["Classical", GetAllTodosApi.name]);
      },
    );

    final deleteMutation = useMutation<Todo, int>(
      mutationFn: (int id) => DeleteTodoApi.request(id),
      onSuccess: (deleted) {
        // Invalidate the todos query to refetch the updated list
        QueryClient.instance.invalidateQueries(["Infinite", GetAllTodosApi.name]);
        QueryClient.instance.invalidateQueries(["Classical", GetAllTodosApi.name]);
      },
    );

    final checkTodoMutation = useMutation(
      mutationFn: (CheckForm checkForm) => CheckTodoApi.request(checkForm),
    );

    void onCardTap(int id, bool check) {
      checkTodoMutation.mutate(CheckForm(id: id, check: check));
    }

    final editingController = useTextEditingController(text: todo.title);

    return Dismissible(
      key: ValueKey('todo-${todo.id}'),
      confirmDismiss: (direction) async {
        // startToEnd -> edit; endToStart -> delete
        if (direction == DismissDirection.startToEnd) {
          // Show edit dialog
          editingController.text = todo.title;
          await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Edit Todo'),
              content: TextField(controller: editingController, decoration: const InputDecoration(labelText: 'Title')),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    final newTitle = editingController.text.trim();
                    if (newTitle.isEmpty) return;
                    // call edit mutation
                    editMutation.mutate(Todo(id: todo.id, title: newTitle, completed: todo.completed));
                    Navigator.of(ctx).pop(true);
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          );

          // we don't actually want to dismiss the item when editing - return false
          return false;
        } else if (direction == DismissDirection.endToStart) {
          // Confirm delete
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Delete Todo'),
              content: const Text('Are you sure you want to delete this todo?'),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
              ],
            ),
          );

          if (confirm == true) {
            deleteMutation.mutate(todo.id);
            // allow the Dismissible to remove the item immediately; query invalidation will refetch
            return true;
          }
          return false;
        }

        return false;
      },
      background: Container(
        decoration: BoxDecoration(color: Colors.blue[600], borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 16),
        child: Row(mainAxisSize: MainAxisSize.min, children: const [
          Icon(Icons.edit, color: Colors.white),
          SizedBox(width: 8),
          Text('Edit', style: TextStyle(color: Colors.white))
        ]),
      ),
      secondaryBackground: Container(
        decoration: BoxDecoration(color: Colors.red[600], borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: Row(mainAxisSize: MainAxisSize.min, children: const [
          Text('Delete', style: TextStyle(color: Colors.white)),
          SizedBox(width: 8),
          Icon(Icons.delete, color: Colors.white)
        ]),
      ),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(todo.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text('ID: ${todo.id} • Completed: ${todo.completed ? 'Yes' : 'No'}',
                        style: const TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Checkbox(
                  value: check.value,
                  onChanged: (value) {
                    check.value = value ?? false;
                    onCardTap(todo.id, check.value);
                  }),
            ],
          ),
        ),
      ),
    );
  }
}
