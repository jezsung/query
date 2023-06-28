### Introduction

In this short tutorial, you will fetch remote data by making an HTTP request to a server and will handle each state of a query.

By the end of this tutorial, you will have clear ideas of how QueryBuilders help manage the common server state.

## Choose what to use for identifiers

A `QueryBuilder` has a required property call `id`. This is a unique identifier for the same source of data. A `QueryBuilder` uses the provided `id` to cache the state. `QueryBuilder`s with the same `id` share the same state and are updated simultaneously.

An `id` must be the type of `String`. Provide an identifier to the `id` of a `QueryBuilder`:

```dart
QueryBuilder(
  // highlight-next-line
  id: 'unique-id',
  ...
)
```

Setting an `id` with an API endpoint is a good practice because API endpoints represent the same source of data.

```dart
QueryBuilder(
  // highlight-next-line
  id: 'https://my-server.com/api',
  ...
)
```

You have chosen what to use for query identifiers and provided it to a `QueryBuilder`.

## Make API requests

A `QueryBuiler` executes fetching with the provided `fetcher` function. A `fetcher` is an asynchronous function and it should return a `Future` with data when it succeeds or throw an error when it fails. The `id` is passed to the `fetcher` as an argument.

Use the [`http`](https://pub.dev/packages/http) package to make an HTTP `GET` request to a server and return the fetched data:

```dart
import 'package:http/http.dart' as http;

QueryBuilder<String>(
  id: 'https://my-server.com/api/post/1',
  // highlight-start
  fetcher: (id) async {
    final response = await http.get(Uri.parse(id));
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return json['title'] as String;
  },
  // highlight-end
  ...
)
```

Let's say the API enpoint, which is `https://my-server.com/api/post/1`, returns a JSON with a property called `title`. You use the [`http`](https://pub.dev/packages/http) package to make a `GET` request and receive a response and parse the response body and retrive the `title` property.

:::tip
Set the generic type argument of a `QueryBuilder` to the `fetcher` function's return type to access the fetched data type-safely.
:::

You have fetched remote data using a `QueryBuilder`. Next, you will access the fetched data with the `QueryState` to build a widget tree.

## Build a widget with the state

The `QueryState` of a `QueryBuilder` is passed to the `builder` function. You will build a widget based on the `QueryState` and return the widget in the `builder` function.

Display the fetched `title` from the previous example:

```dart
QueryBuilder<String>(
  id: 'https://my-server.com/api/post/1',
  fetcher: (id) async {
    final response = await http.get(Uri.parse(id));
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return json['title'] as String;
  },
  // highlight-start
  builder: (context, state, child) {
    if (state.hasData) {
      final title = state.data!;
      return Text(title);
    }
  }
  // highlight-end
)
```

First of all, you check if the `data` exists with the `hasData` getter on the `state`. If the `data` exists, you return a `Text` with the `title`.

:::tip
If the `data` is not `null`, the `hasData` always returns `true` so you are safe to cast the type of `data` with the non-nullable operator `!`.
:::

The `QueryState` has a `QueryStatus` enum that represents the current status of the fetch execution. The `QueryStatus` starts with the `QueryStatus.idle` and immediately turns into the `QueryStatus.fetching` when the `QueryBuilder` is inserted into a widget tree. Once the fetch succeeds, the `status` becomes `QueryStatus.success` with the returned `data`. If the fetch fails, the `status` becomes `QueryStatus.error` with the `error` property.

Display a loading view when there is no fetched data:

```dart
QueryBuilder<String>(
  id: 'https://my-server.com/api/post/1',
  fetcher: (id) async {
    final response = await http.get(Uri.parse(id));
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return json['title'] as String;
  },
  builder: (context, state, child) {
    if (state.hasData) {
      final title = state.data!;
      return Text(title);
    }

    // highlight-next-line
    return const CircularProgressIndicator();
  }
)
```

You already returned a `Text` with the `title` when the `data` is available. If the `data` is not available, you display a loading view by returning a `CircularProgressIndicator`. By checking if the `data` exists first, you can display a view with the `data` even if subsequent fetching is in progress.

Display an error view if fetching failed:

```dart
QueryBuilder<String>(
  id: 'https://my-server.com/api/post/1',
  fetcher: (id) async {
    final response = await http.get(Uri.parse(id));
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return json['title'] as String;
  },
  builder: (context, state, child) {
    // highlight-start
    if(state.status.isFailure) {
      final error = state.error!;
      return Text(error.message);
    }
    // highlight-end

    if (state.hasData) {
      final title = state.data!;
      return Text(title);
    }

    return const CircularProgressIndicator();
  }
)
```

You handle errors by checking if the `status` is `QueryStatus.failure`. You can use the extension getter `isFailure` on the `QueryStatus`. It returns `true` if the `status` is `QueryStatus.failure`. If the `status` was `QueryStatus.failure`, the `error` would be the thrown error which is a subtype of `Exception`. Assuming the `error` has a `message` property, you return a `Text` with the error message.

## Conculusion

Congratulations! You have used a `QueryBuilder` to fetch remote data and handle each state with the `QueryState`.
