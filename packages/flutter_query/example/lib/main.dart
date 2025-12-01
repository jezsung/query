import 'package:flutter/material.dart';
import 'package:flutter_query/flutter_query.dart';

QueryClient queryClient = QueryClient(
    defaultOptions: const DefaultOptions(
      queries: QueryDefaultOptions(
        enabled: true,
        staleTime: 0,
        refetchOnRestart: false,
        refetchOnReconnect: false,
      ),
    ),
    queryCache: QueryCache(config: QueryCacheConfig(
      onError: (e) {
        print(e);
      },
    )),
    mutationCache: MutationCache(config: MutationCacheConfig(
      onError: (e) {
        print(e);
      },
    )));

void main() {
  runApp(
    const App(),
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
