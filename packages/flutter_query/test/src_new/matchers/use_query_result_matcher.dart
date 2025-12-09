import 'package:flutter_query/src_new/core/query.dart';
import 'package:flutter_query/src_new/hooks/use_query.dart';
import 'package:flutter_test/flutter_test.dart';

/// A matcher for [UseQueryResult] that matches all fields.
///
/// All parameters are required and will be matched against the result.
///
/// [dataUpdatedAt] and [errorUpdatedAt] can be either a [DateTime] for exact
/// matching or a [Matcher] for flexible matching (e.g., [isNull], [isA<DateTime>()]).
///
/// Example:
/// ```dart
/// expect(result, isUseQueryResult<String, Object>(
///   status: QueryStatus.success,
///   fetchStatus: FetchStatus.idle,
///   data: 'expected data',
///   dataUpdatedAt: isNotNull,  // Use a matcher
///   error: null,
///   errorUpdatedAt: null,
///   errorUpdateCount: 0,
///   isEnabled: true,
/// ));
/// ```
Matcher isUseQueryResult<TData, TError>({
  required QueryStatus status,
  required FetchStatus fetchStatus,
  required TData? data,
  required dynamic dataUpdatedAt, // DateTime or Matcher
  required TError? error,
  required dynamic errorUpdatedAt, // DateTime or Matcher
  required int errorUpdateCount,
  required bool isEnabled,
}) {
  return _UseQueryResultMatcher<TData, TError>(
    status: status,
    fetchStatus: fetchStatus,
    data: data,
    dataUpdatedAt: dataUpdatedAt,
    error: error,
    errorUpdatedAt: errorUpdatedAt,
    errorUpdateCount: errorUpdateCount,
    isEnabled: isEnabled,
  );
}

class _UseQueryResultMatcher<TData, TError> extends Matcher {
  const _UseQueryResultMatcher({
    required this.status,
    required this.fetchStatus,
    required this.data,
    required this.dataUpdatedAt,
    required this.error,
    required this.errorUpdatedAt,
    required this.errorUpdateCount,
    required this.isEnabled,
  });

  final QueryStatus status;
  final FetchStatus fetchStatus;
  final TData? data;
  final dynamic dataUpdatedAt; // Can be DateTime or Matcher
  final TError? error;
  final dynamic errorUpdatedAt; // Can be DateTime or Matcher
  final int errorUpdateCount;
  final bool isEnabled;

  @override
  bool matches(dynamic item, Map matchState) {
    if (item is! UseQueryResult) {
      matchState['reason'] = 'is not a UseQueryResult';
      return false;
    }

    if (item.status != status) {
      matchState['field'] = 'status';
      matchState['expected'] = status;
      matchState['actual'] = item.status;
      return false;
    }

    if (item.fetchStatus != fetchStatus) {
      matchState['field'] = 'fetchStatus';
      matchState['expected'] = fetchStatus;
      matchState['actual'] = item.fetchStatus;
      return false;
    }

    if (item.data != data) {
      matchState['field'] = 'data';
      matchState['expected'] = data;
      matchState['actual'] = item.data;
      return false;
    }

    final actualDataUpdatedAt = item.dataUpdatedAt;
    if (dataUpdatedAt is Matcher) {
      final matcher = dataUpdatedAt as Matcher;
      if (!matcher.matches(actualDataUpdatedAt, {})) {
        matchState['field'] = 'dataUpdatedAt';
        matchState['expected'] = 'to match $dataUpdatedAt';
        matchState['actual'] = actualDataUpdatedAt;
        return false;
      }
    } else if (actualDataUpdatedAt != dataUpdatedAt) {
      matchState['field'] = 'dataUpdatedAt';
      matchState['expected'] = dataUpdatedAt;
      matchState['actual'] = actualDataUpdatedAt;
      return false;
    }

    if (item.error != error) {
      matchState['field'] = 'error';
      matchState['expected'] = error;
      matchState['actual'] = item.error;
      return false;
    }

    final actualErrorUpdatedAt = item.errorUpdatedAt;
    if (errorUpdatedAt is Matcher) {
      final matcher = errorUpdatedAt as Matcher;
      if (!matcher.matches(actualErrorUpdatedAt, {})) {
        matchState['field'] = 'errorUpdatedAt';
        matchState['expected'] = 'to match $errorUpdatedAt';
        matchState['actual'] = actualErrorUpdatedAt;
        return false;
      }
    } else if (actualErrorUpdatedAt != errorUpdatedAt) {
      matchState['field'] = 'errorUpdatedAt';
      matchState['expected'] = errorUpdatedAt;
      matchState['actual'] = actualErrorUpdatedAt;
      return false;
    }

    if (item.errorUpdateCount != errorUpdateCount) {
      matchState['field'] = 'errorUpdateCount';
      matchState['expected'] = errorUpdateCount;
      matchState['actual'] = item.errorUpdateCount;
      return false;
    }

    if (item.isEnabled != isEnabled) {
      matchState['field'] = 'isEnabled';
      matchState['expected'] = isEnabled;
      matchState['actual'] = item.isEnabled;
      return false;
    }

    return true;
  }

  @override
  Description describe(Description description) {
    final parts = <String>[
      '$status',
      '$fetchStatus',
      '$data',
      '$dataUpdatedAt',
      '$error',
      '$errorUpdatedAt',
      '$errorUpdateCount',
      '$isEnabled',
    ];

    return description
        .add('UseQueryResult<$TData, $TError>(${parts.join(', ')})');
  }

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    if (matchState['reason'] != null) {
      return mismatchDescription.add(matchState['reason'] as String);
    }

    if (matchState['field'] != null) {
      return mismatchDescription
          .add('has ${matchState['field']} = ${matchState['actual']} ')
          .add('instead of ${matchState['expected']}');
    }

    return mismatchDescription;
  }
}
