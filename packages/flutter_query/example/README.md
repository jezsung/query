# flutter_query Example

A minimal example demonstrating `flutter_query` usage.

## What This Example Shows

- Setting up a `QueryClient` and `QueryClientProvider`
- Using the `useQuery` hook to fetch data
- Handling loading, error, and success states with pattern matching

## Code Overview

```dart
final result = useQuery<String, Exception>(
  const ['greeting'],
  (context) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));
    return 'Hello, Flutter Query!';
  },
);
```

Handle states using pattern matching on the sealed `QuerySnapshot`:

```dart
switch (result) {
  QuerySuccess(:final data) => Text(data),
  QueryPending() => const Text('Loading...'),
  QueryError(:final error) => Text('Error: $error'),
}
```
