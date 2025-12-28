import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

@internal
class QueryKey {
  const QueryKey(this._parts);

  final List<Object?> _parts;

  List<Object?> get parts => List.unmodifiable(_parts);

  int get length => _parts.length;

  bool startsWith(QueryKey prefix) {
    if (prefix._parts.length > _parts.length) {
      return false;
    }

    for (var i = 0; i < prefix._parts.length; i++) {
      if (!_equality.equals(_parts[i], prefix._parts[i])) {
        return false;
      }
    }

    return true;
  }

  Object? operator [](int index) => _parts[index];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QueryKey && _equality.equals(_parts, other._parts)) ||
      (other is List && _equality.equals(_parts, other));

  @override
  int get hashCode => _equality.hash(_parts);

  @override
  String toString() => '$_parts';
}

const _equality = DeepCollectionEquality();
