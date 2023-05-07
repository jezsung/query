part of 'mutation.dart';

class MutationController<T, A> extends ValueNotifier<MutationState<T>> {
  MutationController() : super(MutationState<T>());

  final TimerInterceptor _timerInterceptor = TimerInterceptor();

  _MutationWidgetState<T, A>? _state;
  CancelableOperation<T>? _cancelableOperation;

  Mutator<T, A> get mutator {
    assert(_state != null);

    return _state!.mutator;
  }

  RetryCondition? get retryWhen {
    assert(_state != null);

    return _state!.retryWhen;
  }

  int get retryMaxAttempts {
    assert(_state != null);

    return _state!.retryMaxAttempts;
  }

  Duration get retryMaxDelay {
    assert(_state != null);

    return _state!.retryMaxDelay;
  }

  Duration get retryDelayFactor {
    assert(_state != null);

    return _state!.retryDelayFactor;
  }

  double get retryRandomizationFactor {
    assert(_state != null);

    return _state!.retryRandomizationFactor;
  }

  Future<void> mutate([A? args]) async {
    assert(_state != null);

    if (value.status.isMutating) return;

    value = value.copyWith(status: MutationStatus.mutating);

    try {
      _cancelableOperation = CancelableOperation<T>.fromFuture(
        _timerInterceptor.run(() => mutator(args)),
      );

      final data = await _cancelableOperation!.valueOrCancellation();

      if (!_cancelableOperation!.isCanceled) {
        value = value.copyWith(
          status: MutationStatus.success,
          data: data,
          dataUpdatedAt: clock.now(),
        );
      }
    } on Exception catch (error) {
      if (retryMaxAttempts >= 1 && (await retryWhen?.call(error) ?? true)) {
        value = value.copyWith(
          status: MutationStatus.retrying,
          error: error,
          errorUpdatedAt: clock.now(),
        );

        try {
          final data = await retry(
            () {
              _cancelableOperation = CancelableOperation<T>.fromFuture(
                _timerInterceptor.run(() => mutator(args)),
              );
              return _cancelableOperation!.valueOrCancellation();
            },
            retryIf: retryWhen,
            maxAttempts: retryMaxAttempts,
            delayFactor: retryDelayFactor,
            randomizationFactor: retryRandomizationFactor,
            onRetry: (error) {
              value = value.copyWith(
                status: MutationStatus.retrying,
                error: error,
                errorUpdatedAt: clock.now(),
              );
            },
          );

          if (!_cancelableOperation!.isCanceled) {
            value = value.copyWith(
              status: MutationStatus.success,
              data: data,
              dataUpdatedAt: clock.now(),
            );
          }
        } on Exception catch (error) {
          value = value.copyWith(
            status: MutationStatus.failure,
            error: error,
            errorUpdatedAt: clock.now(),
          );
        }
      } else {
        value = value.copyWith(
          status: MutationStatus.failure,
          error: error,
          errorUpdatedAt: clock.now(),
        );
      }
    }
  }

  Future<void> cancel({
    T? data,
    Exception? error,
  }) async {
    if (!value.status.isMutating) return;

    await _cancelableOperation?.cancel();

    value = value.copyWith(
      status: MutationStatus.canceled,
      data: data,
      dataUpdatedAt: data != null ? clock.now() : null,
      error: error,
      errorUpdatedAt: error != null ? clock.now() : null,
    );
  }

  void reset() {
    if (value.status.isMutating) return;

    value = value.copyWith(
      status: MutationStatus.idle,
      data: null,
      error: null,
    );
  }

  @override
  void dispose() {
    _timerInterceptor.cancel();
    _cancelableOperation?.cancel();
    super.dispose();
  }

  void _attach(_MutationWidgetState<T, A> state) {
    _state = state;
  }

  void _detach(_MutationWidgetState<T, A> state) {
    if (_state == state) {
      _state = null;
      cancel();
    }
  }
}
