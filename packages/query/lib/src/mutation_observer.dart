part of 'mutation.dart';

class MutationObserver<T, P> implements Observer<MutationState<T>> {
  MutationObserver(this._state);

  Mutation<T, P>? _mutation;
  MutationState<T> _state;

  MutationState<T> get state => _state;

  @override
  void onNotified(MutationState<T> state) {
    this._state = state;
  }

  @override
  void onAdded(covariant Mutation<T, P> mutatoin) {
    this._mutation = _mutation;
  }

  @override
  void onRemoved(covariant Mutation<T, P> mutatoin) {
    if (this._mutation == mutatoin) {
      this._mutation = null;
    }
  }
}
