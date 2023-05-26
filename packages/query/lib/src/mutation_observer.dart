part of 'mutation.dart';

class MutationObserver<T, P> implements Observer<MutationState<T>> {
  MutationObserver(this.state);

  Mutation<T, P>? mutation;
  MutationState<T> state;

  @override
  void onNotified(MutationState<T> state) {
    this.state = state;
  }

  @override
  void onAdded(covariant Mutation<T, P> mutatoin) {
    this.mutation = mutation;
  }

  @override
  void onRemoved(covariant Mutation<T, P> mutatoin) {
    if (this.mutation == mutatoin) {
      this.mutation = null;
    }
  }
}
