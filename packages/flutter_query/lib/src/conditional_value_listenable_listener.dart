import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

typedef ValueListenableListenerCondition<T> = bool Function(
  T previousValue,
  T currentValue,
);

typedef ValueWidgetListener<T> = void Function(
  BuildContext context,
  T value,
);

class ConditionalValueListenableListener<T> extends StatefulWidget {
  const ConditionalValueListenableListener({
    Key? key,
    required this.valueListenable,
    this.listenWhen,
    required this.listener,
    required this.child,
  }) : super(key: key);

  final ValueListenable<T> valueListenable;
  final ValueListenableListenerCondition<T>? listenWhen;
  final ValueWidgetListener<T> listener;
  final Widget child;

  @override
  State<ConditionalValueListenableListener> createState() =>
      _ConditionalValueListenableListenerState<T>();
}

class _ConditionalValueListenableListenerState<T>
    extends State<ConditionalValueListenableListener<T>> {
  late T _previousValue;
  late T value;

  bool get _shouldRelisten => widget.listenWhen != null
      ? widget.listenWhen!(_previousValue, value)
      : true;

  @override
  void initState() {
    super.initState();
    _previousValue = widget.valueListenable.value;
    value = widget.valueListenable.value;
    widget.valueListenable.addListener(_valueChanged);
  }

  @override
  void didUpdateWidget(ConditionalValueListenableListener<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.valueListenable != widget.valueListenable) {
      oldWidget.valueListenable.removeListener(_valueChanged);
      value = widget.valueListenable.value;
      widget.valueListenable.addListener(_valueChanged);
    }

    if (oldWidget.listenWhen != widget.listenWhen) {
      if (_shouldRelisten) {
        widget.listener(context, value);
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
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
