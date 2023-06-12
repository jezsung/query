In this quick start tutorial, we will make an app that shows "Hello World!" in the center of the screen after the 3-second delay using a `QueryBuilder`.

First of all, wrap your entire widget tree with the `QueryClientProvider`. The `QueryClientProvider` allows you to create a `QueryClient` and dispose of it when the `QueryClient` is no longer used.

```dart title="lib/main.dart"
void main() {
  runApp(
    QueryClientProvider(
      create: (context) => QueryClient(),
      child: const MyApp(),
    ),
  );
}
```

:::caution
Do create a `QueryClient` inside the `create`. Do NOT provide a `QueryClient` that was created outside of the `create`.
:::

```dart title="lib/main.dart"
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quick start',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: QueryBuilder<String>(
          id: 'id',
          fetcher: (id) async {
            await Future.delayed(const Duration(seconds: 3));
            return 'Hello World!';
          },
          builder: (context, state, child) {
            switch (state.status) {
              case QueryStatus.idle:
              case QueryStatus.fetching:
                return const CircularProgressIndicator();
              case QueryStatus.success:
                return Text(state.data!);
              case QueryStatus.failure:
                return const Text('Something went wrong...');
            }
          },
        ),
      ),
    );
  }
}
```
