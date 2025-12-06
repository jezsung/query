part of 'query.dart';

class PagedQueryState<T> extends QueryState<Pages<T>> {
  const PagedQueryState({
    super.status,
    Pages<T> pages = const [],
    super.error,
    super.dataUpdatedAt,
    super.errorUpdatedAt,
    super.isInvalidated,
    this.isFetchingNextPage = false,
    this.isFetchingPreviousPage = false,
    this.hasNextPage = false,
    this.hasPreviousPage = false,
  }) : super(
          data: pages,
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
