import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

typedef ValueListenableListenerCondition<T> = bool Function(
  T previousValue,
  T currentValue,
);

typedef ValueListenableBuilderCondition<T> = bool Function(
  T previousValue,
  T currentValue,
);

typedef ValueWidgetListener<T> = void Function(
  BuildContext context,
  T value,
);

class ConditionalValueListenableConsumer<T> extends StatefulWidget {
  const ConditionalValueListenableConsumer({
    super.key,
    required this.valueListenable,
    this.listenWhen,
    required this.listener,
    this.buildWhen,
    required this.builder,
    this.child,
  });

  final ValueListenable<T> valueListenable;
  final ValueListenableListenerCondition<T>? listenWhen;
  final ValueWidgetListener<T> listener;
  final ValueListenableBuilderCondition<T>? buildWhen;
  final ValueWidgetBuilder<T> builder;
  final Widget? child;

  @override
  State<ConditionalValueListenableConsumer> createState() =>
      _ConditionalValueListenableConsumerState<T>();
}

class _ConditionalValueListenableConsumerState<T>
    extends State<ConditionalValueListenableConsumer<T>> {
  late T _previousValue;
  late T value;

  bool get _shouldRelisten => widget.listenWhen != null
      ? widget.listenWhen!(_previousValue, value)
      : true;

  bool get _shouldRebuild => widget.buildWhen != null
      ? widget.buildWhen!(_previousValue, value)
      : true;

  @override
  void initState() {
    super.initState();
    _previousValue = widget.valueListenable.value;
    value = widget.valueListenable.value;
    widget.valueListenable.addListener(_valueChanged);
  }

  @override
  void didUpdateWidget(ConditionalValueListenableConsumer<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.valueListenable != widget.valueListenable) {
      oldWidget.valueListenable.removeListener(_valueChanged);
      value = widget.valueListenable.value;
      widget.valueListenable.addListener(_valueChanged);
    }

    if (oldWidget.buildWhen != widget.buildWhen) {
      if (_shouldRelisten) {
        widget.listener(context, value);
      }
      if (_shouldRebuild) {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    widget.valueListenable.removeListener(_valueChanged);
    super.dispose();
  }

  void _valueChanged() {
    _previousValue = value;
    value = widget.valueListenable.value;

    if (_shouldRelisten) {
      widget.listener(context, value);
    }
    if (_shouldRebuild) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, value, widget.child);
  }
}

class _CallbackQueue {
  _CallbackQueue({
    // ignore: unused_element
    this.enabled = true,
  });

  final Queue<Function> _queue = Queue<Function>();

  bool enabled;

  void call(Function callback) {
    if (!enabled) {
      callback();
      return;
    }

    _queue.add(callback);

    if (_queue.length == 1) {
      _execute();
    }
  }

  void _execute() async {
    if (_queue.isEmpty) return;

    final Function function = _queue.first;
    await function();
    _queue.removeFirst();

    _execute();
  }
}
