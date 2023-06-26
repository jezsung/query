Query identifiers are used to cache the result of the queries.

You can pass in an identifier to the `id` of a `QueryBuilder`.

```dart
QueryBuilder(
  id: 'unique-id',
  ...
)
```

The `id` is passed to the `fetcher` function as an argument.

```dart
QueryBuilder(
  id: 'unique-id',
  fetcher: (id) async {
    // id == 'unique-id'
  },
  ...
)
```

Queries with the same data source have to share the same identifier. Because of that, a query identifier is usually defined with the URL of the target API.

```dart
QueryBuilder(
  id: 'https://myserver.com/todos/1',
  ...
)
```
