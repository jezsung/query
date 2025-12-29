---
sidebar_position: 1
---

# Query Options

This page documents all configuration options for queries.

## QueryObserverOptions

Options passed to `useQuery`. These control observer-level behavior.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `queryKey` | `List<Object?>` | required | Unique identifier for the query. |
| `queryFn` | `QueryFn<TData>` | required | Async function that fetches data. |
| `enabled` | `bool` | `true` | Whether the query should run. |
| `staleDuration` | `StaleDuration` | `StaleDuration.zero` | Duration until data is considered stale. |
| `gcDuration` | `GcDuration` | - | Duration before garbage collection. |
| `placeholder` | `TData` | `null` | Data to show while loading. |
| `refetchOnMount` | `RefetchOnMount` | `stale` | When to refetch on mount. |
| `refetchOnResume` | `RefetchOnResume` | `stale` | When to refetch on app resume. |
| `refetchInterval` | `Duration` | `null` | Interval for automatic refetching. |
| `retry` | `RetryResolver<TError>` | exponential | Retry logic on failure. |
| `retryOnMount` | `bool` | `true` | Whether to retry failed queries on mount. |
| `seed` | `TData` | `null` | Initial data to populate cache. |
| `seedUpdatedAt` | `DateTime` | `null` | Timestamp for seed data. |
| `meta` | `Map<String, dynamic>` | `null` | Custom metadata. |
| `queryClient` | `QueryClient` | inherited | Override QueryClient. |

## StaleDuration

Controls when cached data is considered stale.

### Constructors

```dart
// Time-based staleness
const StaleDuration({
  int days = 0,
  int hours = 0,
  int minutes = 0,
  int seconds = 0,
  int milliseconds = 0,
  int microseconds = 0,
})

// Immediately stale
StaleDuration.zero

// Never stale by time (only by invalidation)
StaleDuration.infinity

// Truly static (never refetch, even on invalidation)
StaleDuration.static
```

### Examples

```dart
// Stale after 5 minutes
staleDuration: const StaleDuration(minutes: 5)

// Stale after 1 hour
staleDuration: const StaleDuration(hours: 1)

// Stale after 2 minutes 30 seconds
staleDuration: const StaleDuration(minutes: 2, seconds: 30)

// Immediately stale (refetch on every mount when refetchOnMount is stale)
staleDuration: StaleDuration.zero

// Never becomes stale by time
staleDuration: StaleDuration.infinity

// Never refetch, even when invalidated
staleDuration: StaleDuration.static
```

## GcDuration

Controls when inactive queries are garbage collected.

### Constructors

```dart
// Time-based GC
const GcDuration({
  int days = 0,
  int hours = 0,
  int minutes = 0,
  int seconds = 0,
  int milliseconds = 0,
  int microseconds = 0,
})

// Immediate GC when no observers
GcDuration.zero

// Never garbage collect
GcDuration.infinity
```

### Examples

```dart
// GC after 5 minutes of no observers
gcDuration: const GcDuration(minutes: 5)

// GC after 1 hour
gcDuration: const GcDuration(hours: 1)

// Immediate GC
gcDuration: GcDuration.zero

// Never GC (keep forever)
gcDuration: GcDuration.infinity
```

## RefetchOnMount

Controls refetch behavior when a component mounts.

| Value | Description |
|-------|-------------|
| `RefetchOnMount.never` | Never refetch on mount. |
| `RefetchOnMount.stale` | Refetch only if data is stale (default). |
| `RefetchOnMount.always` | Always refetch on mount. |

```dart
// Show cached data, refetch only if stale
refetchOnMount: RefetchOnMount.stale

// Always refetch for fresh data
refetchOnMount: RefetchOnMount.always

// Never refetch, always use cache
refetchOnMount: RefetchOnMount.never
```

## RefetchOnResume

Controls refetch behavior when the app resumes from background.

| Value | Description |
|-------|-------------|
| `RefetchOnResume.never` | Never refetch on resume. |
| `RefetchOnResume.stale` | Refetch only if data is stale (default). |
| `RefetchOnResume.always` | Always refetch on resume. |

```dart
// Refetch if data might be outdated
refetchOnResume: RefetchOnResume.stale

// Always get fresh data after background
refetchOnResume: RefetchOnResume.always

// Trust cached data
refetchOnResume: RefetchOnResume.never
```

## RetryResolver

Function that determines retry behavior.

### Type

```dart
typedef RetryResolver<TError> = Duration? Function(int retryCount, TError error);
```

- Return a `Duration` to retry after that delay
- Return `null` to stop retrying

### Built-in Resolvers

```dart
// Never retry (default for mutations)
retry: retryNever

// Exponential backoff (default for queries)
retry: retryExponentialBackoff(
  maxRetries: 3,           // Default: 3
  baseDelay: Duration(seconds: 1),   // Default: 1s
  maxDelay: Duration(seconds: 30),   // Default: 30s
)
```

### Custom Resolver

```dart
retry: (retryCount, error) {
  // Don't retry 4xx errors
  if (error is HttpException && error.statusCode >= 400 && error.statusCode < 500) {
    return null;
  }

  // Max 5 retries
  if (retryCount >= 5) return null;

  // Linear backoff
  return Duration(seconds: retryCount + 1);
}
```

## DefaultQueryOptions

Default options applied to all queries.

```dart
final queryClient = QueryClient(
  defaultQueryOptions: DefaultQueryOptions(
    enabled: true,
    staleDuration: const StaleDuration(minutes: 5),
    gcDuration: const GcDuration(minutes: 10),
    refetchOnMount: RefetchOnMount.stale,
    refetchOnResume: RefetchOnResume.stale,
    refetchInterval: null,
    retry: retryExponentialBackoff(),
    retryOnMount: true,
  ),
);
```

| Option | Type | Default |
|--------|------|---------|
| `enabled` | `bool?` | `true` |
| `staleDuration` | `StaleDuration?` | `StaleDuration.zero` |
| `gcDuration` | `GcDuration?` | - |
| `refetchOnMount` | `RefetchOnMount?` | `stale` |
| `refetchOnResume` | `RefetchOnResume?` | `stale` |
| `refetchInterval` | `Duration?` | `null` |
| `retry` | `RetryResolver?` | exponential backoff |
| `retryOnMount` | `bool?` | `true` |

## QueryFunctionContext

Context passed to the query function.

| Property | Type | Description |
|----------|------|-------------|
| `queryKey` | `List<Object?>` | The query key. |
| `client` | `QueryClient` | The QueryClient instance. |
| `signal` | `AbortSignal` | Signal for cancellation. |
| `meta` | `Map<String, dynamic>?` | Custom metadata. |

```dart
useQuery(
  ['user', userId],
  (context) async {
    final key = context.queryKey;     // ['user', userId]
    final client = context.client;    // QueryClient
    final signal = context.signal;    // AbortSignal
    final meta = context.meta;        // Custom metadata

    // Use the signal for cancellation
    if (signal.aborted) {
      throw AbortedException();
    }

    return fetchUser(key[1] as String);
  },
  meta: {'source': 'profile_page'},
);
```
