part of 'index.dart';

class QueryController<T> extends QueryObserver<T> {
  Query<T> get _query {
    assert(_widgetState != null);
    return _widgetState!.query;
  }

  Future refetch() async {
    await _query.fetch(
      fetcher: fetcher,
      staleDuration: staleDuration,
      retryWhen: retryWhen,
      retryMaxAttempts: retryMaxAttempts,
      retryMaxDelay: retryMaxDelay,
      retryDelayFactor: retryDelayFactor,
      retryRandomizationFactor: retryRandomizationFactor,
    );
  }

  void setData(T data, [DateTime? updatedAt]) {
    _query.setData(data, updatedAt);
  }

  void invalidate() {
    _query.invalidate();
  }
}
