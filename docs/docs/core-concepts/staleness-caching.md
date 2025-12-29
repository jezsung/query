---
sidebar_position: 2
---

# Staleness & Caching

Flutter Query automatically caches query results and determines when to refetch based on staleness. Understanding these concepts is key to optimizing your app's performance and user experience.

## How Caching Works

When a query completes successfully, the result is stored in the `QueryCache`:

1. The data is associated with the query key
2. A timestamp is recorded (`dataUpdatedAt`)
3. The data is shared with all components using the same key

```dart
// First component fetches data - request is made
useQuery(['user', userId], fetchUser);

// Second component with same key - uses cached data, no request
useQuery(['user', userId], fetchUser);
```

## What is Staleness?

**Stale** data is cached data that is considered outdated and eligible for refetching. Staleness is determined by the `staleDuration` option.

```dart
useQuery(
  ['user', userId],
  fetchUser,
  staleDuration: const StaleDuration(minutes: 5),
);
```

With this configuration:
- Data fetched less than 5 minutes ago is **fresh**
- Data fetched more than 5 minutes ago is **stale**

## Stale vs Fresh Data

| State | Description | Behavior |
|-------|-------------|----------|
| **Fresh** | Data was recently fetched | No automatic refetch |
| **Stale** | Data is outdated | May refetch based on `refetchOnMount`/`refetchOnResume` |

## StaleDuration Options

### Time-Based Duration

```dart
// Stale after 5 minutes
staleDuration: const StaleDuration(minutes: 5)

// Stale after 30 seconds
staleDuration: const StaleDuration(seconds: 30)

// Stale after 1 hour
staleDuration: const StaleDuration(hours: 1)

// Combine time units
staleDuration: const StaleDuration(minutes: 2, seconds: 30)
```

### Special Values

```dart
// Immediately stale (default) - refetches on every mount when stale-checking is enabled
staleDuration: StaleDuration.zero

// Never stale by time - only becomes stale through invalidation
staleDuration: StaleDuration.infinity

// Truly static - never refetch, even on invalidation
staleDuration: StaleDuration.static
```

## Refetch Triggers

Staleness determines *if* data should be refetched. These options determine *when* to check:

### Refetch on Mount

When a component mounts and subscribes to a query:

```dart
useQuery(
  ['user', userId],
  fetchUser,
  refetchOnMount: RefetchOnMount.stale,  // Refetch if stale (default)
);
```

| Value | Behavior |
|-------|----------|
| `RefetchOnMount.never` | Never refetch on mount |
| `RefetchOnMount.stale` | Refetch only if data is stale |
| `RefetchOnMount.always` | Always refetch on mount |

### Refetch on App Resume

When the app returns from the background:

```dart
useQuery(
  ['user', userId],
  fetchUser,
  refetchOnResume: RefetchOnResume.stale,  // Refetch if stale (default)
);
```

| Value | Behavior |
|-------|----------|
| `RefetchOnResume.never` | Never refetch on resume |
| `RefetchOnResume.stale` | Refetch only if data is stale |
| `RefetchOnResume.always` | Always refetch on resume |

### Refetch Interval

Automatically refetch at a fixed interval:

```dart
useQuery(
  ['stock', symbol],
  fetchStockPrice,
  refetchInterval: const Duration(seconds: 10),
);
```

:::tip
Interval refetching is useful for real-time data like stock prices, notifications, or live feeds.
:::

## Checking Staleness

The `QueryResult` includes an `isStale` property:

```dart
final result = useQuery(['user', userId], fetchUser);

if (result.isStale) {
  // Data is stale
}
```

## Cache Behavior Examples

### Scenario 1: Fresh Data

```dart
// staleDuration: 5 minutes
// Data fetched 2 minutes ago

// Component mounts with refetchOnMount: stale
// Result: Uses cached data, no refetch (data is fresh)
```

### Scenario 2: Stale Data

```dart
// staleDuration: 5 minutes
// Data fetched 10 minutes ago

// Component mounts with refetchOnMount: stale
// Result: Shows cached data immediately, refetches in background
```

### Scenario 3: No Cached Data

```dart
// No data in cache

// Component mounts
// Result: Shows loading state, fetches data
```

## Default Options

Set defaults for all queries in your app:

```dart
final queryClient = QueryClient(
  defaultQueryOptions: DefaultQueryOptions(
    staleDuration: const StaleDuration(minutes: 5),
    refetchOnMount: RefetchOnMount.stale,
    refetchOnResume: RefetchOnResume.stale,
  ),
);
```

## Best Practices

### Match Staleness to Data Freshness Requirements

```dart
// User profile - doesn't change often
staleDuration: const StaleDuration(minutes: 30)

// Notifications - should be relatively fresh
staleDuration: const StaleDuration(minutes: 1)

// Real-time data - always refetch
staleDuration: StaleDuration.zero
refetchInterval: const Duration(seconds: 5)
```

### Use `infinity` for Static Data

For data that rarely or never changes:

```dart
// App configuration loaded once
useQuery(
  ['config'],
  fetchConfig,
  staleDuration: StaleDuration.infinity,
);
```

### Combine with Query Invalidation

Even with a long stale duration, you can force a refetch by invalidating:

```dart
// After user updates their profile
queryClient.invalidateQueries(['user', userId]);
```

This marks the query as stale and triggers a refetch if there are active observers.
