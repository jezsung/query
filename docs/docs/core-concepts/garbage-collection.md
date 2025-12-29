---
sidebar_position: 3
---

# Garbage Collection

Flutter Query automatically removes unused cached data after a configurable period. This prevents memory leaks and keeps your cache size manageable.

## How Garbage Collection Works

When a query has no active observers (no components are using it), a garbage collection timer starts. After the `gcDuration` expires, the query is removed from the cache.

```
Component mounts → Query created
Component unmounts → GC timer starts
GC duration expires → Query removed from cache
```

If a component mounts with the same query key before the timer expires, the timer is cancelled and the cached data is reused.

## Configuring GC Duration

### Per-Query Configuration

```dart
useQuery(
  ['user', userId],
  fetchUser,
  gcDuration: const GcDuration(minutes: 10),
);
```

### Default Configuration

Set a default for all queries:

```dart
final queryClient = QueryClient(
  defaultQueryOptions: DefaultQueryOptions(
    gcDuration: const GcDuration(minutes: 5),
  ),
);
```

## GcDuration Options

### Time-Based Duration

```dart
// Remove after 5 minutes of inactivity
gcDuration: const GcDuration(minutes: 5)

// Remove after 1 hour
gcDuration: const GcDuration(hours: 1)

// Remove after 30 seconds
gcDuration: const GcDuration(seconds: 30)
```

### Special Values

```dart
// Remove immediately when no observers (default behavior may vary)
gcDuration: GcDuration.zero

// Never garbage collect - keep in cache forever
gcDuration: GcDuration.infinity
```

## Query Lifecycle

Here's the complete lifecycle of a query:

```
1. Query Created
   └── Component calls useQuery
   └── Query added to cache
   └── Fetch initiated

2. Query Active
   └── One or more components observing
   └── Data in cache
   └── No GC timer

3. Query Inactive
   └── All components unmounted
   └── GC timer started
   └── Data still in cache

4. Query Garbage Collected (if timer expires)
   └── Removed from cache
   └── Next useQuery will fetch fresh data
```

## Mutations and GC

Mutations also support garbage collection:

```dart
final queryClient = QueryClient(
  defaultMutationOptions: DefaultMutationOptions(
    gcDuration: const GcDuration(minutes: 5),  // Default
  ),
);
```

Mutation state is garbage collected after the mutation completes and the component unmounts.

## Best Practices

### Balance Memory and User Experience

```dart
// Frequently accessed data - keep longer
['user', currentUserId]
gcDuration: const GcDuration(minutes: 30)

// Rarely accessed data - shorter retention
['search', query]
gcDuration: const GcDuration(minutes: 2)
```

### Use `infinity` for Critical Data

For data that should persist throughout the app session:

```dart
// App configuration
useQuery(
  ['config'],
  fetchConfig,
  gcDuration: GcDuration.infinity,
);

// Current user session
useQuery(
  ['currentUser'],
  fetchCurrentUser,
  gcDuration: GcDuration.infinity,
);
```

### Consider Navigation Patterns

If users frequently navigate between screens:

```dart
// List view data - user might go back
gcDuration: const GcDuration(minutes: 5)

// Detail view data - less likely to revisit same item
gcDuration: const GcDuration(minutes: 2)
```

## Manual Cache Management

You can also manually manage the cache:

### Clear All Queries

```dart
queryClient.dispose();
```

### Cancel Specific Queries

```dart
queryClient.cancelQueries(['user', userId]);
```

## Debugging

To understand what's in your cache, you can inspect the `QueryCache`:

```dart
final queryClient = useQueryClient();
// Access queryClient.queryCache for debugging
```

:::tip
In development, consider using longer GC durations to make debugging easier. You can use different configurations for debug and release builds.
:::
