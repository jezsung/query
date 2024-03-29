part of 'mutation.dart';

class MutationState<T> extends Equatable {
  const MutationState({
    this.status = MutationStatus.idle,
    this.data,
    this.error,
    this.dataUpdatedAt,
    this.errorUpdatedAt,
  });

  final MutationStatus status;
  final T? data;
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

  MutationState<T> copyWith({
    MutationStatus? status,
    T? data,
    Exception? error,
    DateTime? dataUpdatedAt,
    DateTime? errorUpdatedAt,
  }) {
    return MutationState<T>(
      status: status ?? this.status,
      data: data ?? this.data,
      error: error ?? this.error,
      dataUpdatedAt: dataUpdatedAt ?? this.dataUpdatedAt,
      errorUpdatedAt: errorUpdatedAt ?? this.errorUpdatedAt,
    );
  }

  MutationState<T> copyWithNull({
    bool data = false,
    bool error = false,
    bool dataUpdatedAt = false,
    bool errorUpdatedAt = false,
  }) {
    return MutationState<T>(
      status: status,
      data: data ? null : this.data,
      error: error ? null : this.error,
      dataUpdatedAt: dataUpdatedAt ? null : this.dataUpdatedAt,
      errorUpdatedAt: errorUpdatedAt ? null : this.errorUpdatedAt,
    );
  }

  @override
  List<Object?> get props => [
        status,
        data,
        error,
        dataUpdatedAt,
        errorUpdatedAt,
      ];
}
