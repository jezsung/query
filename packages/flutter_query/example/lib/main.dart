import 'package:flutter/material.dart';
import 'package:flutter_query/flutter_query.dart';
import 'pages/todos_page.dart';
import 'pages/infinity_page.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

void main() {
  queryClient = QueryClient(
    defaultOptions: const DefaultOptions(
      queries: QueryDefaultOptions(
        enabled: true,
        staleTime: 0,
        refetchOnRestart: false,
        refetchOnReconnect: false,
      ),
    ),
    queryCache: QueryCache(config: QueryCacheConfig(onError: (e) => print(e))),
    mutationCache:
        MutationCache(config: MutationCacheConfig(onError: (e) => print(e))),
  );

  runApp(const App());
}

class App extends HookWidget {
  const App({super.key});


  @override
  Widget build(BuildContext context) {
    final content = useState<Widget>(TodosPage());

    return MaterialApp(
      title: 'flutter_query Example',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: Scaffold(
      body: SafeArea(
        child: content.value,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: content.value is TodosPage ? 0 : 1,
        onTap: (index) {
        if (index == 0) {
          // Always create a new TodosPage, to see the librairy in action
          content.value = TodosPage();
        } else {
          // Always create a new InfinityPage, to see the librairy in action
          content.value = InfinityPage();
        }
        },
        items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.view_agenda),
          label: 'Classical',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.all_inclusive),
          label: 'Infinity',
        ),
        ],
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.black54,
      ),
      ),
    );
  }
}
