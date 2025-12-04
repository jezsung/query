---
sidebar_position: 4
---

# useMutation

This page documents the implemented behavior of the Flutter hook `useMutation` as found in `packages/flutter_query/lib/src/hooks/use_mutation.dart`.

> This reference describes only what the current source code implements and avoids describing features not present in the implementation.

## Signature

```dart
class MutationResult<T, P> {
  Function(P) mutate;
  T? data;
  MutationStatus status;
  Object? error;
  bool isIdle;
  bool isPending;
  bool isError;
  bool isSuccess;
}


MutationResult<T, P> useMutation<T, P>({
  required Future<T> Function(P) mutationFn,
  void Function(T?)? onSuccess,
  void Function(Object?)? onError,
  void Function(T?, Object?)? onSettle,
})
```

- Returns: `MutationResult<T, P>` — an object that exposes the `mutate` function and the internal mutation state (data, status, error).

## Parameters

- mutationFn (required)
  - Type: `Future<T> Function(P)`
  - The async function that will execute the mutation when `mutate` is called. It receives the variables of type `P` and must return a `Future` resolving to the mutation result value of type `T` or throw on error.

- onSuccess (optional)
  - Type: `void Function(T?)?`
  - Callback executed after a successful mutation. The hook will call this with the mutation result `data`.
  - The hook also invokes `QueryClient.instance.mutationCache?.config.onSuccess?.call(data)` if a mutation cache with callbacks is present.

- onError (optional)
  - Type: `void Function(Object?)?`
  - Callback executed when the mutation function throws an error. The hook will call this with the thrown error.
  - The hook also invokes `QueryClient.instance.mutationCache?.config.onError?.call(error)` if a mutation cache with callbacks is present.

- onSettle (optional)
  - Type: `void Function(T?, Object?)?`
  - Called after the mutation either succeeds or errors. Receives `(data, error)`.


## Return value — `MutationResult<T, P>`

`useMutation` returns a `MutationResult<T, P>` whose implementation (`packages/query_core/lib/src/mutation_types.dart`) exposes the following shape:

- mutate (Function(P))
  - A function that kicks off the mutation using the supplied variables of type `P`. In this implementation `mutate` is an `async` function but the hook returns a synchronous `Function` that internally performs `await`.

- data (T?)
  - The last successfully resolved result from the mutation. Initially `null`.

- error (Object?)
  - The most recent error thrown by the `mutationFn` (present when `status == MutationStatus.error`).
  
- status (MutationStatus)
  - Will be:
    - `idle`: initial status prior to the mutation function executing.
    - `pending`: if the mutation is currently executing.
    - `error`: if the last mutation attempt resulted in an error.
    - `success`: if the last mutation attempt was successful.

Derived boolean variables from status:

- isIdle — true when `status == MutationStatus.idle`.
- isPending — true when `status == MutationStatus.pending`.
- isError — true when `status == MutationStatus.error`.
- isSuccess — true when `status == MutationStatus.success`.

## Small example

The example below demonstrates a minimal Flutter Hooks UI using `useMutation` to add a new Todo item. It shows:

- calling `mutate` from the UI
- performing an optimistic update using `QueryClient.instance.setQueryData`
- invalidating the related query to ensure a fresh fetch after success

```dart
    final editMutation = useMutation<Todo, Todo>(
      mutationFn: (Todo body) => UpdateTodoApi.request(body),
      onSuccess: (deleted) {
        // Invalidate the todos query to refetch the updated list
        QueryClient.instance.invalidateQueries(queryKey: ['todos']);
      },
    );
```

