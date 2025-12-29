---
sidebar_position: 1
---

# QueryClient Setup

The `QueryClient` is the central manager for all queries and mutations. It holds the cache, manages defaults, and provides methods for cache manipulation.

## Creating a QueryClient

Create a single `QueryClient` instance for your app:

```dart
import 'package:flutter_query/flutter_query.dart';

final queryClient = QueryClient();
```

## Providing the QueryClient

Wrap your app with `QueryClientProvider` to make the client available to all hooks:

```dart
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

Configure default behavior for all queries and mutations:

```dart
final queryClient = QueryClient(
  defaultQueryOptions: DefaultQueryOptions(
    staleDuration: const StaleDuration(minutes: 5),
    gcDuration: const GcDuration(minutes: 10),
    refetchOnMount: RefetchOnMount.stale,
    refetchOnResume: RefetchOnResume.stale,
    retry: retryExponentialBackoff(),
    retryOnMount: true,
  ),
  defaultMutationOptions: DefaultMutationOptions(
    retry: retryNever,
    gcDuration: const GcDuration(minutes: 5),
  ),
);
```

### DefaultQueryOptions

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enabled` | `bool?` | `true` | Whether queries are enabled by default. |
| `staleDuration` | `StaleDuration?` | `StaleDuration.zero` | Default staleness duration. |
| `gcDuration` | `GcDuration?` | - | Default garbage collection duration. |
| `refetchOnMount` | `RefetchOnMount?` | `stale` | Default behavior when component mounts. |
| `refetchOnResume` | `RefetchOnResume?` | `stale` | Default behavior when app resumes. |
| `refetchInterval` | `Duration?` | `null` | Default refetch interval. |
| `retry` | `RetryResolver?` | exponential | Default retry strategy. |
| `retryOnMount` | `bool?` | `true` | Whether to retry failed queries on mount. |

### DefaultMutationOptions

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `retry` | `RetryResolver?` | `retryNever` | Default retry strategy for mutations. |
| `gcDuration` | `GcDuration?` | 5 minutes | Default GC duration for mutation state. |

## Retry Strategies

Flutter Query provides built-in retry strategies:

### Exponential Backoff (Default for Queries)

```dart
final queryClient = QueryClient(
  defaultQueryOptions: DefaultQueryOptions(
    retry: retryExponentialBackoff(
      maxRetries: 3,           // Default: 3
      baseDelay: Duration(seconds: 1),  // Default: 1s
      maxDelay: Duration(seconds: 30),  // Default: 30s
    ),
  ),
);
```

The delays are: 1s, 2s, 4s (capped at maxDelay).

### Never Retry (Default for Mutations)

```dart
retry: retryNever
```

### Custom Retry Logic

```dart
retry: (retryCount, error) {
  // Don't retry client errors (4xx)
  if (error is HttpException && error.statusCode >= 400 && error.statusCode < 500) {
    return null;  // Stop retrying
  }

  // Max 5 retries
  if (retryCount >= 5) return null;

  // Linear backoff: 1s, 2s, 3s, 4s, 5s
  return Duration(seconds: retryCount + 1);
}
```

## Lifecycle Management

### Disposing the Client

Always dispose the `QueryClient` when it's no longer needed:

```dart
// At app shutdown
queryClient.dispose();
```

### With StatefulWidget

For proper lifecycle management:

```dart
class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final QueryClient _queryClient;

  @override
  void initState() {
    super.initState();
    _queryClient = QueryClient(
      defaultQueryOptions: DefaultQueryOptions(
        staleDuration: const StaleDuration(minutes: 5),
      ),
    );
  }

  @override
  void dispose() {
    _queryClient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return QueryClientProvider(
      client: _queryClient,
      child: const MaterialApp(home: HomeScreen()),
    );
  }
}
```

## Multiple QueryClients

You can use multiple `QueryClient` instances for different parts of your app:

```dart
class MyApp extends StatelessWidget {
  final QueryClient mainClient;
  final QueryClient authClient;

  const MyApp({
    required this.mainClient,
    required this.authClient,
  });

  @override
  Widget build(BuildContext context) {
    return QueryClientProvider(
      client: mainClient,
      child: MaterialApp(
        home: QueryClientProvider(
          client: authClient,  // Override for auth section
          child: const AuthSection(),
        ),
      ),
    );
  }
}
```

## Accessing the QueryClient

### In HookWidgets

```dart
final queryClient = useQueryClient();
```

### In Regular Widgets

```dart
final queryClient = QueryClientProvider.of(context);

// Or safely
final queryClient = QueryClientProvider.maybeOf(context);
```

### In Mutation Callbacks

```dart
useMutation(
  mutationFn,
  onSuccess: (data, variables, _, context) {
    context.client.invalidateQueries(['todos']);
  },
);
```

## Configuration Examples

### Conservative Caching

Keep data fresh, refetch often:

```dart
QueryClient(
  defaultQueryOptions: DefaultQueryOptions(
    staleDuration: StaleDuration.zero,
    refetchOnMount: RefetchOnMount.always,
    refetchOnResume: RefetchOnResume.always,
  ),
)
```

### Aggressive Caching

Minimize network requests:

```dart
QueryClient(
  defaultQueryOptions: DefaultQueryOptions(
    staleDuration: const StaleDuration(hours: 1),
    gcDuration: GcDuration.infinity,
    refetchOnMount: RefetchOnMount.never,
    refetchOnResume: RefetchOnResume.never,
  ),
)
```

### Balanced (Recommended)

```dart
QueryClient(
  defaultQueryOptions: DefaultQueryOptions(
    staleDuration: const StaleDuration(minutes: 5),
    gcDuration: const GcDuration(minutes: 15),
    refetchOnMount: RefetchOnMount.stale,
    refetchOnResume: RefetchOnResume.stale,
    retry: retryExponentialBackoff(maxRetries: 3),
  ),
)
```
