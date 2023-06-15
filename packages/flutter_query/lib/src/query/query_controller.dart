part of 'query.dart';

class QueryController<T> extends QueryObserver<T>
    with ChangeNotifier
    implements ValueListenable<QueryState<T>> {
  QueryController({
    T? data,
    DateTime? updatedAt,
  })  : _initialData = data,
        _initialDataUpdatedAt = updatedAt,
        super(QueryState<T>());

  final T? _initialData;
  final DateTime? _initialDataUpdatedAt;

  _QueryWidgetState<T>? _state;

  QueryId get id {
    assert(_state != null);
    return _state!.id;
  }

  QueryFetcher<T> get fetcher {
    assert(_state != null);
    return _state!.fetcher;
  }

  T? get placeholder {
    assert(_state != null);
    return _state!.placeholder;
  }

  Duration get staleDuration {
    assert(_state != null);
    return _state!.staleDuration;
  }

  Duration get cacheDuration {
    assert(_state != null);
    return _state!.cacheDuration;
  }

  @override
  QueryState<T> get value => state;

  Future refetch() async {
    assert(query != null);

    await query!.fetch(
      fetcher: fetcher,
      staleDuration: staleDuration,
    );
  }

  Future cancel() async {
    assert(query != null);

    await query!.cancel();
  }

  void setData(
    T data, [
    DateTime? updatedAt,
  ]) {
    assert(query != null);

    query!.setData(data, updatedAt);
  }

  @internal
  @override
  void onNotified(QueryState<T> state) {
    QueryState<T> temp = state;

    if (!temp.hasData) {
      assert(temp.data == null);
      temp = temp.copyWith(data: placeholder);
    }

    super.onNotified(temp);
    notifyListeners();
  }

  @internal
  @override
  void onAdded(covariant Query<T> query) {
    super.onAdded(query);

    _state!.cacheStorage.cancelGarbageCollection(id);

    if (_initialData != null) {
      query.setInitialData(
        _initialData!,
        _initialDataUpdatedAt,
      );
    }
  }

  @override
  void onRemoved(covariant Query<T> query) {
    super.onRemoved(query);

    if (query.observers.isEmpty) {
      _state!.cacheStorage.scheduleGarbageCollection(id, cacheDuration);
    }
  }

  void _attach(_QueryWidgetState<T> state) {
    _state = state;
  }

  void _detach(_QueryWidgetState<T> state) {
    if (_state == state) {
      _state = null;
    }
  }
}
