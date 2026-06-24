/// Decides whether an observing widget should rebuild when a query result
/// changes.
///
/// Receives the [previous] result the widget last rendered with and the [next]
/// result just produced. Return `true` to rebuild, or `false` to suppress the
/// rebuild and keep showing [previous].
typedef ShouldRebuild<TResult> = bool Function(TResult previous, TResult next);
