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
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const QueryExamplePage(),
                  ),
                );
              },
              child: const Text('Query Example'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MutationExamplePage(),
                  ),
                );
              },
              child: const Text('Mutation Example'),
            ),
          ],
        ),
      ),
    );
  }
}

class QueryExamplePage extends StatefulWidget {
  const QueryExamplePage({super.key});

  @override
  State<QueryExamplePage> createState() => _QueryExamplePageState();
}

class _QueryExamplePageState extends State<QueryExamplePage> {
  late final QueryController<String> _controller;

  @override
  void initState() {
    super.initState();
    _controller = QueryController<String>();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const QueryExample2Page()),
              );
            },
            icon: const Icon(Icons.navigate_next),
          ),
        ],
      ),
      body: Center(
        child: QueryBuilder<String>(
          controller: _controller,
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
                        _controller.fetch();
                        // QueryClientProvider.of(context).refetch('example');
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

class QueryExample2Page extends StatelessWidget {
  const QueryExample2Page({super.key});

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

class MutationExamplePage extends StatefulWidget {
  const MutationExamplePage({super.key});

  @override
  State<MutationExamplePage> createState() => _MutationExamplePageState();
}

class _MutationExamplePageState extends State<MutationExamplePage> {
  late final MutationController<String, void> _controller;

  @override
  void initState() {
    super.initState();
    _controller = MutationController<String, void>(
      mutator: (args) async {
        await Future.delayed(const Duration(seconds: 1));
        // throw 'Mutation Failure';
        return 'Mutation Success!';
      },
      onMutate: (state, args) async {
        debugPrint('OnMutate');
        await Future.delayed(const Duration(seconds: 3));
      },
      onSuccess: (state, args) async {
        debugPrint('OnSuccess');
        await Future.delayed(const Duration(seconds: 3));
      },
      onFailure: (state, args) async {
        debugPrint('OnFailure');
        await Future.delayed(const Duration(seconds: 1));
      },
      onSettled: (state, args) async {
        debugPrint('OnSettled');
        await Future.delayed(const Duration(seconds: 1));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () {
                _controller.mutate();
              },
              child: const Text('Mutate'),
            ),
            MutationBuilder<String, void>(
              controller: _controller,
              mutator: (args) async {
                await Future.delayed(const Duration(seconds: 1));
                return 'Mutation on widget Success!';
              },
              builder: (context, state, child) {
                switch (state.status) {
                  case MutationStatus.idle:
                    return const Text('Idle');
                  case MutationStatus.mutating:
                    return const Text('Mutating');
                  case MutationStatus.success:
                    final String data = state.data as String;
                    return Text(data);
                  case MutationStatus.failure:
                    final String error = state.error as String;
                    return Text(error);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
