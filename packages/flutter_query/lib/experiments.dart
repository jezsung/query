/// Experimental, Dart-idiomatic query APIs.
///
/// Opt in with `import 'package:flutter_query/experiments.dart';`. This library
/// re-exports a `useQuery` that returns a [QuerySnapshot]. It deliberately
/// reuses the `useQuery` name, so when importing alongside the main library,
/// hide the canonical one:
///
/// ```dart
/// import 'package:flutter_query/flutter_query.dart' hide useQuery;
/// import 'package:flutter_query/experiments.dart';
/// ```
library;

export 'src/experiments/query_snapshot.dart'
    show QuerySnapshot, QueryPending, QuerySuccess, QueryError;
export 'src/experiments/use_query.dart' show useQuery;
