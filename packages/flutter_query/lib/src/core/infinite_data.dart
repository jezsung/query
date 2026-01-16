import 'utils.dart';

/// Data structure for infinite queries containing pages and their params.
class InfiniteData<TData, TPageParam> {
  const InfiniteData(
    this.pages,
    this.pageParams,
  );

  const InfiniteData.empty()
      : pages = const [],
        pageParams = const [];

  /// The list of pages fetched so far.
  /// Each page corresponds to a pageParam at the same index.
  final List<TData> pages;

  /// The list of page parameters used to fetch each page.
  /// pageParams[i] was used to fetch pages[i].
  final List<TPageParam> pageParams;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InfiniteData<TData, TPageParam> &&
          deepEq.equals(pages, other.pages) &&
          deepEq.equals(pageParams, other.pageParams);

  @override
  int get hashCode => Object.hash(
        deepEq.hash(pages),
        deepEq.hash(pageParams),
      );

  @override
  String toString() => 'InfiniteData(pages: $pages, pageParams: $pageParams)';
}

/// Direction of page fetch for infinite queries.
enum FetchDirection {
  /// Fetching the next page (appending to the end).
  forward,

  /// Fetching the previous page (prepending to the start).
  backward,
}
