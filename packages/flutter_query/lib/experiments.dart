/// Experimental, Dart-idiomatic query APIs.
///
/// Opt in with `import 'package:flutter_query/experiments.dart';`. This library
/// re-exports `useQuery`, `useMutation`, and `useInfiniteQuery` that return
/// `sealed`, pattern-matchable snapshots. It deliberately reuses those hook
/// names, so when importing alongside the main library, hide the canonical
/// ones:
///
/// ```dart
/// import 'package:flutter_query/flutter_query.dart'
///     hide useQuery, useMutation, useInfiniteQuery;
/// import 'package:flutter_query/experiments.dart';
/// ```
library;

export 'src/experiments/infinite_query_snapshot.dart'
    show
        InfiniteQuerySnapshot,
        InfiniteQueryPending,
        InfiniteQuerySuccess,
        InfiniteQueryError;
export 'src/experiments/mutation_snapshot.dart'
    show
        MutationSnapshot,
        MutationIdle,
        MutationPending,
        MutationSuccess,
        MutationError;
export 'src/experiments/query_snapshot.dart'
    show QuerySnapshot, QueryPending, QuerySuccess, QueryError;
export 'src/experiments/use_infinite_query.dart' show useInfiniteQuery;
export 'src/experiments/use_mutation.dart' show useMutation;
export 'src/experiments/use_query.dart' show useQuery;
