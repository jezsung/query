part of 'index.dart';

class QueryState<T> extends Equatable {
  const QueryState({
    this.status = QueryStatus.idle,
    this.data,
    this.isRetrying = false,
    this.isInvalidated = false,
    this.dataUpdatedAt,
    this.error,
    this.errorUpdatedAt,
  });

  final QueryStatus status;
  final T? data;
  final bool isRetrying;
  final bool isInvalidated;
  final Exception? error;
  final DateTime? dataUpdatedAt;
  final DateTime? errorUpdatedAt;

  bool get hasData => data != null;

  bool get hasError => error != null;

  DateTime? get lastUpdatedAt {
    if (dataUpdatedAt != null && errorUpdatedAt != null) {
      return dataUpdatedAt!.isAfter(errorUpdatedAt!)
          ? dataUpdatedAt
          : errorUpdatedAt;
    } else if (dataUpdatedAt != null) {
      return dataUpdatedAt;
    } else if (errorUpdatedAt != null) {
      return errorUpdatedAt;
    } else {
      return null;
    }
  }

  QueryState<T> copyWith({
    QueryStatus? status,
    T? data,
    bool? isRetrying,
    bool? isInvalidated,
    Exception? error,
    DateTime? dataUpdatedAt,
    DateTime? errorUpdatedAt,
  }) {
    return QueryState<T>(
      status: status ?? this.status,
      data: data ?? this.data,
      isRetrying: isRetrying ?? this.isRetrying,
      isInvalidated: isInvalidated ?? this.isInvalidated,
      error: error ?? this.error,
      dataUpdatedAt: dataUpdatedAt ?? this.dataUpdatedAt,
      errorUpdatedAt: errorUpdatedAt ?? this.errorUpdatedAt,
    );
  }

  @override
  List<Object?> get props => [
        status,
        data,
        isRetrying,
        isInvalidated,
        error,
        dataUpdatedAt,
        errorUpdatedAt,
      ];
}
