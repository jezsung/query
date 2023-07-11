part of 'query.dart';

typedef Pages<T> = List<T>;

typedef PagedQueryFetcher<T, P> = Future<T> Function(QueryKey key, P? param);

typedef PagedQueryParamBuilder<T, P> = P? Function(Pages<T> pages);

class PagedQuery<T extends Object, P> {
  PagedQuery(this.key) : _state = PagedQueryState<T>();

  final QueryKey key;

  final _stateController = StreamController<PagedQueryState<T>>.broadcast();
  Stream<PagedQueryState<T>> get stream => _stateController.stream;

  PagedQueryState<T> _state;
  PagedQueryState<T> get state => _state;
  set state(PagedQueryState<T> value) {
    _state = value;
    _stateController.add(value);
  }

  CancelableOperation<T>? _cancelableOperation;

  Future fetch({
    required PagedQueryFetcher<T, P> fetcher,
    required PagedQueryParamBuilder<T, P>? nextPageParamBuilder,
    required PagedQueryParamBuilder<T, P>? previousPageParamBuilder,
    required Duration staleDuration,
  }) async {
    if (state.status.isFetching) return;

    if (!isStale(staleDuration) && !state.isInvalidated) return;

    final stateBeforeFetching = state.copyWith();

    state = state.copyWith(
      status: QueryStatus.fetching,
      isInvalidated: false,
    );

    try {
      _cancelableOperation =
          CancelableOperation<T>.fromFuture(fetcher(key, null));

      final data = await _cancelableOperation!.valueOrCancellation();

      if (_cancelableOperation!.isCanceled) {
        state = stateBeforeFetching;
        return;
      }

      final pages = [data!];
      final hasNextPage = nextPageParamBuilder?.call(pages) != null;
      final hasPreviousPage = previousPageParamBuilder?.call(pages) != null;

      state = state.copyWith(
        status: QueryStatus.success,
        data: pages,
        dataUpdatedAt: clock.now(),
        hasNextPage: hasNextPage,
        hasPreviousPage: hasPreviousPage,
      );
    } on Exception catch (error) {
      state = state.copyWith(
        status: QueryStatus.failure,
        error: error,
        errorUpdatedAt: clock.now(),
      );
    }
  }

  Future fetchNextPage({
    required PagedQueryFetcher<T, P> fetcher,
    required PagedQueryParamBuilder<T, P> nextPageParamBuilder,
    required PagedQueryParamBuilder<T, P>? previousPageParamBuilder,
  }) async {
    if (state.isFetchingNextPage) return;

    if (state.isInvalidated) return;

    final stateBeforeFetching = state.copyWith();

    state = state.copyWith(
      status: QueryStatus.fetching,
      isFetchingNextPage: true,
      isInvalidated: false,
    );

    try {
      final param = nextPageParamBuilder(state.pages);
      assert(param != null);

      _cancelableOperation = CancelableOperation<T>.fromFuture(
        fetcher(key, param!),
      );

      final data = await _cancelableOperation!.valueOrCancellation();

      if (_cancelableOperation!.isCanceled) {
        state = stateBeforeFetching;
        return;
      }

      final pages = [...state.pages, data!];
      final hasNextPage = nextPageParamBuilder(pages) != null;
      final hasPreviousPage = previousPageParamBuilder?.call(pages) != null;

      state = state.copyWith(
        status: QueryStatus.success,
        data: pages,
        dataUpdatedAt: clock.now(),
        isFetchingNextPage: false,
        hasNextPage: hasNextPage,
        hasPreviousPage: hasPreviousPage,
      );
    } on Exception catch (error) {
      state = state.copyWith(
        status: QueryStatus.failure,
        error: error,
        errorUpdatedAt: clock.now(),
        isFetchingNextPage: false,
      );
    }
  }

  Future fetchPreviousPage({
    required PagedQueryFetcher<T, P> fetcher,
    required PagedQueryParamBuilder<T, P>? nextPageParamBuilder,
    required PagedQueryParamBuilder<T, P> previousPageParamBuilder,
  }) async {
    if (state.isFetchingPreviousPage) return;

    if (state.isInvalidated) return;

    final stateBeforeFetching = state.copyWith();

    state = state.copyWith(
      status: QueryStatus.fetching,
      isFetchingPreviousPage: true,
      isInvalidated: false,
    );

    try {
      final param = previousPageParamBuilder(state.pages);
      assert(param != null);

      _cancelableOperation = CancelableOperation<T>.fromFuture(
        fetcher(key, param!),
      );

      final data = await _cancelableOperation!.valueOrCancellation();

      if (_cancelableOperation!.isCanceled) {
        state = stateBeforeFetching;
        return;
      }

      final pages = [data!, ...state.pages];
      final hasNextPage = nextPageParamBuilder?.call(pages) != null;
      final hasPreviousPage = previousPageParamBuilder(pages) != null;

      state = state.copyWith(
        status: QueryStatus.success,
        data: pages,
        dataUpdatedAt: clock.now(),
        isFetchingPreviousPage: false,
        hasNextPage: hasNextPage,
        hasPreviousPage: hasPreviousPage,
      );
    } on Exception catch (error) {
      state = state.copyWith(
        status: QueryStatus.failure,
        error: error,
        errorUpdatedAt: clock.now(),
        isFetchingPreviousPage: false,
      );
    }
  }

  void setInitialData(
    Pages<T> data, [
    DateTime? updatedAt,
  ]) {
    if (state.hasData) {
      return;
    }

    state = state.copyWith(
      status: QueryStatus.success,
      data: data,
      dataUpdatedAt: updatedAt ?? clock.now(),
    );
  }

  bool isStale(Duration duration) {
    if (!state.hasData || state.dataUpdatedAt == null) return true;

    final now = clock.now();
    final staleAt = state.dataUpdatedAt!.add(duration);

    return now.isAfter(staleAt) || now.isAtSameMomentAs(staleAt);
  }

  Future close() async {
    await _cancelableOperation?.cancel();
  }
}
