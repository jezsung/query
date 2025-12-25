import 'dart:async';

import 'mutation_function_context.dart';
import 'query_function_context.dart';

/// Function that fetches data for a query.
///
/// The function receives a [QueryFunctionContext] containing the query key, client,
/// and abort signal for cancellation support.
typedef QueryFn<TData> = Future<TData> Function(QueryFunctionContext context);

/// Callback invoked before the mutation function is executed.
///
/// Can be used to perform optimistic updates. The returned value is passed
/// to onSuccess, onError, and onSettled callbacks as `onMutateResult`.
typedef MutationOnMutate<TVariables, TOnMutateResult>
    = FutureOr<TOnMutateResult?> Function(
  TVariables variables,
  MutationFunctionContext context,
);

/// Callback invoked when the mutation is successful.
typedef MutationOnSuccess<TData, TVariables, TOnMutateResult> = FutureOr<void>
    Function(
  TData data,
  TVariables variables,
  TOnMutateResult? onMutateResult,
  MutationFunctionContext context,
);

/// Callback invoked when the mutation encounters an error.
typedef MutationOnError<TError, TVariables, TOnMutateResult> = FutureOr<void>
    Function(
  TError error,
  TVariables variables,
  TOnMutateResult? onMutateResult,
  MutationFunctionContext context,
);

/// Callback invoked when the mutation is either successful or errors.
typedef MutationOnSettled<TData, TError, TVariables, TOnMutateResult>
    = FutureOr<void> Function(
  TData? data,
  TError? error,
  TVariables variables,
  TOnMutateResult? onMutateResult,
  MutationFunctionContext context,
);
