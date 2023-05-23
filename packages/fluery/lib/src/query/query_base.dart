part of 'index.dart';

abstract class Streamable<State extends Object?> {
  Stream<State> get stream;
}

abstract class StateStreamable<State> implements Streamable<State> {
  State get state;
}

abstract class Closable {
  FutureOr close();

  bool get isClosed;
}

abstract class StateStreamableSource<State>
    implements StateStreamable<State>, Closable {}

mixin StateListenable<Listener extends StateListener<State>, State>
    on StateStreamable<State> {
  final _subscription = <Listener, StreamSubscription>{};

  List<Listener> get listeners => _subscription.keys.toList();

  void addListener(Listener listener) {
    listener.onListen(state);
    _subscription[listener] = stream.listen(listener.onListen);
  }

  void removeListener(Listener listener) {
    _subscription[listener]?.cancel();
    _subscription.remove(listener);
  }
}

abstract class StateListener<State extends Object?> {
  void onListen(State state);
}

abstract class QueryBase<Observer extends StateListener<State>, State>
    extends StateStreamableSource<State> with StateListenable<Observer, State> {
  QueryBase({
    required this.id,
    required this.cache,
    required State initialState,
  }) : _state = initialState {
    scheduleGarbageCollection(cacheDuration);

    _stateController.onListen = () {
      cancelGarbageCollection();
    };
    _stateController.onCancel = () {
      if (isClosed) return;

      if (!_stateController.hasListener) {
        scheduleGarbageCollection(cacheDuration);
      }
    };
  }

  final QueryIdentifier id;
  final QueryCache cache;

  final _stateController = StreamController<State>.broadcast(sync: true);

  Duration cacheDuration = const Duration(minutes: 5);
  State _state;
  Timer? _garbageCollectionTimer;

  @override
  Stream<State> get stream => _stateController.stream;

  @override
  State get state => _state;

  @override
  bool get isClosed => _stateController.isClosed;

  List<Observer> get observers => listeners;

  set state(value) {
    _state = value;
    _stateController.add(value);
  }

  @mustCallSuper
  @override
  Future close() async {
    await _stateController.close();
    _garbageCollectionTimer?.cancel();
  }

  void scheduleGarbageCollection(Duration duration) {
    _garbageCollectionTimer = Timer(
      duration,
      () {
        cache.remove(id);
        close();
      },
    );
  }

  void cancelGarbageCollection() {
    _garbageCollectionTimer?.cancel();
  }
}
