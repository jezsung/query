import 'package:flutter/material.dart';
import 'package:flutter_query/flutter_query.dart';
import 'pages/todos_page.dart';
import 'pages/infinity_page.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

// The QueryClient is created inside the QueryClientProvider (see Quick Start docs)

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
      title: 'futter_query Example',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: Scaffold(
        body: SafeArea(
          child: content.value,
        ),
        // Custom simple bottom bar with two items that switches the index.
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.black12)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => content.value = TodosPage(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        Icon(Icons.view_agenda, color: content.value is TodosPage ? Colors.blue : Colors.black54),
                      const SizedBox(height: 4),
                      Text('Classical', style: TextStyle(color: content.value is TodosPage ? Colors.blue : Colors.black54)),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => content.value = InfinityPage(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        Icon(Icons.all_inclusive, color: content.value is InfinityPage ? Colors.blue : Colors.black54),
                      const SizedBox(height: 4),
                      Text('Infinity', style: TextStyle(color: content.value is InfinityPage ? Colors.blue : Colors.black54)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
