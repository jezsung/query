import 'package:query_core/src/types.dart';

class MutationState<T> {
  final T? data;
  final MutationStatus status;
  final Object? error;

  MutationState(this.data, this.status, this.error);

  bool get isIdle => status == MutationStatus.idle;
  bool get isPending => status == MutationStatus.pending;
  bool get isError => status == MutationStatus.error;
  bool get isSuccess => status == MutationStatus.success;
}

class MutationResult<T, P> {
  final Function(P) mutate;
  final T? data;
  final MutationStatus status;
  final Object? error;

  MutationResult(this.mutate, this.data, this.status, this.error);

  bool get isIdle => status == MutationStatus.idle;
  bool get isPending => status == MutationStatus.pending;
  bool get isError => status == MutationStatus.error;
  bool get isSuccess => status == MutationStatus.success;
}
