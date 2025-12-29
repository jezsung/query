---
sidebar_position: 1
---

# Overview

Flutter Query is a powerful data fetching and state management library for Flutter, inspired by [TanStack Query](https://tanstack.com/query) (formerly React Query). It provides a declarative, hooks-based API for managing asynchronous state in your Flutter applications.

## Features

- **Declarative Data Fetching** - Fetch data with simple hooks that handle loading, error, and success states automatically
- **Automatic Caching** - Query results are cached and shared across your app
- **Smart Refetching** - Configurable background refetching on mount, app resume, or at intervals
- **Request Deduplication** - Multiple components requesting the same data share a single request
- **Automatic Retries** - Failed requests are automatically retried with exponential backoff
- **Mutations with Callbacks** - Create, update, and delete data with lifecycle callbacks
- **Optimistic Updates** - Update the UI optimistically before the server responds
- **Query Invalidation** - Invalidate and refetch queries when data changes
- **Garbage Collection** - Unused cached data is automatically cleaned up

## Why Flutter Query?

Managing server state in Flutter applications can be complex. You need to handle:

- Loading and error states
- Caching and cache invalidation
- Background updates and refetching
- Request deduplication
- Retry logic
- Optimistic updates

Flutter Query solves all of these problems with a simple, declarative API that lets you focus on building your UI.

## Architecture

Flutter Query uses a hooks-based API powered by [flutter_hooks](https://pub.dev/packages/flutter_hooks). The main components are:

| Component | Description |
|-----------|-------------|
| `QueryClient` | Central manager for all queries and mutations. Holds the cache and provides methods for cache manipulation. |
| `QueryClientProvider` | Widget that provides the `QueryClient` to the widget tree. |
| `useQuery` | Hook for fetching and caching data. |
| `useMutation` | Hook for creating, updating, or deleting data. |
| `useQueryClient` | Hook for accessing the `QueryClient` instance. |

## Quick Example

```dart
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_query/flutter_query.dart';

class UserProfile extends HookWidget {
  final String userId;

  const UserProfile({required this.userId});

  @override
  Widget build(BuildContext context) {
    final result = useQuery<User, Exception>(
      ['user', userId],
      (context) => fetchUser(userId),
    );

    return switch (result) {
      QueryResult(:final data?) => Text('Hello, ${data.name}!'),
      QueryResult(isPending: true) => const CircularProgressIndicator(),
      QueryResult(:final error?) => Text('Error: $error'),
    };
  }
}
```

## Comparison with Other Solutions

| Feature | Flutter Query | Provider | Riverpod | BLoC |
|---------|--------------|----------|----------|------|
| Declarative data fetching | Yes | Manual | Manual | Manual |
| Automatic caching | Yes | Manual | Manual | Manual |
| Background refetching | Yes | Manual | Manual | Manual |
| Request deduplication | Yes | Manual | Yes | Manual |
| Retry logic | Yes | Manual | Manual | Manual |
| Devtools | Planned | Yes | Yes | Yes |

## Requirements

- Flutter 3.32.0 or higher
- Dart 3.0.0 or higher

## Next Steps

- [Installation](./installation) - Add Flutter Query to your project
- [Quick Start](./quick-start) - Build your first query
- [Core Concepts](./core-concepts/) - Understand how Flutter Query works
