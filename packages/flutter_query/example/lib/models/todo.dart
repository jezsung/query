class Todo {
  final int id;
  final String title;
  final bool completed;

  const Todo({required this.id, required this.title, this.completed = false});

  factory Todo.fromJson(Map<String, dynamic> json) => Todo(
        id: json['id'] as int,
        title: json['title'] as String,
        completed: json['completed'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'completed': completed,
      };
}

class PaginatedTodos {
  final List<Todo> items;
  final int page;
  final int limit;
  final int totalCount;
  final int totalPages;

  const PaginatedTodos(
      {required this.items,
      required this.page,
      required this.limit,
      required this.totalCount,
      required this.totalPages});

  Map<String, dynamic> toJson() => {
        'items': items.map((t) => t.toJson()).toList(),
        'page': page,
        'limit': limit,
        'totalCount': totalCount,
        'totalPages': totalPages,
      };
}