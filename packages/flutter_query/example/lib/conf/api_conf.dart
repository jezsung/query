import 'dart:async';

import 'package:example/models/check.dart';
import 'package:example/models/pagination.dart';
import 'package:example/models/todo.dart';
import 'package:example/conf/todo_store.dart';
import 'package:flutter/src/foundation/change_notifier.dart';

// ---------------------------------------------------------------------------
// Fake API classes (in-memory) — these mimic your GetEntityApi pattern
// but operate against the `_TodoStore` so the example app works offline.
// ---------------------------------------------------------------------------

class GetTodoApi {
  static const String name = "getTodoApi";

  static Future<Todo> request(int id) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final todo = await TodoStore.getById(id);
    if (todo == null) throw Exception('Todo not found: id=$id');
    return todo;
  }
}

class CreateTodoApi {
  static const String name = "createTodoApi";

  static Future<Todo> request(Todo body) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return await TodoStore.create(body);
  }
}

class CheckTodoApi {
  static const String name = "checkTodoApi";

  static Future<Todo> request(CheckForm checkForm) async {
    await Future.delayed(const Duration(milliseconds: 150));

    final todo = await TodoStore.getById(checkForm.id);
    if (todo == null) throw Exception('Todo not found: id=${checkForm.id}');

    final updated =
        Todo(id: todo.id, title: todo.title, completed: checkForm.check);
    final result = await TodoStore.update(updated);

    if (result == null)
      throw Exception('Failed to update todo: id=${checkForm.id}');
    return result;
  }
}

class UpdateTodoApi {
  static const String name = "updateTodoApi";

  static Future<Todo> request(Todo body) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final updated = await TodoStore.update(body);
    if (updated == null) throw Exception('Todo not found: id=${body.id}');
    return updated;
  }
}

class DeleteTodoApi {
  static const String name = "deleteTodoApi";

  static Future<Todo> request(int id) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final removed = await TodoStore.delete(id);
    if (removed == null) throw Exception('Todo not found: id=$id');
    return removed;
  }
}

class GetAllTodosApi {
  static const String name = "getAllTodosApi";

  /// Get a paginated list of Todos. `page` starts at 1.
  static Future<PaginatedTodos> request(Pagination pagination) async {
    await Future.delayed(const Duration(milliseconds: 500));

    final total = TodoStore.totalCount();
    final items = await TodoStore.getAll(pagination);
    final totalPages = (total / pagination.size).ceil();
    return PaginatedTodos(
        items: items,
        page: pagination.number,
        limit: pagination.size,
        totalCount: total,
        totalPages: totalPages);
  }
}
