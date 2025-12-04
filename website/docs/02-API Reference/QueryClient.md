---
sidebar_position: 1
---

# QueryClient

The QueryClient can be used to interact with a cache:
```dart
queryClient = QueryClient(
  defaultOptions: const DefaultOptions(
    queries: QueryDefaultOptions(
      enabled: true,
      staleTime: 0,
      refetchOnRestart: false,
      refetchOnReconnect: false,
    ),
  ),
  queryCache: QueryCache(config: QueryCacheConfig(onError: (e) => print(e))),
  mutationCache: MutationCache(config: MutationCacheConfig(onError: (e) => print(e))),
);
```

## Options


- `queryCache` - Optional. The query cache this client is connected to.
- `mutationCache` - Optional. The mutation cache this client is connected to.
- `defaultOptions` - Optional. Define defaults for all queries and mutations using this queryClient.

### `refetechOnReconnect`
Iterates over all listeners and calls their `refetchCallBack()` if either the listener's `refetechOnReconnect` is true
> **Need implementation:**  
> ```dart
> import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
> import 'package:flutter_query/flutter_query.dart';
> 
> static InternetConnection connectivity = InternetConnection();
> 
> connectivity.onStatusChange.listen((status) {
>   if (status case InternetStatus.connected) {
>     QueryClient.instance.refetchOnReconnect();
>   }
> });
> ```


### `refetchOnRestart`
Iterates over all listeners and calls their `refetchCallBack()` if either the listener's `refetchOnRestart` is true
> **Need implementation:**  
> ```dart
> AppLifecycleListener(
>   onRestart: () {
>     QueryClient.instance.refetchOnRestart();
>   },
>   child: MyApp(),
> );
> ```

#### setQueryData

`setQueryData` is a synchronous function that can be used to immediately update a query's cached data
it take an updater function

```dart
queryClient.setQueryData(['todo', todoId], (oldData) => {... oldData});
```

#### invalidateQueries

The `invalidateQueries` method can be used to invalidate and refetch single or multiple queries in the cache based on their query keys or any other functionally accessible property/state of the query. By default, all matching queries are immediately marked as invalid and active queries are refetched in the background.

Invalidates all queries starting with 'todos'
 ```dart
 queryClient.invalidateQueries(queryKey: ["todos"]);
 ```

Invalidates only the query with key exactly ['todos']
 ```dart
  queryClient.invalidateQueries(queryKey: ["todos"], exact: true);
 ```

#### clear

The `clear` method clears all connected caches.

```dart
queryClient.clear();
```