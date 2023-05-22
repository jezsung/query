part of 'paged_query.dart';

class PagedQueryState<T, P> extends QueryState<Pages<T>> {
  const PagedQueryState({
    super.status = QueryStatus.idle,
    Pages<T> pages = const [],
    this.isFetchingNextPage = false,
    this.isFetchingPreviousPage = false,
    this.nextPageParam,
    this.previousPageParam,
    super.error,
    super.dataUpdatedAt,
    super.errorUpdatedAt,
  }) : super(data: pages);

  final bool isFetchingNextPage;
  final bool isFetchingPreviousPage;
  final P? nextPageParam;
  final P? previousPageParam;

  Pages<T> get pages => data as Pages<T>;

  @override
  bool get hasData => pages.isNotEmpty;

  bool get hasNextPage => nextPageParam != null;

  bool get hasPreviousPage => previousPageParam != null;

  @override
  PagedQueryState<T, P> copyWith({
    QueryStatus? status,
    Pages<T>? data,
    bool? isFetchingNextPage,
    bool? isFetchingPreviousPage,
    P? nextPageParam,
    P? previousPageParam,
    Exception? error,
    DateTime? dataUpdatedAt,
    DateTime? errorUpdatedAt,
  }) {
    return PagedQueryState<T, P>(
      status: status ?? this.status,
      pages: data ?? this.pages,
      isFetchingNextPage: isFetchingNextPage ?? this.isFetchingNextPage,
      isFetchingPreviousPage:
          isFetchingPreviousPage ?? this.isFetchingPreviousPage,
      nextPageParam: nextPageParam ?? this.nextPageParam,
      previousPageParam: previousPageParam ?? this.previousPageParam,
      error: error ?? this.error,
      dataUpdatedAt: dataUpdatedAt ?? this.dataUpdatedAt,
      errorUpdatedAt: errorUpdatedAt ?? this.errorUpdatedAt,
    );
  }

  PagedQueryState<T, P> copyWithNull({
    bool nextPageParam = false,
    bool previousPageParam = false,
    bool error = false,
    bool dataUpdatedAt = false,
    bool errorUpdatedAt = false,
  }) {
    return PagedQueryState<T, P>(
      status: status,
      pages: pages,
      isFetchingNextPage: isFetchingNextPage,
      isFetchingPreviousPage: isFetchingPreviousPage,
      nextPageParam: nextPageParam ? null : this.nextPageParam,
      previousPageParam: previousPageParam ? null : this.previousPageParam,
      error: error ? null : this.error,
      dataUpdatedAt: previousPageParam ? null : this.dataUpdatedAt,
      errorUpdatedAt: errorUpdatedAt ? null : this.errorUpdatedAt,
    );
  }

  @override
  List<Object?> get props =>
      super.props +
      [
        isFetchingNextPage,
        isFetchingPreviousPage,
        nextPageParam,
        previousPageParam,
      ];
}
