part of 'mutation.dart';

class MutationConsumer<T, A> extends StatefulWidget {
  const MutationConsumer({
    super.key,
    required this.controller,
    required this.mutator,
    this.retryWhen,
    this.retryMaxAttempts = 3,
    this.retryMaxDelay = const Duration(seconds: 30),
    this.retryDelayFactor = const Duration(milliseconds: 200),
    this.retryRandomizationFactor = 0.25,
    this.listenWhen,
    required this.listener,
    this.buildWhen,
    required this.builder,
    this.child,
  });

  final MutationController<T, A> controller;
  final Mutator<T, A> mutator;
  final RetryCondition? retryWhen;
  final int retryMaxAttempts;
  final Duration retryMaxDelay;
  final Duration retryDelayFactor;
  final double retryRandomizationFactor;
  final MutationListenerCondition? listenWhen;
  final MutationWidgetListener<T> listener;
  final MutationBuilderCondition? buildWhen;
  final MutationWidgetBuilder<T> builder;
  final Widget? child;

  @override
  State<MutationConsumer<T, A>> createState() => _MutationConsumerState<T, A>();
}

class _MutationConsumerState<T, A> extends State<MutationConsumer<T, A>>
    with _MutationWidgetState<T, A> {
  @override
  Mutator<T, A> get mutator => widget.mutator;

  @override
  RetryCondition? get retryWhen => widget.retryWhen;

  @override
  int get retryMaxAttempts => widget.retryMaxAttempts;

  @override
  Duration get retryMaxDelay => widget.retryMaxDelay;

  @override
  Duration get retryDelayFactor => widget.retryDelayFactor;

  @override
  double get retryRandomizationFactor => widget.retryRandomizationFactor;

  @override
  void initState() {
    super.initState();
    widget.controller._attach(this);
  }

  @override
  void dispose() {
    widget.controller._detach(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MutationConsumer<T, A> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.controller != oldWidget.controller) {
      oldWidget.controller._detach(this);
      widget.controller._attach(this);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConditionalValueListenableListener<MutationState<T>>(
      valueListenable: widget.controller,
      listenWhen: widget.listenWhen,
      listener: widget.listener,
      child: ConditionalValueListenableBuilder<MutationState<T>>(
        valueListenable: widget.controller,
        buildWhen: widget.buildWhen,
        builder: widget.builder,
        child: widget.child,
      ),
    );
  }
}
