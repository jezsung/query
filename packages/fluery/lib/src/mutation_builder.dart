import 'package:fluery/src/mutation_controller.dart';
import 'package:flutter/material.dart';

typedef MutationWidgetBuilder<Data> = Widget Function(
  BuildContext context,
  MutationState<Data> state,
  Widget? child,
);

class MutationBuilder<Data, Args> extends StatefulWidget {
  const MutationBuilder({
    super.key,
    required this.controller,
    this.mutator,
    this.onMutate,
    this.onSuccess,
    this.onFailure,
    this.onSettled,
    required this.builder,
    this.child,
  });

  final MutationController<Data, Args> controller;
  final Mutator<Data, Args>? mutator;
  final MutationCallback<Args>? onMutate;
  final MutationCallback<Args>? onSuccess;
  final MutationCallback<Args>? onFailure;
  final MutationCallback<Args>? onSettled;
  final MutationWidgetBuilder<Data> builder;
  final Widget? child;

  @override
  State<MutationBuilder<Data, Args>> createState() =>
      _MutationBuilderState<Data, Args>();
}

class _MutationBuilderState<Data, Args>
    extends State<MutationBuilder<Data, Args>> {
  late final MutationController<Data, Args> _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _controller.mergeOptions(
      mutator: widget.mutator,
      onMutate: widget.onMutate,
      onSuccess: widget.onSuccess,
      onFailure: widget.onFailure,
      onSettled: widget.onSettled,
    );
  }

  @override
  void didUpdateWidget(covariant MutationBuilder<Data, Args> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mutator != widget.mutator) {
      _controller.mergeOptions(mutator: widget.mutator);
    }
    if (oldWidget.onMutate != widget.onMutate) {
      _controller.mergeOptions(onMutate: widget.onMutate);
    }
    if (oldWidget.onSuccess != widget.onSuccess) {
      _controller.mergeOptions(onSuccess: widget.onSuccess);
    }
    if (oldWidget.onFailure != widget.onFailure) {
      _controller.mergeOptions(onFailure: widget.onFailure);
    }
    if (oldWidget.onSettled != widget.onSettled) {
      _controller.mergeOptions(onSettled: widget.onSettled);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MutationState<Data>>(
      valueListenable: _controller,
      builder: (context, value, child) {
        return widget.builder(context, value, child);
      },
      child: widget.child,
    );
  }
}
