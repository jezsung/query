---
sidebar_position: 2
---

# Installation

## Adding the Package

Add `flutter_query` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_query: ^0.3.7
```

Then run:

```bash
flutter pub get
```

## Dependencies

Flutter Query depends on [flutter_hooks](https://pub.dev/packages/flutter_hooks) for its hooks-based API. This is included as a transitive dependency, but you may want to add it explicitly:

```yaml
dependencies:
  flutter_query: ^0.3.7
  flutter_hooks: ^0.21.2
```

## Setup

### 1. Create a QueryClient

Create a `QueryClient` instance. This is typically done once at the top level of your app:

```dart
import 'package:flutter_query/flutter_query.dart';

void main() {
  final queryClient = QueryClient();

  runApp(MyApp(queryClient: queryClient));
}
```

### 2. Provide the QueryClient

Wrap your app with `QueryClientProvider`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_query/flutter_query.dart';

class MyApp extends StatelessWidget {
  final QueryClient queryClient;

  const MyApp({required this.queryClient});

  @override
  Widget build(BuildContext context) {
    return QueryClientProvider(
      client: queryClient,
      child: MaterialApp(
        home: HomeScreen(),
      ),
    );
  }
}
```

### 3. Dispose the QueryClient

Don't forget to dispose the `QueryClient` when your app is closed to clean up resources:

```dart
void main() {
  final queryClient = QueryClient();

  runApp(MyApp(queryClient: queryClient));

  // Clean up when the app closes
  queryClient.dispose();
}
```

:::tip
For proper lifecycle management, consider using a `StatefulWidget` at the root of your app or a state management solution to handle the `QueryClient` disposal.
:::

## Complete Example

Here's a complete setup example:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_query/flutter_query.dart';

void main() {
  final queryClient = QueryClient();

  runApp(
    QueryClientProvider(
      client: queryClient,
      child: const MaterialApp(
        home: HomeScreen(),
      ),
    ),
  );
}
```

## Default Options

You can configure default options for all queries and mutations:

```dart
final queryClient = QueryClient(
  defaultQueryOptions: DefaultQueryOptions(
    staleDuration: const StaleDuration(minutes: 5),
    gcDuration: const GcDuration(minutes: 10),
    refetchOnMount: RefetchOnMount.stale,
    refetchOnResume: RefetchOnResume.stale,
    retry: retryExponentialBackoff(),
  ),
  defaultMutationOptions: DefaultMutationOptions(
    retry: retryNever,
    gcDuration: const GcDuration(minutes: 5),
  ),
);
```

See [QueryClient Setup](./query-client/setup) for more configuration options.

## Next Steps

- [Quick Start](./quick-start) - Build your first query
- [useQuery Hook](./hooks/use-query) - Learn about the main data fetching hook
