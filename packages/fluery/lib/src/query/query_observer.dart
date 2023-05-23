part of 'index.dart';

class QueryObserver<T> extends ValueNotifier<QueryState<T>>
    implements QueryObserverBase<QueryState<T>> {
  QueryObserver() : super(QueryState<T>());

  _QueryWidgetState<T>? _widgetState;

  @protected
  Query<T> get query {
    assert(_widgetState != null);
    return _widgetState!.query;
  }

  QueryIdentifier get id {
    assert(_widgetState != null);
    return _widgetState!.id;
  }

  QueryFetcher<T> get fetcher {
    assert(_widgetState != null);
    return _widgetState!.fetcher;
  }

  bool get enabled {
    assert(_widgetState != null);
    return _widgetState!.enabled;
  }

  T? get initialData {
    assert(_widgetState != null);
    return _widgetState!.initialData;
  }

  DateTime? get initialDataUpdatedAt {
    assert(_widgetState != null);
    return _widgetState!.initialDataUpdatedAt;
  }

  T? get placeholder {
    assert(_widgetState != null);
    return _widgetState!.placeholder;
  }

  Duration get staleDuration {
    assert(_widgetState != null);
    return _widgetState!.staleDuration;
  }

  Duration get cacheDuration {
    assert(_widgetState != null);
    return _widgetState!.cacheDuration;
  }

  RetryCondition? get retryWhen {
    assert(_widgetState != null);
    return _widgetState!.retryWhen;
  }

  int get retryMaxAttempts {
    assert(_widgetState != null);
    return _widgetState!.retryMaxAttempts;
  }

  Duration get retryMaxDelay {
    assert(_widgetState != null);
    return _widgetState!.retryMaxDelay;
  }

  Duration get retryDelayFactor {
    assert(_widgetState != null);
    return _widgetState!.retryDelayFactor;
  }

  double get retryRandomizationFactor {
    assert(_widgetState != null);
    return _widgetState!.retryRandomizationFactor;
  }

  Duration? get refetchIntervalDuration {
    assert(_widgetState != null);
    return _widgetState!.refetchIntervalDuration;
  }

  @override
  QueryState<T> get value {
    QueryState<T> state = super.value;

    if (!state.hasData) {
      state = state.copyWith(data: placeholder);
    }

    return state;
  }

  @override
  void onStateChanged(QueryState<T> state) {
    value = state;
  }

  void _attach(_QueryWidgetState<T> widgetState) {
    _widgetState = widgetState;
  }

  void _detach(_QueryWidgetState<T> widgetState) {
    if (_widgetState == widgetState) {
      _widgetState = null;
    }
  }
}
