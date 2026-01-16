import 'package:meta/meta.dart';

import 'utils.dart';

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
      if (!deepEq.equals(_parts[i], prefix._parts[i])) {
        return false;
      }
    }

    return true;
  }

  Object? operator [](int index) => _parts[index];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QueryKey && deepEq.equals(_parts, other._parts)) ||
      (other is List && deepEq.equals(_parts, other));

  @override
  int get hashCode => deepEq.hash(_parts);

  @override
  String toString() => '$_parts';
}
