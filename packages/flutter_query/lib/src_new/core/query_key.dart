import 'package:equatable/equatable.dart';

/// Internal class for efficient query key hashing and comparison.
///
/// QueryKey is used internally by QueryCache to efficiently hash and compare
/// query keys. Users never interact with this directly - they use `List<Object?>`.
class QueryKey with EquatableMixin {
  const QueryKey(this._segments);

  final List<Object?> _segments;

  @override
  List<Object?> get props => _segments;

  @override
  String toString() => '$_segments';
}
