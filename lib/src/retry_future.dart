import 'dart:async';

import 'cancellation.dart';

/// Current lifecycle phase for a retry execution.
enum RetryPhase {
  /// Execution was created but has not entered the pipeline yet.
  pending,

  /// The wrapped operation is currently being attempted.
  attempting,

  /// Retry has scheduled another attempt and is waiting before it runs.
  waiting,

  /// Execution completed with a value.
  completed,

  /// Execution completed with a non-cancellation error.
  failed,

  /// Execution completed because cancellation was requested.
  cancelled,
}

/// Future-compatible handle for one retry execution.
abstract interface class RetryFuture<T> implements Future<T> {
  /// Effective cancellation token for this execution.
  CancellationToken get cancelToken;

  /// Current retry execution phase.
  RetryPhase get phase;

  /// Requests cancellation for this execution.
  void cancel([Object? reason]);
}
