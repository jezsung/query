import 'package:flutter/material.dart';
import 'package:fluery/fluery.dart';

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
            // ElevatedButton(
            //   onPressed: () {
            //     Navigator.push(
            //       context,
            //       MaterialPageRoute(
            //         builder: (context) => const InfiniteQueryExamplePage(),
            //       ),
            //     );
            //   },
            //   child: const Text('Infinite Query Example'),
            // ),
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
          id: 'example',
          fetcher: (key) async {
            await Future.delayed(const Duration(seconds: 3));
            // throw 'Fetching Failure';
            return 'Fetching Success!';
          },
          enabled: true,
          staleDuration: const Duration(seconds: 0),
          refetchOnInit: RefetchMode.stale,
          builder: (context, state, child) {
            switch (state.status) {
              case QueryStatus.idle:
              case QueryStatus.canceled:
                if (state.hasData) {
                  return Text(state.data!);
                }
                return const Text('idle');
              case QueryStatus.fetching:
                if (state.hasData) {
                  return Text(state.data!);
                }
                return const CircularProgressIndicator();
              case QueryStatus.retrying:
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    CircularProgressIndicator(),
                  ],
                );
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
                        _controller.refetch();
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
          id: 'example',
          fetcher: (key) async {
            await Future.delayed(const Duration(seconds: 3));
            // throw 'Fetching Failure';
            return 'Fetching Success!';
          },
          placeholder: 'Placeholder Data!',
          staleDuration: const Duration(seconds: 10),
          builder: (context, state, child) {
            switch (state.status) {
              case QueryStatus.idle:
              case QueryStatus.fetching:
              case QueryStatus.retrying:
              case QueryStatus.canceled:
                if (state.hasData) {
                  return Text(state.data!);
                }
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

// class InfiniteQueryExamplePage extends StatefulWidget {
//   const InfiniteQueryExamplePage({super.key});

//   static final examplePages = [
//     {
//       'data': 'Hello1',
//       'nextCursor': 1,
//     },
//     {
//       'data': 'Hello2',
//       'nextCursor': 2,
//     },
//     {
//       'data': 'Hello3',
//       'nextCursor': 3,
//     },
//     {
//       'data': 'Hello4',
//     },
//   ];

//   @override
//   State<InfiniteQueryExamplePage> createState() =>
//       _InfiniteQueryExamplePageState();
// }

// class _InfiniteQueryExamplePageState extends State<InfiniteQueryExamplePage> {
//   late final PagedQueryController<Map<String, dynamic>, int> _controller;

//   @override
//   void initState() {
//     super.initState();
//     _controller = PagedQueryController<Map<String, dynamic>, int>();
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(),
//       body: PagedQueryBuilder<Map<String, dynamic>, int>(
//         controller: _controller,
//         id: 'infinite-query-example',
//         fetcher: (id, params) async {
//           await Future.delayed(const Duration(seconds: 2));
//           if (params == null) {
//             return InfiniteQueryExamplePage.examplePages[0];
//           }
//           return InfiniteQueryExamplePage.examplePages[params];
//         },
//         nextPageParamsBuilder: (pages) {
//           return pages.isNotEmpty ? pages.last['nextCursor'] : null;
//         },
//         // initialData: const [
//         //   {
//         //     'data': 'Hello1',
//         //     'nextCursor': 1,
//         //   },
//         // ],
//         placeholderData: const [
//           {'data': 'Placeholder!'}
//         ],
//         staleDuration: const Duration(seconds: 5),
//         builder: (context, state, child) {
//           if (state.status == QueryStatus.fetching) {
//             if (state.hasData) {
//               return ListView.builder(
//                 itemCount: state.pages.length,
//                 itemBuilder: (context, i) {
//                   return Text(state.pages[i]['data']);
//                 },
//               );
//             }
//             return const Center(
//               child: CircularProgressIndicator(),
//             );
//           }

//           return ListView.builder(
//             itemCount: state.pages.length,
//             itemBuilder: (context, i) {
//               final data = state.pages[i]['data'];
//               return Column(
//                 children: [
//                   Text(data),
//                   if (i == state.pages.length - 1 &&
//                       state.status == QueryStatus.success &&
//                       state.hasNextPage)
//                     ElevatedButton(
//                       onPressed: () {
//                         _controller.fetchNextPage();
//                       },
//                       child: const Text('Load More'),
//                     ),
//                   if (i == state.pages.length - 1 && state.isFetchingNextPage)
//                     Container(
//                       alignment: Alignment.center,
//                       padding: const EdgeInsets.all(4),
//                       height: 32,
//                       child: const CircularProgressIndicator(),
//                     )
//                 ],
//               );
//             },
//           );
//         },
//       ),
//     );
//   }
// }

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
