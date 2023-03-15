import 'package:flutter/material.dart';
import 'package:fluery/fluery.dart';

void main() {
  runApp(
    const QueryClientProvider(
      child: MyApp(),
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
      home: const FirstPage(),
    );
  }
}

class FirstPage extends StatelessWidget {
  const FirstPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SecondPage()),
              );
            },
            icon: const Icon(Icons.navigate_next),
          ),
        ],
      ),
      body: Center(
        child: QueryBuilder<String>(
          queryKey: 'example',
          fetcher: (key) async {
            await Future.delayed(const Duration(seconds: 3));
            // throw 'Fetching Failure';
            return 'Fetching Success!';
          },
          staleDuration: const Duration(seconds: 3),
          builder: (context, state, child) {
            switch (state.status) {
              case QueryStatus.idle:
              case QueryStatus.loading:
                return const CircularProgressIndicator();
              case QueryStatus.success:
                final String data = state.data!;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(data),
                    TextButton(
                      onPressed: () {
                        QueryClientProvider.of(context).refetch('example');
                      },
                      child: const Text('Refetch'),
                    ),
                  ],
                );
              case QueryStatus.failure:
                final String error = state.error as String;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(error),
                    TextButton(
                      onPressed: () {
                        QueryClientProvider.of(context).refetch('example');
                      },
                      child: const Text('Refetch'),
                    ),
                  ],
                );
            }
          },
        ),
      ),
    );
  }
}

class SecondPage extends StatelessWidget {
  const SecondPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: QueryBuilder(
          queryKey: 'example',
          fetcher: (key) async {
            await Future.delayed(const Duration(seconds: 3));
            // throw 'Fetching Failure';
            return 'Fetching Success!';
          },
          staleDuration: const Duration(seconds: 10),
          builder: (context, state, child) {
            switch (state.status) {
              case QueryStatus.idle:
              case QueryStatus.loading:
                return const CircularProgressIndicator();
              case QueryStatus.success:
                final String data = state.data!;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(data),
                    TextButton(
                      onPressed: () {
                        QueryClientProvider.of(context).refetch('example');
                      },
                      child: const Text('Refetch'),
                    ),
                  ],
                );
              case QueryStatus.failure:
                final String error = state.error as String;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(error),
                    TextButton(
                      onPressed: () {
                        QueryClientProvider.of(context).refetch('example');
                      },
                      child: const Text('Refetch'),
                    ),
                  ],
                );
            }
          },
        ),
      ),
    );
  }
}
