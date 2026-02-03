/// Network connectivity modes for queries and mutations.
///
/// Determines whether operations should pause when offline and resume when
/// connectivity is restored.
enum NetworkMode {
  /// The default mode that pauses operations when offline.
  ///
  /// Operations will:
  /// - Start in a paused state if offline
  /// - Pause retries if the network becomes unavailable
  /// - Automatically resume when connectivity is restored
  ///
  /// Use this mode for operations that require network connectivity to succeed.
  online,

  /// A mode that ignores network state entirely.
  ///
  /// Operations will:
  /// - Always start immediately
  /// - Continue retrying even when offline
  /// - Never enter the paused state
  ///
  /// Use this mode for operations that don't require network connectivity,
  /// such as local database queries, or when you want to handle offline
  /// scenarios yourself.
  always,

  /// A mode that runs the first attempt immediately but pauses retries when
  /// offline.
  ///
  /// Operations will:
  /// - Start immediately regardless of network state
  /// - Pause retries if the network is unavailable
  /// - Resume retries when connectivity is restored
  ///
  /// Use this mode for offline-first applications where you want to attempt
  /// the operation immediately, such as hitting a service worker cache, but
  /// pause retries if the initial attempt fails while offline.
  offlineFirst,
}
