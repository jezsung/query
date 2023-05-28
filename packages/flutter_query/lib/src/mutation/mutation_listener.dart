part of 'mutation.dart';

typedef MutationListenerCondition<T> = bool Function(
  MutationState<T> previousState,
  MutationState<T> currentState,
);

typedef MutationWidgetListener<T> = void Function(
  BuildContext context,
  MutationState<T> state,
);

class MutationListener<T, P> extends StatefulWidget {
  const MutationListener({
    Key? key,
    required this.controller,
    required this.mutator,
    this.listenWhen,
    required this.listener,
    required this.child,
  }) : super(key: key);

  final MutationController<T, P> controller;
  final Mutator<T, P> mutator;
  final MutationListenerCondition? listenWhen;
  final MutationWidgetListener<T> listener;
  final Widget child;

  @visibleForTesting
  MutationListener<T, P> copyWith({
    Key? key,
    MutationController<T, P>? controller,
    Mutator<T, P>? mutator,
    MutationListenerCondition? listenWhen,
    MutationWidgetListener<T>? listener,
    Widget? child,
  }) {
    return MutationListener<T, P>(
      key: key ?? this.key,
      controller: controller ?? this.controller,
      mutator: mutator ?? this.mutator,
      listenWhen: listenWhen ?? this.listenWhen,
      listener: listener ?? this.listener,
      child: child ?? this.child,
    );
  }

  @override
  State<MutationListener<T, P>> createState() => _MutationListenerState<T, P>();
}

class _MutationListenerState<T, P> extends State<MutationListener<T, P>>
    with _MutationWidgetState<T, P> {
  late Mutation<T, P> _mutation;

  @override
  Mutator<T, P> get mutator => widget.mutator;

  @override
  void initState() {
    super.initState();
    _mutation = Mutation<T, P>();
    _mutation.addObserver(widget.controller);
    widget.controller._attach(this);
  }

  @override
  void dispose() {
    widget.controller._detach(this);
    _mutation.removeObserver(widget.controller);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MutationListener<T, P> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.controller != oldWidget.controller) {
      oldWidget.controller._detach(this);
      _mutation.removeObserver(oldWidget.controller);
      _mutation.addObserver(widget.controller);
      widget.controller._attach(this);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConditionalValueListenableListener<MutationState<T>>(
      valueListenable: widget.controller,
      listenWhen: widget.listenWhen,
      listener: widget.listener,
      child: widget.child,
    );
  }
}

abstract class _MutationWidgetState<T, P> {
  Mutator<T, P> get mutator;
}
