import 'package:collection/collection.dart';

/// Internal class for efficient query key hashing and comparison.
///
/// QueryKey is used internally by QueryCache to efficiently hash and compare
/// query keys. Users never interact with this directly - they use `List<Object?>`.
class QueryKey {
  const QueryKey(this._segments);

  final List<Object?> _segments;

  static const _equality = DeepCollectionEquality();

  /// Checks if this query key starts with another query key
  /// Returns true if [prefix] is a prefix of this query key
  /// Example: QueryKey(['users', '1']).startsWith(QueryKey(['users'])) => true
  bool startsWith(QueryKey prefix) {
    if (prefix._segments.length > _segments.length) {
      return false;
    }

    for (var i = 0; i < prefix._segments.length; i++) {
      if (!_equality.equals(_segments[i], prefix._segments[i])) {
        return false;
      }
    }

    return true;
  }

  @override
  String toString() => '$_segments';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueryKey && _equality.equals(_segments, other._segments);

  @override
  int get hashCode => _equality.hash(_segments);
}
