import 'package:flutter/material.dart';
import 'package:flutter_query/flutter_query.dart';

void main() {
  runApp(
    QueryScope(
      child: const App(),
    ),
  );
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'futter_query Example',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const Scaffold(),
    );
  }
}
