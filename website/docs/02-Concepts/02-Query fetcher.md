A query fetcher is a function that gets the `id` as an argument and returns a `Future` with data. You can pass in an async function to the `fetcher` of a `QueryBuilder`. The provided `fetcher` will be executed when a `QueryBuilder` is inserted into a widget tree for the time or when a refetching has to occur.

```dart
QueryBuilder(
  fetcher: (id) async {
    ...
  },
)
```

You can specifiy the return type of a `fetcher` with the type argument of a `QueryBuilder`.

```dart
QueryBuilder<String>(
  fetcher: (id) async {
    final String data = await getSomethingString();
    return data;
  },
)
```
