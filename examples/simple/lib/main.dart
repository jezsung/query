import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_query/flutter_query.dart';
import 'package:http/http.dart' as http;
import 'package:simple/repository.dart';

void main() {
  runApp(QueryClientProvider(
    create: (context) => QueryClient(),
    child: const MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Query Simple Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final QueryController<Repository> controller;

  @override
  void initState() {
    super.initState();
    controller = QueryController<Repository>();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simple Example'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: QueryBuilder<Repository>(
            controller: controller,
            id: 'https://api.github.com/repositories/601455511',
            fetcher: (id) async {
              // Uncomment the following line to simulate the loading state long enough
              await Future.delayed(const Duration(seconds: 2));

              final response = await http.get(Uri.parse(id));
              final json = jsonDecode(response.body) as Map<String, dynamic>;
              return Repository.fromJson(json);
            },
            staleDuration: const Duration(seconds: 5),
            builder: (context, state, child) {
              final refetchButton = ElevatedButton(
                style: ElevatedButton.styleFrom(
                  fixedSize: const Size(108, 40),
                ),
                onPressed: state.status.isFetching
                    ? null
                    : () {
                        controller.refetch();
                      },
                child: state.status.isFetching
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(),
                      )
                    : const Text('Refetch'),
              );

              if (state.status.isFailure) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Something went wrong...'),
                    refetchButton,
                  ],
                );
              }

              if (state.hasData) {
                final repo = state.data!;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      repo.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(repo.description, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    IconTheme(
                      data: IconThemeData(color: Colors.grey[600]),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.visibility),
                              const SizedBox(width: 8),
                              Text('${repo.watcherCount}'),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(Icons.call_split),
                              const SizedBox(width: 8),
                              Text('${repo.forkCount}'),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(Icons.star),
                              const SizedBox(width: 8),
                              Text('${repo.starCount}'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    refetchButton,
                  ],
                );
              }

              return const Center(child: CircularProgressIndicator());
            },
          ),
        ),
      ),
    );
  }
}
