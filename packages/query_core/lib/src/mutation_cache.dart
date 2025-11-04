class MutationCacheConfig {
  final dynamic Function(dynamic error)? onError;
  final dynamic Function(dynamic data)? onSuccess;
  final dynamic Function()? onMutate;

  MutationCacheConfig({this.onError, this.onSuccess, this.onMutate});
}

class MutationCache {
  final MutationCacheConfig config;

  MutationCache({required this.config});
}
