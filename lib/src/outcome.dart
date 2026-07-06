/// Captures the result or error from one attempt.
final class AttemptOutcome<T> {
  const AttemptOutcome._({this.result, this.error, this.stackTrace});

  /// Creates a successful result outcome.
  const AttemptOutcome.result(T result) : this._(result: result);

  /// Creates an error outcome.
  const AttemptOutcome.error(Object error, StackTrace stackTrace)
    : this._(error: error, stackTrace: stackTrace);

  /// The returned result, when the attempt succeeded.
  final T? result;

  /// The thrown error, when the attempt failed.
  final Object? error;

  /// The captured stack trace, when the attempt failed.
  final StackTrace? stackTrace;

  /// Whether this outcome contains an error.
  bool get hasError => error != null;
}
