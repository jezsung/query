part of 'mutation.dart';

class MutationListener<T, P> extends StatefulWidget {
  const MutationListener({
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
    required this.child,
  });

  final MutationController<T, P> controller;
  final Mutator<T, P> mutator;
  final RetryCondition? retryWhen;
  final int retryMaxAttempts;
  final Duration retryMaxDelay;
  final Duration retryDelayFactor;
  final double retryRandomizationFactor;
  final MutationListenerCondition? listenWhen;
  final MutationWidgetListener<T> listener;
  final Widget child;

  @visibleForTesting
  MutationListener<T, P> copyWith({
    Key? key,
    MutationController<T, P>? controller,
    Mutator<T, P>? mutator,
    RetryCondition? retryWhen,
    int? retryMaxAttempts,
    Duration? retryMaxDelay,
    Duration? retryDelayFactor,
    double? retryRandomizationFactor,
    MutationListenerCondition? listenWhen,
    MutationWidgetListener<T>? listener,
    Widget? child,
  }) {
    return MutationListener<T, P>(
      key: key ?? this.key,
      controller: controller ?? this.controller,
      mutator: mutator ?? this.mutator,
      retryWhen: retryWhen ?? this.retryWhen,
      retryMaxAttempts: retryMaxAttempts ?? this.retryMaxAttempts,
      retryMaxDelay: retryMaxDelay ?? this.retryMaxDelay,
      retryDelayFactor: retryDelayFactor ?? this.retryDelayFactor,
      retryRandomizationFactor:
          retryRandomizationFactor ?? this.retryRandomizationFactor,
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
  @override
  Mutator<T, P> get mutator => widget.mutator;

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
  void didUpdateWidget(covariant MutationListener<T, P> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.controller != oldWidget.controller) {
      oldWidget.controller._detach(this);
      widget.controller._attach(this);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConditionalValueListenableListener(
      valueListenable: widget.controller,
      listenWhen: widget.listenWhen,
      listener: widget.listener,
      child: widget.child,
    );
  }
}
