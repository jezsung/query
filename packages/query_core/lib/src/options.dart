// Core-level small types and default options

class QueryDefaultOptions {
  final bool enabled;
  final double? staleTime;
  final bool refetchOnRestart;
  final bool refetchOnReconnect;

  const QueryDefaultOptions(
      {this.enabled = true, this.staleTime = 0, this.refetchOnRestart = true, this.refetchOnReconnect = true});
}

class MutationDefaultOptions {
  const MutationDefaultOptions();
}

class DefaultOptions {
  final QueryDefaultOptions queries;
  final MutationDefaultOptions mutations;

  const DefaultOptions({this.queries = const QueryDefaultOptions(), this.mutations = const MutationDefaultOptions()});
}
