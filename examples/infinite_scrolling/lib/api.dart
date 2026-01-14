import 'dart:convert';

import 'package:http/http.dart' as http;

Future<List<Post>> fetchPosts({required int page, required int limit}) async {
  await Future.delayed(const Duration(seconds: 2));
  final uri = Uri.parse(
    'https://jsonplaceholder.typicode.com/posts?_page=${page + 1}&_limit=$limit',
  );
  final response = await http.get(uri);

  if (response.statusCode != 200) {
    throw Exception('Failed to fetch posts');
  }

  return (jsonDecode(response.body) as List)
      .map((json) => Post.fromJson(json))
      .toList();
}

class Post {
  const Post({
    required this.userId,
    required this.id,
    required this.title,
    required this.body,
  });

  final int userId;
  final int id;
  final String title;
  final String body;

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      userId: json['userId'] as int,
      id: json['id'] as int,
      title: json['title'] as String,
      body: json['body'] as String,
    );
  }
}
