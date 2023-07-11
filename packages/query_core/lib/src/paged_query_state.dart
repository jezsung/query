part of 'query.dart';

class PagedQueryState<T> extends QueryState<Pages<T>> {
  const PagedQueryState({
    QueryStatus status = QueryStatus.idle,
    Pages<T> pages = const [],
    Exception? error,
    DateTime? dataUpdatedAt,
    DateTime? errorUpdatedAt,
    bool isInvalidated = false,
    this.isFetchingNextPage = false,
    this.isFetchingPreviousPage = false,
    this.hasNextPage = false,
    this.hasPreviousPage = false,
  }) : super(
          status: status,
          data: pages,
          error: error,
          dataUpdatedAt: dataUpdatedAt,
          errorUpdatedAt: errorUpdatedAt,
          isInvalidated: isInvalidated,
        );

  final bool isFetchingNextPage;
  final bool isFetchingPreviousPage;
  final bool hasNextPage;
  final bool hasPreviousPage;

  Pages<T> get pages => data as Pages<T>;

  @override
  bool get hasData => pages.isNotEmpty;

  @override
  PagedQueryState<T> copyWith({
    QueryStatus? status,
    Pages<T>? data,
    Exception? error,
    DateTime? dataUpdatedAt,
    DateTime? errorUpdatedAt,
    bool? isFetchingNextPage,
    bool? isFetchingPreviousPage,
    bool? hasNextPage,
    bool? hasPreviousPage,
    bool? isInvalidated,
  }) {
    return PagedQueryState<T>(
      status: status ?? this.status,
      pages: data ?? this.pages,
      error: error ?? this.error,
      dataUpdatedAt: dataUpdatedAt ?? this.dataUpdatedAt,
      errorUpdatedAt: errorUpdatedAt ?? this.errorUpdatedAt,
      isFetchingNextPage: isFetchingNextPage ?? this.isFetchingNextPage,
      isFetchingPreviousPage:
          isFetchingPreviousPage ?? this.isFetchingPreviousPage,
      hasNextPage: hasNextPage ?? this.hasNextPage,
      hasPreviousPage: hasPreviousPage ?? this.hasPreviousPage,
      isInvalidated: isInvalidated ?? this.isInvalidated,
    );
  }

  @override
  List<Object?> get props =>
      super.props +
      [
        isFetchingNextPage,
        isFetchingPreviousPage,
        hasNextPage,
        hasPreviousPage,
      ];
}
