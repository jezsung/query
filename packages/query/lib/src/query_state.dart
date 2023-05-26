part of 'query.dart';

class QueryState<T> extends Equatable {
  const QueryState({
    this.status = QueryStatus.idle,
    this.data,
    this.isInvalidated = false,
    this.dataUpdatedAt,
    this.error,
    this.errorUpdatedAt,
  });

  final QueryStatus status;
  final T? data;
  final Exception? error;
  final DateTime? dataUpdatedAt;
  final DateTime? errorUpdatedAt;
  final bool isInvalidated;

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
    bool? isInvalidated,
  }) {
    return QueryState<T>(
      status: status ?? this.status,
      data: data ?? this.data,
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
        error,
        dataUpdatedAt,
        errorUpdatedAt,
        isInvalidated,
      ];
}
