---
sidebar_position: 4
---

# Retry Strategies

Flutter Query automatically retries failed queries using configurable retry logic. This helps handle transient failures like network issues or server errors.

## Default Behavior

- **Queries**: Retry with exponential backoff (3 retries: 1s, 2s, 4s)
- **Mutations**: No retry by default

## RetryResolver

Retry behavior is controlled by a `RetryResolver` function:

```dart
typedef RetryResolver<TError> = Duration? Function(int retryCount, TError error);
```

- Return a `Duration` to retry after that delay
- Return `null` to stop retrying

## Built-in Retry Strategies

### Exponential Backoff

Default for queries. Retries with increasing delays:

```dart
// Default configuration
retry: retryExponentialBackoff()

// Custom configuration
retry: retryExponentialBackoff(
  maxRetries: 5,           // Maximum retry attempts (default: 3)
  baseDelay: Duration(seconds: 2),   // Initial delay (default: 1s)
  maxDelay: Duration(seconds: 60),   // Maximum delay cap (default: 30s)
)
```

With default settings, delays are: 1s, 2s, 4s (then stops).

### Never Retry

Default for mutations:

```dart
retry: retryNever
```

## Custom Retry Logic

### Retry Based on Error Type

```dart
useQuery(
  ['data'],
  fetchData,
  retry: (retryCount, error) {
    // Don't retry client errors
    if (error is HttpException) {
      if (error.statusCode >= 400 && error.statusCode < 500) {
        return null;  // Don't retry
      }
    }

    // Max 3 retries for other errors
    if (retryCount >= 3) return null;

    // Exponential backoff
    return Duration(seconds: pow(2, retryCount).toInt());
  },
);
```

### Retry Specific Status Codes

```dart
retry: (retryCount, error) {
  if (error is HttpException) {
    // Only retry 5xx errors and specific 4xx
    final retryableCodes = [500, 502, 503, 504, 429];
    if (!retryableCodes.contains(error.statusCode)) {
      return null;
    }
  }

  if (retryCount >= 3) return null;
  return Duration(seconds: retryCount + 1);
}
```

### Linear Backoff

```dart
retry: (retryCount, error) {
  if (retryCount >= 5) return null;
  return Duration(seconds: retryCount + 1);  // 1s, 2s, 3s, 4s, 5s
}
```

### Fixed Delay

```dart
retry: (retryCount, error) {
  if (retryCount >= 3) return null;
  return const Duration(seconds: 2);  // Always 2s
}
```

### Jittered Backoff

Add randomness to prevent thundering herd:

```dart
import 'dart:math';

final random = Random();

retry: (retryCount, error) {
  if (retryCount >= 3) return null;

  final baseDelay = pow(2, retryCount).toInt() * 1000;
  final jitter = random.nextInt(1000);

  return Duration(milliseconds: baseDelay + jitter);
}
```

## Configuring Default Retry

Set retry behavior for all queries:

```dart
final queryClient = QueryClient(
  defaultQueryOptions: DefaultQueryOptions(
    retry: retryExponentialBackoff(maxRetries: 5),
  ),
  defaultMutationOptions: DefaultMutationOptions(
    retry: retryNever,  // Default
  ),
);
```

## Per-Query Retry

Override defaults for specific queries:

```dart
// Critical data - more retries
useQuery(
  ['payments'],
  fetchPayments,
  retry: retryExponentialBackoff(maxRetries: 10),
);

// Non-critical - fewer retries
useQuery(
  ['suggestions'],
  fetchSuggestions,
  retry: (retryCount, error) => retryCount < 1 ? Duration(seconds: 1) : null,
);

// Never retry
useQuery(
  ['search', query],
  () => search(query),
  retry: retryNever,
);
```

## Mutation Retry

Enable retry for mutations when appropriate:

```dart
useMutation(
  (data, context) => submitForm(data),
  retry: (retryCount, error) {
    // Only retry network errors
    if (error is SocketException) {
      if (retryCount < 3) {
        return Duration(seconds: retryCount + 1);
      }
    }
    return null;
  },
);
```

:::warning
Be careful with mutation retries. Mutations that aren't idempotent (like creating orders) might cause duplicate operations.
:::

## Retry on Mount

Control whether failed queries retry when the component remounts:

```dart
useQuery(
  ['data'],
  fetchData,
  retryOnMount: true,   // Retry failed queries on mount (default)
  retryOnMount: false,  // Don't retry, show error immediately
);
```

## Monitoring Retries

The `QueryResult` includes retry information:

```dart
final result = useQuery(['data'], fetchData);

// Number of consecutive failures
print(result.failureCount);

// Show retry indicator
if (result.failureCount > 0 && result.isFetching) {
  return Text('Retrying (attempt ${result.failureCount + 1})...');
}
```

## Best Practices

### Don't Retry Non-Recoverable Errors

```dart
retry: (retryCount, error) {
  // Don't retry authentication errors
  if (error is UnauthorizedException) return null;

  // Don't retry validation errors
  if (error is ValidationException) return null;

  // Don't retry not found
  if (error is NotFoundException) return null;

  // Retry other errors
  if (retryCount >= 3) return null;
  return Duration(seconds: pow(2, retryCount).toInt());
}
```

### Use Shorter Delays for Background Queries

```dart
// User-facing query - longer delays acceptable
useQuery(
  ['profile'],
  fetchProfile,
  retry: retryExponentialBackoff(baseDelay: Duration(seconds: 2)),
);

// Background sync - shorter delays
useQuery(
  ['sync'],
  syncData,
  retry: retryExponentialBackoff(baseDelay: Duration(milliseconds: 500)),
);
```

### Cap Maximum Delay

Prevent excessively long waits:

```dart
retry: (retryCount, error) {
  if (retryCount >= 10) return null;

  final delay = pow(2, retryCount).toInt() * 1000;
  final cappedDelay = min(delay, 30000);  // Max 30 seconds

  return Duration(milliseconds: cappedDelay);
}
```
