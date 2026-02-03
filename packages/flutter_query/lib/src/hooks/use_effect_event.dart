import 'package:flutter/widgets.dart';

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:meta/meta.dart';

@internal
class EffectEvent<T extends Function> {
  EffectEvent._(this._ref);

  final ObjectRef<T> _ref;

  T get call => _ref.value;
}

@internal
EffectEvent<T> useEffectEvent<T extends Function>(T callback) {
  return use(_EffectEventHook<T>(callback));
}

class _EffectEventHook<T extends Function> extends Hook<EffectEvent<T>> {
  const _EffectEventHook(this.callback);

  final T callback;

  @override
  _EffectEventHookState<T> createState() => _EffectEventHookState<T>();
}

class _EffectEventHookState<T extends Function>
    extends HookState<EffectEvent<T>, _EffectEventHook<T>> {
  late final ObjectRef<T> _ref;

  @override
  void initHook() {
    _ref = ObjectRef<T>(hook.callback);
  }

  @override
  void didUpdateHook(_EffectEventHook<T> oldHook) {
    _ref.value = hook.callback;
  }

  @override
  EffectEvent<T> build(BuildContext context) {
    return EffectEvent<T>._(_ref);
  }

  @override
  String get debugLabel => 'useEffectEvent<$T>';

  @override
  bool get debugSkipValue => true;
}
