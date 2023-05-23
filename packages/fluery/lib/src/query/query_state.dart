part of 'query.dart';

class QueryState<T> extends Equatable {
  const QueryState({
    this.status = QueryStatus.idle,
    this.data,
    this.dataUpdatedAt,
    this.error,
    this.errorUpdatedAt,
    this.invalidated = false,
  });

  final QueryStatus status;
  final T? data;
  final Exception? error;
  final DateTime? dataUpdatedAt;
  final DateTime? errorUpdatedAt;
  final bool invalidated;

  bool get inProgress => status.isFetching || status.isRetrying;

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
    Exception? error,
    DateTime? dataUpdatedAt,
    DateTime? errorUpdatedAt,
    bool? invalidated,
  }) {
    return QueryState<T>(
      status: status ?? this.status,
      data: data ?? this.data,
      error: error ?? this.error,
      dataUpdatedAt: dataUpdatedAt ?? this.dataUpdatedAt,
      errorUpdatedAt: errorUpdatedAt ?? this.errorUpdatedAt,
      invalidated: invalidated ?? this.invalidated,
    );
  }

  @override
  List<Object?> get props => [
        status,
        data,
        error,
        dataUpdatedAt,
        errorUpdatedAt,
        invalidated,
      ];
}
