import 'dart:async';

import 'package:async/async.dart';
import 'package:clock/clock.dart';
import 'package:equatable/equatable.dart';
import 'package:fluery/src/paged_query/paged_query.dart';
import 'package:fluery/src/scheduler.dart';
import 'package:fluery/src/conditional_value_listenable_builder.dart';
import 'package:fluery/src/timer_interceptor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:retry/retry.dart';

part 'query.dart';
part 'query_base.dart';
part 'query_builder.dart';
part 'query_cache.dart';
part 'query_client.dart';
part 'query_client_provider.dart';
part 'query_controller.dart';
part 'query_observer.dart';
part 'query_state.dart';

typedef QueryIdentifier = String;

typedef QueryFetcher<Data> = Future<Data> Function(QueryIdentifier id);

typedef RetryCondition = FutureOr<bool> Function(Exception e);

enum QueryStatus {
  idle,
  fetching,
  retrying,
  success,
  failure,
}

extension QueryStatusExtension on QueryStatus {
  bool get isIdle => this == QueryStatus.idle;

  bool get isFetching => this == QueryStatus.fetching;

  bool get isRetrying => this == QueryStatus.retrying;

  bool get isSuccess => this == QueryStatus.success;

  bool get isFailure => this == QueryStatus.failure;
}

typedef QueryWidgetBuilder<T> = Widget Function(
  BuildContext context,
  QueryState<T> state,
  Widget? child,
);

typedef QueryBuilderCondition<T> = bool Function(
  QueryState<T> previousState,
  QueryState<T> currentState,
);

enum RefetchMode {
  never,
  stale,
  always,
}

abstract class _QueryWidgetState<T> {
  Query<T> get query;
  QueryIdentifier get id;
  QueryFetcher<T> get fetcher;
  bool get enabled;
  T? get initialData;
  DateTime? get initialDataUpdatedAt;
  T? get placeholder;
  Duration get staleDuration;
  Duration get cacheDuration;
  RetryCondition? get retryWhen;
  int get retryMaxAttempts;
  Duration get retryMaxDelay;
  Duration get retryDelayFactor;
  double get retryRandomizationFactor;
  Duration? get refetchIntervalDuration;
}
