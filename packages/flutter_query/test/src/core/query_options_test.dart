import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_query/src/core/core.dart';

void main() {
  group('Seed', () {
    group('value', () {
      test(
          'SHOULD be equal '
          'WHEN values are deeply equal', () {
        expect(
          Seed<List<String>>.value(const ['a', 'b']),
          Seed<List<String>>.value(const ['a', 'b']),
        );
        expect(
          Seed<List<String>>.value(const ['a', 'b']).hashCode,
          Seed<List<String>>.value(const ['a', 'b']).hashCode,
        );
      });

      test(
          'SHOULD NOT be equal '
          'WHEN values differ', () {
        expect(
          Seed<String>.value('a'),
          isNot(Seed<String>.value('b')),
        );
      });
    });

    group('lazy', () {
      test(
          'SHOULD be equal '
          'WHEN callbacks are identical', () {
        String? resolve() => 'data';

        expect(Seed<String>.lazy(resolve), Seed<String>.lazy(resolve));
        expect(
          Seed<String>.lazy(resolve).hashCode,
          Seed<String>.lazy(resolve).hashCode,
        );
      });

      test(
          'SHOULD NOT be equal '
          'WHEN callbacks are different instances', () {
        expect(
          Seed<String>.lazy(() => 'data'),
          isNot(Seed<String>.lazy(() => 'data')),
        );
      });
    });

    test(
        'SHOULD NOT be equal '
        'WHEN forms differ', () {
      expect(
        Seed<String>.value('data'),
        isNot(Seed<String>.lazy(() => 'data')),
      );
    });
  });

  group('SeedUpdatedAt', () {
    group('value', () {
      test(
          'SHOULD be equal '
          'WHEN values are equal', () {
        final timestamp = DateTime(2026, 7, 10);

        expect(
          SeedUpdatedAt.value(timestamp),
          SeedUpdatedAt.value(DateTime(2026, 7, 10)),
        );
        expect(
          SeedUpdatedAt.value(timestamp).hashCode,
          SeedUpdatedAt.value(DateTime(2026, 7, 10)).hashCode,
        );
      });

      test(
          'SHOULD NOT be equal '
          'WHEN values differ', () {
        expect(
          SeedUpdatedAt.value(DateTime(2026, 7, 10)),
          isNot(SeedUpdatedAt.value(DateTime(2026, 7, 11))),
        );
      });
    });

    group('lazy', () {
      test(
          'SHOULD be equal '
          'WHEN callbacks are identical', () {
        DateTime? resolve() => DateTime(2026, 7, 10);

        expect(SeedUpdatedAt.lazy(resolve), SeedUpdatedAt.lazy(resolve));
        expect(
          SeedUpdatedAt.lazy(resolve).hashCode,
          SeedUpdatedAt.lazy(resolve).hashCode,
        );
      });

      test(
          'SHOULD NOT be equal '
          'WHEN callbacks are different instances', () {
        expect(
          SeedUpdatedAt.lazy(() => DateTime(2026, 7, 10)),
          isNot(SeedUpdatedAt.lazy(() => DateTime(2026, 7, 10))),
        );
      });
    });

    test(
        'SHOULD NOT be equal '
        'WHEN forms differ', () {
      final timestamp = DateTime(2026, 7, 10);

      expect(
        SeedUpdatedAt.value(timestamp),
        isNot(SeedUpdatedAt.lazy(() => timestamp)),
      );
    });
  });
}
