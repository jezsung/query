A Flutter package inspired by the [TanStack Query](https://tanstack.com/query/latest) library (formerly React Query) in the [React](https://react.dev/) ecosystem. The current API reflects the [TanStack Query version 3](https://tanstack.com/query/v3/docs/framework/react/overview) API.

This package utilizes the power of Hooks in Flutter. As TanStack Query provides its APIs with Hooks, flutter_query does it with Hooks too.

> **Note:** Since version 0.3.0, the widget-based API has been dropped in favor of the hook-based API. This package now requires `flutter_hooks`.

## Motivation

There are a variety of state management packages in Flutter, but those packages lack abstraction for common asynchronous operations.

Asynchronous operations are mostly used when communicating with remote APIs such as sending HTTP requests to servers.

These kind of operations lead to the repetitive state management pattern.

This package helps reducing this common pattern by providing high level state management APIs.

## Usage

Wrap your app with the `QueryScope`. This provides the query client to the widget tree.

```dart
runApp(
  QueryScope(
    child: MyApp(),
  ),
);
```

Use the `useQuery` hook in your `HookWidget` to fetch data. Give a unique key and a `fetcher` function that runs asynchronous operations.

The hook returns a `QueryResult` containing the `state`, which is of type `QueryState`. The `QueryState` has a `QueryStatus` that represents the current status of the operation.

```dart
class TodoWidget extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final result = useQuery<String, String>(
      'todo-1',
      (key) async {
        final todoId = key;
        final todoTitle = await getTodoTitleById(todoId);
        return todoTitle;
      },
    );

    switch(result.state.status) {
      case QueryStatus.fetching:
        return Text('Loading...');
      case QueryStatus.success:
        final todoTitle = result.state.data!;
        return Text(todoTitle);
      case QueryStatus.failure:
        return Text('Something went wrong...');
      default:
        return Text('Ready to load data');
    }
  }
}
```
