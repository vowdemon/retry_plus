/// Captures the result or error from one attempt.
sealed class AttemptOutcome<T> {
  const AttemptOutcome();

  /// Creates a successful result outcome.
  const factory AttemptOutcome.result(T result) = AttemptOutcomeResult<T>;

  /// Creates an error outcome.
  const factory AttemptOutcome.error(Object error, StackTrace stackTrace) =
      AttemptOutcomeError<T>;
}

/// A successful attempt outcome.
final class AttemptOutcomeResult<T> extends AttemptOutcome<T> {
  const AttemptOutcomeResult(this.result);

  final T result;
}

/// A failed attempt outcome.
final class AttemptOutcomeError<T> extends AttemptOutcome<T> {
  const AttemptOutcomeError(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;
}
