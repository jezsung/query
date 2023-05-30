import 'package:flutter/material.dart';
import 'package:flutter_query/flutter_query.dart';

void main() {
  runApp(
    QueryClientProvider(
      create: (context) => QueryClient(),
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
  late final QueryController<Post> _postController;

  @override
  void initState() {
    super.initState();
    _postController = QueryController<Post>();
  }

  @override
  void dispose() {
    _postController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('flutter_query'),
      ),
      body: SafeArea(
        child: QueryBuilder<Post>(
          controller: _postController,
          id: 'https://jsonplaceholder.typicode.com/posts/1',
          fetcher: (uri) async {
            await Future.delayed(const Duration(seconds: 3));
            return const Post(
              title: 'This is flutter_query example!',
              body: 'It is really awesome!',
            );
          },
          builder: (context, state, child) {
            if (state.status.isFailure) {
              return const Center(child: Text('Something went wrong!'));
            }

            if (!state.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final post = state.data!;
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(post.body),
                  ElevatedButton(
                    onPressed: state.status.isFetching
                        ? null
                        : () {
                            _postController.refetch();
                          },
                    child: state.status.isFetching
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Refetch'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class Post {
  const Post({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;
}
