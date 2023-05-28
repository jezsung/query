part of 'mutation.dart';

typedef MutationBuilderCondition<T> = bool Function(
  MutationState<T> previousState,
  MutationState<T> currentState,
);

typedef MutationWidgetBuilder<T> = Widget Function(
  BuildContext context,
  MutationState<T> state,
  Widget? child,
);

class MutationBuilder<T, P> extends StatefulWidget {
  const MutationBuilder({
    Key? key,
    required this.controller,
    required this.mutator,
    this.buildWhen,
    required this.builder,
    this.child,
  }) : super(key: key);

  final MutationController<T, P> controller;
  final Mutator<T, P> mutator;
  final MutationBuilderCondition? buildWhen;
  final MutationWidgetBuilder<T> builder;
  final Widget? child;

  @visibleForTesting
  MutationBuilder<T, P> copyWith({
    Key? key,
    MutationController<T, P>? controller,
    Mutator<T, P>? mutator,
    MutationBuilderCondition? buildWhen,
    MutationWidgetBuilder<T>? builder,
    Widget? child,
  }) {
    return MutationBuilder<T, P>(
      key: key ?? this.key,
      controller: controller ?? this.controller,
      mutator: mutator ?? this.mutator,
      buildWhen: buildWhen ?? this.buildWhen,
      builder: builder ?? this.builder,
      child: child ?? this.child,
    );
  }

  @override
  State<MutationBuilder<T, P>> createState() => _MutationBuilderState<T, P>();
}

class _MutationBuilderState<T, P> extends State<MutationBuilder<T, P>> {
  late MutationState<T> _state;

  @override
  void initState() {
    super.initState();
    _state = widget.controller.state;
  }

  @override
  Widget build(BuildContext context) {
    return MutationListener<T, P>(
      controller: widget.controller,
      mutator: widget.mutator,
      listenWhen: widget.buildWhen,
      listener: (context, state) {
        setState(() {
          _state = state;
        });
      },
      child: widget.builder(context, _state, widget.child),
    );
  }
}
