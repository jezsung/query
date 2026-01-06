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
      child: const MainApp(),
    ),
  );
  queryClient.dispose();
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: Home());
  }
}

class Home extends HookWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    final result = useQuery<Repo, Exception>(
      const ['repo'],
      (context) async {
        final response = await http.get(
          Uri.parse('https://api.github.com/repos/jezsung/query'),
        );

        if (response.statusCode != 200) {
          throw Exception('Failed to fetch repository data');
        }

        return Repo.fromJson(jsonDecode(response.body));
      },
    );

    return Scaffold(
      body: Center(
        child: switch (result) {
          QueryResult(isPending: true) => const Text('Loading...'),
          QueryResult(:final error?) => Text('An error has occurred: $error'),
          QueryResult(:final data?) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (result.isFetching) const Text('Fetching in background...'),

              Text(data.fullName),
              Text(data.description),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('👀 ${data.watchers}'),
                  Text('🍴 ${data.forks}'),
                  Text('✨ ${data.stars}'),
                ],
              ),
            ],
          ),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }
}

class Repo {
  const Repo({
    required this.fullName,
    required this.description,
    required this.watchers,
    required this.forks,
    required this.stars,
  });

  final String fullName;
  final String description;
  final int watchers;
  final int forks;
  final int stars;

  factory Repo.fromJson(Map<String, dynamic> json) {
    return Repo(
      fullName: json['full_name'] as String,
      description: json['description'] as String? ?? '',
      watchers: json['subscribers_count'] as int,
      forks: json['forks_count'] as int,
      stars: json['stargazers_count'] as int,
    );
  }
}
