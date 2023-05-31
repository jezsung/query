A Flutter package that is equivalent to the [React Query](https://tanstack.com/query/v3/) library in the [React](https://react.dev/) ecosystem.

This package utilizes the power of Widgets in Flutter. As React Query provides its APIs with Hooks, flutter_query does it with Widgets.

## Motivation

There are a variety of state management packages in Flutter, but those packages lack abstraction for common asynchronous operations.

Asynchronous operations are mostly used when communicating with remote APIs such as sending HTTP requests to servers.

These kind of operations lead to the repetitive state management pattern.

This package helps reducing this common pattern by providing high level state management APIs.

## Usage

Wrap your app with the `QueryClientProvider`. The `QueryClient` is used to control the `Query`s in the app.

```dart
runApp(
  QueryClientProvider(
    create: (context) => QueryClient(),
    child: MyApp(),
  ),
);
```

Give an unique string to the `id` and a method to the `fetcher` that runs asynchronous operations.

The `state` is the type of `QueryState`. The `QueryState` has a `QueryStatus` that represents the current status of the operation.

```dart
QueryBuilder<String>(
  id: '1',
  fetcher: (id) async {
    final todoId = id;
    final todoTitle = getTodoTitleById(todoId);
    return todoTitle;
  },
  builder: (context, state, child) {
    switch(state.status) {
      case QueryStatus.idle:
        return Text('Ready to load data');
      case QueryStatus.fetching:
        return Text('Loading...');
      case QueryStatus.success:
        final todoTitle = state.data!;
        return Text(todoTitle);
      case QueryStatus.failure:
        return Text('Something went wrong...')
    }
  },
)
```
