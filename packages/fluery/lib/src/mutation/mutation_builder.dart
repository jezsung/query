part of 'mutation.dart';

class MutationBuilder<T, P> extends StatefulWidget {
  const MutationBuilder({
    super.key,
    required this.controller,
    required this.mutator,
    this.retryWhen,
    this.retryMaxAttempts = 3,
    this.retryMaxDelay = const Duration(seconds: 30),
    this.retryDelayFactor = const Duration(milliseconds: 200),
    this.retryRandomizationFactor = 0.25,
    this.buildWhen,
    required this.builder,
    this.child,
  });

  final MutationController<T, P> controller;
  final Mutator<T, P> mutator;
  final RetryCondition? retryWhen;
  final int retryMaxAttempts;
  final Duration retryMaxDelay;
  final Duration retryDelayFactor;
  final double retryRandomizationFactor;
  final MutationBuilderCondition? buildWhen;
  final MutationWidgetBuilder<T> builder;
  final Widget? child;

  @visibleForTesting
  MutationBuilder<T, P> copyWith({
    Key? key,
    MutationController<T, P>? controller,
    Mutator<T, P>? mutator,
    RetryCondition? retryWhen,
    int? retryMaxAttempts,
    Duration? retryMaxDelay,
    Duration? retryDelayFactor,
    double? retryRandomizationFactor,
    MutationBuilderCondition? buildWhen,
    MutationWidgetBuilder<T>? builder,
    Widget? child,
  }) {
    return MutationBuilder<T, P>(
      key: key ?? this.key,
      controller: controller ?? this.controller,
      mutator: mutator ?? this.mutator,
      retryWhen: retryWhen ?? this.retryWhen,
      retryMaxAttempts: retryMaxAttempts ?? this.retryMaxAttempts,
      retryMaxDelay: retryMaxDelay ?? this.retryMaxDelay,
      retryDelayFactor: retryDelayFactor ?? this.retryDelayFactor,
      retryRandomizationFactor:
          retryRandomizationFactor ?? this.retryRandomizationFactor,
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
    _state = widget.controller.value;
  }

  @override
  Widget build(BuildContext context) {
    return MutationListener<T, P>(
      controller: widget.controller,
      mutator: widget.mutator,
      retryWhen: widget.retryWhen,
      retryMaxAttempts: widget.retryMaxAttempts,
      retryMaxDelay: widget.retryMaxDelay,
      retryDelayFactor: widget.retryDelayFactor,
      retryRandomizationFactor: widget.retryRandomizationFactor,
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
