part of 'paged_query.dart';

class PagedQueryObserver<T, P> extends ValueNotifier<PagedQueryState<T, P>>
    implements StateListener<PagedQueryState<T, P>> {
  PagedQueryObserver({
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
  }) : super(PagedQueryState<T, P>());

  PagedQueryFetcher<T, P> fetcher;
  PagedQueryParamBuilder<T, P>? nextPageParamBuilder;
  PagedQueryParamBuilder<T, P>? previousPageParamBuilder;
  bool enabled;
  Pages<T>? placeholder;
  Duration staleDuration;
  Duration cacheDuration;
  RetryCondition? retryWhen;
  int retryMaxAttempts;
  Duration retryMaxDelay;
  Duration retryDelayFactor;
  double retryRandomizationFactor;

  @override
  PagedQueryState<T, P> get value {
    PagedQueryState<T, P> state = super.value;

    if (state.status.isIdle && enabled) {
      state = state.copyWith(status: QueryStatus.fetching);
    }

    if (!state.hasData) {
      state = state.copyWith(data: placeholder);
    }

    return state;
  }

  PagedQuery<T, P>? _query;
  StreamSubscription? _subscription;

  void bind(PagedQuery<T, P> query) {
    _query = query;
    value = query.state;
    _subscription = query.stream.listen(_onStateChanged);
    query.addObserver(this);
  }

  void unbind() {
    if (_query == null) return;

    _subscription?.cancel();
    _query!.removeObserver(this);
    _query = null;
  }

  void _onStateChanged(PagedQueryState<T, P> state) {
    value = state;
  }

  @override
  void onListen(PagedQueryState<T, P> state) {
    value = state;
  }
}
