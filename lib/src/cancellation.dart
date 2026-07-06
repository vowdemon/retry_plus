/// Thrown when retry execution is cancelled.
final class RetryCancelledException implements Exception {
  /// Creates a retry cancellation exception.
  const RetryCancelledException([this.message = 'Retry operation cancelled']);

  /// Human-readable cancellation message.
  final String message;

  @override
  String toString() => 'RetryCancelledException: $message';
}

/// Cooperative cancellation token for retry waits and retry boundaries.
final class CancellationToken {
  Object? _reason;

  /// Whether cancellation was requested.
  bool get isCancelled => _reason != null;

  /// Cancellation reason, when available.
  Object? get reason => _reason;

  /// Requests cancellation.
  void cancel([Object? reason]) {
    _reason = reason ?? const RetryCancelledException();
  }

  /// Throws the cancellation reason when cancellation was requested.
  void throwIfCancelled() {
    final reason = _reason;
    if (reason == null) {
      return;
    }
    if (reason is Exception || reason is Error) {
      throw reason;
    }
    throw RetryCancelledException(reason.toString());
  }
}

/// Returns true when [error] represents cancellation for [token].
bool isCancellationError(Object error, CancellationToken? token) {
  if (error is RetryCancelledException) {
    return true;
  }
  return token?.isCancelled == true && identical(error, token?.reason);
}
