part of 'query.dart';

class QueryObserver<T> implements Observer<QueryState<T>> {
  QueryObserver(this._state);

  Query<T>? _query;
  QueryState<T> _state;

  Query<T>? get query => _query;

  QueryState<T> get state => _state;

  @override
  void onNotified(QueryState<T> state) {
    this._state = state;
  }

  @override
  void onAdded(covariant Query<T> query) {
    this._query = query;
  }

  @override
  void onRemoved(covariant Query<T> query) {
    if (this._query == query) {
      this._query = null;
    }
  }
}
