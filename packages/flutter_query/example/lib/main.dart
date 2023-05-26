import 'package:flutter/material.dart';
import 'package:flutter_query/flutter_query.dart';

void main() {
  runApp(
    QueryClientProvider(
      create: (context) => QueryClient(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fluery Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Placeholder(),
      ),
    );
  }
}
