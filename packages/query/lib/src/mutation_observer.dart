part of 'mutation.dart';

class MutationObserver<T, P> implements Observer<MutationState<T>> {
  MutationObserver(this._widgetState);

  Mutation<T, P>? _mutation;
  MutationState<T> _widgetState;

  Mutation<T, P>? get mutation => _mutation;

  MutationState<T> get state => _widgetState;

  @override
  void onNotified(MutationState<T> state) {
    this._widgetState = state;
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
