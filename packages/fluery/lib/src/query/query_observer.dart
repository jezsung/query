part of 'query.dart';

class QueryObserver<T> extends ValueNotifier<QueryState<T>> {
  QueryObserver({
    required this.fetcher,
    this.enabled = true,
    this.placeholder,
    this.staleDuration = Duration.zero,
    this.cacheDuration = const Duration(minutes: 5),
    this.retryWhen,
    this.retryMaxAttempts = 3,
    this.retryMaxDelay = const Duration(seconds: 30),
    this.retryDelayFactor = const Duration(milliseconds: 200),
    this.retryRandomizationFactor = 0.25,
    this.refetchIntervalDuration,
  }) : super(QueryState<T>());

  QueryFetcher<T> fetcher;
  bool enabled;
  T? placeholder;
  Duration staleDuration;
  Duration cacheDuration;
  RetryCondition? retryWhen;
  int retryMaxAttempts;
  Duration retryMaxDelay;
  Duration retryDelayFactor;
  double retryRandomizationFactor;
  Duration? refetchIntervalDuration;

  Query<T>? _query;
  StreamSubscription<QueryState<T>>? _subscription;

  @override
  QueryState<T> get value {
    QueryState<T> state = super.value;

    if (!state.hasData) {
      state = state.copyWith(data: placeholder);
    }

    return state;
  }

  Future<void> fetch({
    QueryFetcher<T>? fetcher,
    Duration? staleDuration,
    RetryCondition? retryWhen,
    int? retryMaxAttempts,
    Duration? retryMaxDelay,
    Duration? retryDelayFactor,
    double? retryRandomizationFactor,
  }) async {
    assert(
      _query != null,
      '''
      Tried to call QueryObserver<${T.runtimeType}>.fetch before it gets bound.

      Bind the QueryObserver<${T.runtimeType}>.
      ''',
    );

    if (!enabled) return;

    await _query!.fetch(
      fetcher: fetcher ?? this.fetcher,
      staleDuration: staleDuration ?? this.staleDuration,
      retryWhen: retryWhen ?? this.retryWhen,
      retryMaxAttempts: retryMaxAttempts ?? this.retryMaxAttempts,
      retryMaxDelay: retryMaxDelay ?? this.retryMaxDelay,
      retryDelayFactor: retryDelayFactor ?? this.retryDelayFactor,
      retryRandomizationFactor:
          retryRandomizationFactor ?? this.retryRandomizationFactor,
    );
  }

  void bind(Query<T> query) {
    _query = query;
    value = query.state;
    _subscription = query.stream.listen(_onStateChanged);
    _query!.addObserver(this);
  }

  void unbind() {
    if (_query == null) return;

    _subscription?.cancel();
    _query!.removeObserver(this);
    _query = null;
  }

  void _onStateChanged(QueryState<T> state) {
    value = state;
  }
}
