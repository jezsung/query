enum QueryStatus {
  idle,
  fetching,
  retrying,
  success,
  failure,
}

extension QueryStatusExtension on QueryStatus {
  bool get isIdle => this == QueryStatus.idle;

  bool get isFetching => this == QueryStatus.fetching;

  bool get isRetrying => this == QueryStatus.retrying;

  bool get isLoading => isFetching || isRetrying;

  bool get isSuccess => this == QueryStatus.success;

  bool get isFailure => this == QueryStatus.failure;
}
