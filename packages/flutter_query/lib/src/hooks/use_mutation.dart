import 'package:flutter_hooks/flutter_hooks.dart';

import '../core/core.dart';
import 'use_query_client.dart';

/// Hook for performing mutations (create, update, delete operations).
///
/// Unlike useQuery which fetches data automatically, useMutation returns
/// a `mutate` function that you call to trigger the mutation.
///
/// Example:
/// ```dart
/// final mutation = useMutation<User, ApiError, CreateUserInput, PreviousUsers>(
///   (input, context) => api.createUser(input),
///   onSuccess: (data, variables, context, fnContext) {
///     // Invalidate and refetch related queries
///     fnContext.client.invalidateQueries(queryKey: ['users']);
///   },
/// );
///
/// // In your UI:
/// ElevatedButton(
///   onPressed: mutation.isPending
///     ? null
///     : () => mutation.mutate(CreateUserInput(name: 'John')),
///   child: Text(mutation.isPending ? 'Creating...' : 'Create User'),
/// );
/// ```
MutationResult<TData, TError, TVariables, TOnMutateResult>
    useMutation<TData, TError, TVariables, TOnMutateResult>(
  MutateFn<TData, TVariables> mutationFn, {
  MutationOnMutate<TVariables, TOnMutateResult>? onMutate,
  MutationOnSuccess<TData, TVariables, TOnMutateResult>? onSuccess,
  MutationOnError<TError, TVariables, TOnMutateResult>? onError,
  MutationOnSettled<TData, TError, TVariables, TOnMutateResult>? onSettled,
  List<Object?>? mutationKey,
  RetryResolver<TError>? retry,
  GcDuration? gcDuration,
  Map<String, dynamic>? meta,
  QueryClient? queryClient,
}) {
  final client = useQueryClient(queryClient);

  // Build options (merging with defaults happens in MutationObserver)
  MutationOptions<TData, TError, TVariables, TOnMutateResult> buildOptions() {
    return MutationOptions<TData, TError, TVariables, TOnMutateResult>(
      mutationFn: mutationFn,
      mutationKey: mutationKey,
      meta: meta,
      onMutate: onMutate,
      onSuccess: onSuccess,
      onError: onError,
      onSettled: onSettled,
      retry: retry,
      gcDuration: gcDuration,
    );
  }

  // Create observer once per component instance
  final observer = useMemoized(
    () => MutationObserver<TData, TError, TVariables, TOnMutateResult>(
      client,
      buildOptions(),
    ),
    [],
  );

  // Update options during render
  observer.options = buildOptions();

  // Subscribe to observer and trigger rebuilds when result changes
  final result = useState(observer.result);

  useEffect(() {
    final unsubscribe = observer.subscribe((newResult) {
      result.value = newResult;
    });
    return unsubscribe;
  }, []);

  // Cleanup on unmount
  useEffect(() {
    return observer.onUnmount;
  }, [observer]);

  return result.value;
}
