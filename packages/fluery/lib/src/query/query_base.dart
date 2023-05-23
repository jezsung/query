part of 'index.dart';

abstract class Streamable<T> {
  Streamable({
    bool sync = false,
  }) : streamController = StreamController<T>(sync: sync);

  Streamable.broadcast({
    bool sync = false,
  }) : streamController = StreamController<T>.broadcast(sync: sync);

  @protected
  final StreamController<T> streamController;

  Stream<T> get stream => streamController.stream;

  @mustCallSuper
  Future close() async {
    await streamController.close();
  }
}

abstract class StateStreamable<T> extends Streamable<T> {
  StateStreamable({
    required T initialState,
    bool sync = false,
  })  : _state = initialState,
        super(sync: sync);

  StateStreamable.broadcast({
    required T initialState,
    bool sync = false,
  })  : _state = initialState,
        super.broadcast(sync: sync);

  T _state;

  T get state => _state;

  set state(T value) {
    _state = value;
    streamController.add(value);
  }
}

abstract class QueryBase<T> extends StateStreamable<T> {
  QueryBase({
    required this.id,
    required this.cache,
    required super.initialState,
  }) : super.broadcast(sync: true) {
    _scheduleGarbageCollection();

    streamController.onListen = () {
      _cancelGarbageCollection();
    };
    streamController.onCancel = () {
      if (streamController.isClosed) return;

      if (!active) {
        _scheduleGarbageCollection();
      }
    };
  }

  final QueryIdentifier id;
  final QueryCache cache;

  @protected
  Duration cacheDuration = const Duration(minutes: 5);

  Timer? _garbageCollectionTimer;

  bool get active => streamController.hasListener;

  @override
  Future close() async {
    _cancelGarbageCollection();
    await super.close();
  }

  void _scheduleGarbageCollection() {
    _garbageCollectionTimer = Timer(
      cacheDuration,
      () {
        cache.remove(id);
        close();
      },
    );
  }

  void _cancelGarbageCollection() {
    _garbageCollectionTimer?.cancel();
  }
}
