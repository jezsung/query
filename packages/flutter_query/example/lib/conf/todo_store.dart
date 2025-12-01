import 'package:example/models/pagination.dart';
import 'package:example/models/todo.dart';

/// In-memory fake store used by the example app. This acts as a tiny
/// "backend" so the example can run without real network requests.
class TodoStore {
  static final List<Todo> _todos = [
    const Todo(id: 1, title: 'Buy milk', completed: false),
    const Todo(id: 2, title: 'Walk the dog', completed: true),
    const Todo(id: 3, title: 'Do laundry', completed: false),
    const Todo(id: 4, title: 'Write example code', completed: false),
    const Todo(id: 5, title: 'Push to repo', completed: true),
    const Todo(id: 6, title: 'Read a book', completed: false),
    const Todo(id: 7, title: 'Call mom', completed: false),
    const Todo(id: 8, title: 'Clean the kitchen', completed: true),
    const Todo(id: 9, title: 'Reply to emails', completed: false),
    const Todo(id: 10, title: 'Plan weekend trip', completed: false),
    const Todo(id: 11, title: 'Finish Flutter tutorial', completed: false),
    const Todo(id: 12, title: 'Update resume', completed: false),
    const Todo(id: 13, title: 'Schedule appointment', completed: false),
    const Todo(id: 14, title: 'Organize workspace', completed: true),
    const Todo(id: 15, title: 'Backup laptop', completed: false),
    const Todo(id: 16, title: 'Pay bills', completed: true),
    const Todo(id: 17, title: 'Water plants', completed: false),
    const Todo(id: 18, title: 'Practice piano', completed: false),
    const Todo(id: 19, title: 'Grocery shopping', completed: false),
    const Todo(id: 20, title: 'Update documentation', completed: false),
  ];

  // next id generator
  static int _nextId = _todos.isEmpty
      ? 1
      : _todos.map((t) => t.id).reduce((a, b) => a > b ? a : b) + 1;

  static Future<Todo?> getById(int id) async {
    for (final t in _todos) {
      if (t.id == id) return t;
    }
    return null;
  }

  static Future<List<Todo>> getAll(Pagination pagination) async {
    final start = (pagination.number - 1) * pagination.size;
    if (start >= _todos.length) return <Todo>[];
    final end = (start + pagination.size).clamp(0, _todos.length);
    final todos = List<Todo>.from(_todos)
      ..sort((a, b) => b.id.compareTo(a.id));
    return todos.sublist(start, end);
  }

  static Future<Todo> create(Todo todo) async {
    final newTodo =
        Todo(id: _nextId++, title: todo.title, completed: todo.completed);
    _todos.add(newTodo);
    return newTodo;
  }

  static Future<Todo?> update(Todo todo) async {
    final idx = _todos.indexWhere((t) => t.id == todo.id);
    if (idx == -1) return null;
    final updated =
        Todo(id: todo.id, title: todo.title, completed: todo.completed);
    _todos[idx] = updated;
    return updated;
  }

  static Future<Todo?> delete(int id) async {
    final idx = _todos.indexWhere((t) => t.id == id);
    if (idx == -1) return null;
    final removed = _todos.removeAt(idx);
    return removed;
  }

  static int totalCount() => _todos.length;
}
