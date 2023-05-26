import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

typedef ValueListenableBuilderCondition<T> = bool Function(
  T previousValue,
  T currentValue,
);

class ConditionalValueListenableBuilder<T> extends StatefulWidget {
  const ConditionalValueListenableBuilder({
    Key? key,
    required this.valueListenable,
    this.buildWhen,
    required this.builder,
    this.child,
  }) : super(key: key);

  final ValueListenable<T> valueListenable;
  final ValueListenableBuilderCondition<T>? buildWhen;
  final ValueWidgetBuilder<T> builder;
  final Widget? child;

  @override
  State<ConditionalValueListenableBuilder> createState() =>
      _ConditionalValueListenableBuilderState<T>();
}

class _ConditionalValueListenableBuilderState<T>
    extends State<ConditionalValueListenableBuilder<T>> {
  late T _previousValue;
  late T value;

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
  void didUpdateWidget(ConditionalValueListenableBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.valueListenable != widget.valueListenable) {
      oldWidget.valueListenable.removeListener(_valueChanged);
      value = widget.valueListenable.value;
      widget.valueListenable.addListener(_valueChanged);
    }

    if (oldWidget.buildWhen != widget.buildWhen) {
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

    if (_shouldRebuild) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, value, widget.child);
  }
}
