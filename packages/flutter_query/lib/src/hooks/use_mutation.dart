import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_query/flutter_query.dart';

typedef Mutate<A> = Future<void> Function([A arg]);

class MutationResult<T, A> {
  MutationResult({
    required this.state,
    required this.mutate,
  });

  final MutationState<T> state;
  final Mutate<A> mutate;
}

MutationResult<T, A> useMutation<T, A>(
  Mutator<T, A> mutator,
) {
  final mutation = useMemoized<Mutation<T, A>>(
    () => Mutation<T, A>(),
  );
  final mutate = useCallback<Mutate<A>>(
    ([A? arg]) {
      if (null is! A && A != Never && arg == null) {
        throw ArgumentError.notNull();
      }
      return mutation.mutate(
        mutator: mutator,
        arg: arg,
      );
    },
  );
  final stateSnapshot = useStream<MutationState<T>>(
    mutation.stream,
    initialData: MutationState<T>(),
    preserveState: false,
  );

  return MutationResult<T, A>(
    state: stateSnapshot.requireData,
    mutate: mutate,
  );
}
