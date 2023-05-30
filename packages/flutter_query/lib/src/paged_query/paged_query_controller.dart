part of 'paged_query.dart';

class PagedQueryController<T, P> extends PagedQueryObserver<T, P>
    with ChangeNotifier
    implements ValueListenable<PagedQueryState<T>> {
  PagedQueryController() : super(PagedQueryState<T>());

  _PagedQueryWidgetState<T, P>? _widgetState;

  QueryId get id {
    assert(_widgetState != null);
    return _widgetState!.id;
  }

  PagedQueryFetcher<T, P> get fetcher {
    assert(_widgetState != null);
    return _widgetState!.fetcher;
  }

  P get initialPageParam {
    assert(_widgetState != null);
    return _widgetState!.initialPageParam;
  }

  PagedQueryParamBuilder<T, P>? get nextPageParamBuilder {
    assert(_widgetState != null);
    return _widgetState!.nextPageParamBuilder;
  }

  PagedQueryParamBuilder<T, P>? get previousPageParamBuilder {
    assert(_widgetState != null);
    return _widgetState!.previousPageParamBuilder;
  }

  Pages<T>? get placeholder {
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

  @override
  PagedQueryState<T> get value => state;

  Future fetchInitialPage() async {
    assert(query != null);

    await query!.fetch(
      fetcher: fetcher,
      initialPageParam: initialPageParam,
      nextPageParamBuilder: nextPageParamBuilder,
      previousPageParamBuilder: previousPageParamBuilder,
      staleDuration: staleDuration,
    );
  }

  Future fetchNextPage() async {
    assert(query != null);
    assert(nextPageParamBuilder != null);

    await query!.fetchNextPage(
      fetcher: fetcher,
      nextPageParamBuilder: nextPageParamBuilder!,
      previousPageParamBuilder: previousPageParamBuilder,
    );
  }

  Future fetchPreviousPage() async {
    assert(query != null);
    assert(previousPageParamBuilder != null);

    await query!.fetchPreviousPage(
      fetcher: fetcher,
      nextPageParamBuilder: nextPageParamBuilder,
      previousPageParamBuilder: previousPageParamBuilder!,
    );
  }

  @internal
  @override
  void onNotified(PagedQueryState<T> state) {
    PagedQueryState<T> temp = state;

    if (!temp.hasData) {
      assert(temp.data == null);
      temp = temp.copyWith(data: placeholder);
    }

    super.onNotified(temp);
    notifyListeners();
  }

  @internal
  @override
  void onAdded(covariant PagedQuery<T, P> query) {
    super.onAdded(query);

    if (query.state.status.isIdle) {
      query.fetch(
        fetcher: fetcher,
        initialPageParam: initialPageParam,
        nextPageParamBuilder: nextPageParamBuilder,
        previousPageParamBuilder: previousPageParamBuilder,
        staleDuration: staleDuration,
      );
    }
  }

  void _attach(_PagedQueryWidgetState<T, P> state) {
    _widgetState = state;
  }

  void _detach(_PagedQueryWidgetState<T, P> state) {
    if (_widgetState == state) {
      _widgetState = null;
    }
  }
}
