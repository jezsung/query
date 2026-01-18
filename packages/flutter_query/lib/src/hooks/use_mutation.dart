import 'package:flutter_hooks/flutter_hooks.dart';

import '../core/core.dart';
import 'use_query_client.dart';

/// A hook for performing create, update, and delete operations.
///
/// Unlike [useQuery] which fetches data automatically, this hook returns a
/// [MutationResult] with a `mutate` function that you call imperatively to
/// trigger the mutation.
///
/// The [mutationFn] performs the actual mutation. It receives the variables
/// passed to `mutate` and a [MutationFunctionContext].
///
/// Returns a [MutationResult] containing the mutation state and control
/// methods. The widget rebuilds automatically when the mutation state changes.
///
/// ## Options
///
/// - [onMutate]: Called before the mutation executes. Use for optimistic
///   updates. The returned value is passed to other callbacks as `context`.
///
/// - [onSuccess]: Called when the mutation succeeds. Receives the data,
///   variables, and context from [onMutate].
///
/// - [onError]: Called when the mutation fails. Receives the error, variables,
///   and context from [onMutate].
///
/// - [onSettled]: Called when the mutation completes, regardless of success or
///   failure. Receives the data (if successful), error (if failed), variables,
///   and context from [onMutate].
///
/// - [mutationKey]: An optional key to identify this mutation in the cache.
///   Unlike query keys, mutation keys are not used for deduplication.
///
/// - [retry]: A callback that controls retry behavior on failure. Returns a
///   [Duration] to retry after waiting, or `null` to stop retrying. Defaults
///   to no retries.
///
/// - [gcDuration]: How long mutation data remains in cache after completion.
///   Defaults to 5 minutes.
///
/// - [meta]: A map of arbitrary metadata attached to this mutation.
///
/// - [client]: The [QueryClient] to use. If provided, takes precedence over
///   the nearest [QueryClientProvider] ancestor.
///
/// See also:
///
/// - [useQuery] for fetching data
/// - [useInfiniteQuery] for paginated data
MutationResult<TData, TError, TVariables, TOnMutateResult>
    useMutation<TData, TError, TVariables, TOnMutateResult>(
  MutateFn<TData, TVariables> mutationFn, {
  MutationOnMutate<TVariables, TOnMutateResult>? onMutate,
  MutationOnSuccess<TData, TVariables, TOnMutateResult>? onSuccess,
  MutationOnError<TError, TVariables, TOnMutateResult>? onError,
  MutationOnSettled<TData, TError, TVariables, TOnMutateResult>? onSettled,
  List<Object?>? mutationKey,
  GcDuration? gcDuration,
  RetryResolver<TError>? retry,
  Map<String, dynamic>? meta,
  QueryClient? client,
}) {
  final effectiveClient = useQueryClient(client);

  // Create observer once per component instance
  final observer = useMemoized(
    () => MutationObserver<TData, TError, TVariables, TOnMutateResult>(
      effectiveClient,
      MutationOptions<TData, TError, TVariables, TOnMutateResult>(
        mutationFn: mutationFn,
        mutationKey: mutationKey,
        meta: meta,
        onMutate: onMutate,
        onSuccess: onSuccess,
        onError: onError,
        onSettled: onSettled,
        gcDuration: gcDuration,
        retry: retry,
      ),
    ),
    [effectiveClient],
  );

  // Update options during render
  observer.options =
      MutationOptions<TData, TError, TVariables, TOnMutateResult>(
    mutationFn: mutationFn,
    mutationKey: mutationKey,
    meta: meta,
    onMutate: onMutate,
    onSuccess: onSuccess,
    onError: onError,
    onSettled: onSettled,
    gcDuration: gcDuration,
    retry: retry,
  );

  // Subscribe to observer and trigger rebuilds when result changes
  // Uses useState with useEffect subscription for synchronous updates
  final result = useState(observer.result);

  useEffect(() {
    final unsubscribe = observer.subscribe((newResult) {
      result.value = newResult;
    });
    return unsubscribe;
  }, [observer]);

  // Cleanup on unmount
  useEffect(() {
    return observer.onUnmount;
  }, [observer]);

  return result.value;
}
