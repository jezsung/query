import 'dart:async';

enum QueryStatus { pending, error, success }
enum MutationStatus { idle, pending, error, success }

class TrackedFuture<T> implements Future<T> {
  final Future<T> _future;
  bool _isCompleted = false;
  bool _hasError = false;
  T? _result;
  Object? _error;

  TrackedFuture(Future<T> future) : _future = future {
    _future.then((value) {
      _isCompleted = true;
      _result = value;
    }).catchError((e) {
      _isCompleted = true;
      _hasError = true;
      _error = e;
    });
  }

  bool get isCompleted => _isCompleted;
  bool get hasError => _hasError;
  T? get result => _result;
  Object? get error => _error;

  @override
  Future<S> then<S>(FutureOr<S> Function(T value) onValue, {Function? onError}) {
    return _future.then(onValue, onError: onError);
  }

  @override
  Future<T> catchError(Function onError, {bool Function(Object error)? test}) {
    return _future.catchError(onError, test: test);
  }

  @override
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) {
    return _future.timeout(timeLimit, onTimeout: onTimeout);
  }

  @override
  Future<T> whenComplete(FutureOr<void> Function() action) {
    return _future.whenComplete(action);
  }

  @override
  Stream<T> asStream() {
    return _future.asStream();
  }
}