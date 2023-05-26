part of 'query.dart';

class QueryObserver<T> implements Observer<QueryState<T>> {
  QueryObserver(this.state);

  Query<T>? query;
  QueryState<T> state;

  @override
  void onNotified(QueryState<T> state) {
    this.state = state;
  }

  @override
  void onAdded(covariant Query<T> query) {
    this.query = query;
  }

  @override
  void onRemoved(covariant Query<T> query) {
    if (this.query == query) {
      this.query = null;
    }
  }
}
