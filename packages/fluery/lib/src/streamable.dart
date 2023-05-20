import 'dart:async';

import 'package:flutter/foundation.dart';

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
