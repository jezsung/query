part of 'index.dart';

class QueryController<T> extends QueryObserver<T> {
  Future refetch() async {
    await query.fetch(
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
    query.setData(data, updatedAt);
  }

  void invalidate() {
    query.invalidate();
  }
}
