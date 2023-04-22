part of 'query.dart';

class QueryController<Data> extends ValueNotifier<QueryState<Data>> {
  QueryController({
    Data? data,
    DateTime? dataUpdatedAt,
  })  : _initialData = data,
        _initialDataUpdatedAt = dataUpdatedAt,
        super(QueryState<Data>());

  Query? _query;

  final Data? _initialData;
  final DateTime? _initialDataUpdatedAt;

  late QueryIdentifier _id;
  late QueryFetcher<Data> _fetcher;
  late bool _enabled;
  late Data? _placeholder;
  late Duration _staleDuration;
  late Duration _cacheDuration;
  late RetryCondition? _retryWhen;
  late int _retryMaxAttempts;
  late Duration _retryMaxDelay;
  late Duration _retryDelayFactor;
  late double _retryRandomizationFactor;
  late Duration? _refetchIntervalDuration;

  QueryIdentifier get id => _id;
  QueryFetcher<Data> get fetcher => _fetcher;
  bool get enabled => _enabled;
  Data? get placeholder => _placeholder;
  Duration get staleDuration => _staleDuration;
  Duration get cacheDuration => _cacheDuration;
  RetryCondition? get retryWhen => _retryWhen;
  int get retryMaxAttempts => _retryMaxAttempts;
  Duration get retryMaxDelay => _retryMaxDelay;
  Duration get retryDelayFactor => _retryDelayFactor;
  double get retryRandomizationFactor => _retryRandomizationFactor;
  Duration? get refetchIntervalDuration => _refetchIntervalDuration;

  @override
  QueryState<Data> get value {
    QueryState<Data> state = super.value;

    if (!state.hasData) {
      state = state.copyWith(data: _placeholder);
    }

    return state;
  }

  Future<void> refetch({
    Duration? staleDuration,
    RetryCondition? retryWhen,
    int? retryMaxAttempts,
    Duration? retryMaxDelay,
    Duration? retryDelayFactor,
    double? retryRandomizationFactor,
  }) async {
    await _query!.fetch(
      fetcher: _fetcher,
      staleDuration: staleDuration ?? _staleDuration,
      retryWhen: retryWhen ?? _retryWhen,
      retryMaxAttempts: retryMaxAttempts ?? _retryMaxAttempts,
      retryMaxDelay: retryMaxDelay ?? _retryMaxDelay,
      retryDelayFactor: retryDelayFactor ?? _retryDelayFactor,
      retryRandomizationFactor:
          retryRandomizationFactor ?? _retryRandomizationFactor,
    );
  }

  Future<void> cancel({
    Data? data,
    Exception? error,
  }) async {
    await _query!.cancel(
      data: data,
      error: error,
    );
  }

  void onStateUpdated(QueryState<Data> state) {
    value = state;
  }

  void onAddedToQuery(Query<Data> query) {
    _query = query;
    value = query.state;

    if (_initialData != null) {
      // ignore: null_check_on_nullable_type_parameter
      query.setData(_initialData!, _initialDataUpdatedAt);
    }
  }

  void onRemovedFromQuery(Query<Data> query) {
    _query = null;
  }
}
