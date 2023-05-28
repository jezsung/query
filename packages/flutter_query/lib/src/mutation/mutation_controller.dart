part of 'mutation.dart';

class MutationController<T, P> extends MutationObserver<T, P>
    with ChangeNotifier
    implements ValueListenable<MutationState<T>> {
  MutationController() : super(MutationState<T>());

  _MutationWidgetState<T, P>? _widgetState;

  Mutator<T, P> get mutator {
    assert(_widgetState != null);
    return _widgetState!.mutator;
  }

  @override
  MutationState<T> get value => state;

  Future mutate([P? param]) async {
    assert(mutation != null);

    await mutation!.mutate(
      mutator: mutator,
      param: param,
    );
  }

  Future cancel() async {
    assert(mutation != null);

    await mutation!.cancel();
  }

  void reset() {
    assert(mutation != null);

    mutation!.reset();
  }

  void _attach(_MutationWidgetState<T, P> state) {
    _widgetState = state;
  }

  void _detach(_MutationWidgetState<T, P> state) {
    if (_widgetState == state) {
      _widgetState = null;
    }
  }

  @override
  void onNotified(MutationState<T> state) {
    super.onNotified(state);
    notifyListeners();
  }
}
