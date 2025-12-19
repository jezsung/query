import 'dart:async';

import 'package:meta/meta.dart';

import 'options/gc_duration.dart';

/// Mixin that provides garbage collection functionality for queries and mutations.
///
/// This mixin is inspired by TanStack Query's Removable class and provides
/// automatic cleanup of unused cache entries after a configurable duration.
///
/// Classes that use this mixin must:
/// - Implement [tryRemove] to define removal logic (including checks for observers, fetching state, etc.)
mixin Removable {
  GcDurationOption _gcDuration = const GcDuration(minutes: 5);
  Timer? _gcTimer;

  /// Updates the garbage collection duration.
  ///
  /// When different garbage collection durations are specified, the longest
  /// one will be used. Use [GcDuration.infinity] to disable garbage collection.
  ///
  /// This matches TanStack Query's `updateGcTime` behavior which uses `Math.max`,
  /// meaning the gcTime can only increase, never decrease during a Query's lifetime.
  /// This is intentional to prevent premature garbage collection.
  void updateGcDuration(GcDurationOption newGcDuration) {
    // Use Math.max equivalent - always keep the longest duration
    // This works because GcDurationInfinity > any GcDuration
    _gcDuration = _gcDuration > newGcDuration ? _gcDuration : newGcDuration;
  }

  /// Schedules garbage collection when the item has no observers.
  ///
  /// If [_gcDuration] is [GcDurationInfinity], garbage collection is disabled
  /// and this method does nothing.
  void scheduleGc() {
    cancelGc();

    // If gcDuration is infinity, garbage collection is disabled
    if (_gcDuration is GcDurationInfinity) {
      return;
    }

    _gcTimer = Timer(_gcDuration as Duration, () {
      tryRemove();
    });
  }

  /// Cancels the garbage collection timer.
  ///
  /// Call this when a new observer subscribes to prevent premature removal.
  void cancelGc() {
    _gcTimer?.cancel();
    _gcTimer = null;
  }

  /// Disposes of resources held by this item.
  ///
  /// Matches TanStack Query's Removable.destroy() method.
  /// Clears the garbage collection timer to prevent further GC attempts.
  @mustCallSuper
  void dispose() {
    cancelGc();
  }

  /// Attempts to remove the item from cache.
  ///
  /// This method must be implemented by classes using this mixin to define
  /// their specific removal logic. Implementations should check conditions like:
  /// - Whether there are active observers
  /// - Whether the item is currently fetching
  /// - Any other conditions that should prevent removal
  ///
  /// Example implementation in Query:
  /// ```dart
  /// void tryRemove() {
  ///   if (!hasObservers && state.fetchStatus == FetchStatus.idle) {
  ///     _cache.remove(this);
  ///   }
  /// }
  /// ```
  void tryRemove();
}
