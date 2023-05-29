part of 'query.dart';

class PagedQueryObserver<T, P> implements Observer<PagedQueryState<T>> {
  PagedQueryObserver(this._state);

  PagedQuery<T, P>? _query;
  PagedQueryState<T> _state;

  PagedQuery<T, P>? get query => _query;

  PagedQueryState<T> get state => _state;

  @override
  void onNotified(PagedQueryState<T> state) {
    _state = state;
  }

  @override
  void onAdded(covariant PagedQuery<T, P> query) {
    _query = query;
    _state = query.state;
  }

  @override
  void onRemoved(covariant PagedQuery<T, P> query) {
    if (_query == query) {
      _query = null;
    }
  }
}
