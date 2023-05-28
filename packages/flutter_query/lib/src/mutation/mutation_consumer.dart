part of 'mutation.dart';

class MutationConsumer<T, P> extends StatefulWidget {
  const MutationConsumer({
    Key? key,
    required this.controller,
    required this.mutator,
    this.listenWhen,
    required this.listener,
    this.buildWhen,
    required this.builder,
    this.child,
  }) : super(key: key);

  final MutationController<T, P> controller;
  final Mutator<T, P> mutator;
  final MutationListenerCondition? listenWhen;
  final MutationWidgetListener<T> listener;
  final MutationBuilderCondition? buildWhen;
  final MutationWidgetBuilder<T> builder;
  final Widget? child;

  @override
  State<MutationConsumer<T, P>> createState() => _MutationConsumerState<T, P>();
}

class _MutationConsumerState<T, P> extends State<MutationConsumer<T, P>>
    with _MutationWidgetState<T, P> {
  late MutationState<T> _previousState;
  late MutationState<T> _currentState;

  @override
  void initState() {
    super.initState();
    _previousState = widget.controller.state;
    _currentState = widget.controller.state;
  }

  @override
  Widget build(BuildContext context) {
    return MutationListener<T, P>(
      controller: widget.controller,
      mutator: mutator,
      listener: (context, state) {
        if (widget.listenWhen?.call(_previousState, _currentState) ?? true) {
          widget.listener(context, state);
        }

        if (widget.buildWhen?.call(_previousState, _currentState) ?? true) {
          _previousState = _currentState;
          setState(() {
            _currentState = state;
          });
        }
      },
      child: widget.builder(context, _currentState, widget.child),
    );
  }

  @override
  Mutator<T, P> get mutator => widget.mutator;
}
