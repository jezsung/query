part of 'paged_query.dart';

class PagedQueryController<T, P> {
  _PagedQueryWidgetState? _state;

  Future fetch() async {
    await _state?.fetch();
  }

  Future fetchNextPage() async {
    await _state?.fetchNextPage();
  }

  Future fetchPreviousPage() async {
    await _state?.fetchPreviousPage();
  }

  void _attach(_PagedQueryWidgetState state) {
    _state = state;
  }

  void _detach(_PagedQueryWidgetState state) {
    if (_state == state) {
      _state = null;
    }
  }
}
