import '../query.dart';

typedef PlaceholderDataBuilder<TData, TError> = TData? Function(
  TData? previousValue,
  Query<TData, TError>? previousQuery,
);

/// Base class for placeholder data options.
sealed class PlaceholderData<TData, TError> {
  factory PlaceholderData(TData value) {
    return _PlaceholderDataValue._(value);
  }

  factory PlaceholderData.resolveWith(
    PlaceholderDataBuilder<TData, TError> callback,
  ) {
    return _PlaceholderDataCallback._(callback);
  }
}

extension Resolve<TData, TError> on PlaceholderData<TData, TError> {
  TData? resolve(TData? previousValue, Query<TData, TError>? previousQuery) {
    return switch (this) {
      _PlaceholderDataValue(:final _value) => _value,
      _PlaceholderDataCallback(:final _callback) =>
        _callback(previousValue, previousQuery),
    };
  }
}

final class _PlaceholderDataValue<TData, TError>
    implements PlaceholderData<TData, TError> {
  const _PlaceholderDataValue._(this._value);

  final TData _value;
}

final class _PlaceholderDataCallback<TData, TError>
    implements PlaceholderData<TData, TError> {
  const _PlaceholderDataCallback._(this._callback);

  final PlaceholderDataBuilder<TData, TError> _callback;
}
