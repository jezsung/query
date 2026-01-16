import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_query/flutter_query.dart';

void main() {
  runApp(
    QueryClientProvider(
      create: (context) => QueryClient(),
      child: MaterialApp(home: Example()),
    ),
  );
}

class Example extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final result = useQuery<String, Exception>(
      const ['greeting'],
      (context) async {
        // Simulate network delay
        await Future.delayed(const Duration(seconds: 3));
        return 'Hello, Flutter Query!';
      },
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Flutter Query Example')),
      body: Center(
        child: switch (result) {
          QueryResult(:final data?) => Text(data),
          QueryResult(isPending: true) => const Text('Loading...'),
          QueryResult(:final error) => Text('Error: $error'),
        },
      ),
    );
  }
}
