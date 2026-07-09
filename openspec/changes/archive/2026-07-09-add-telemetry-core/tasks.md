## 1. Telemetry API

- [x] 1.1 Add `lib/src/telemetry.dart` with `TelemetryEvent<T>`, `TelemetryEventType`, `TelemetrySource`, `TelemetrySeverity`, `TelemetryOptions`, and `TelemetryListener`.
- [x] 1.2 Add callback listener and in-memory listener helpers for simple custom behavior and tests.
- [x] 1.3 Add default severity mapping and caller severity provider suppression with `TelemetrySeverity.none`.
- [x] 1.4 Export telemetry API from `lib/src/retry_plus.dart`.

## 2. Pipeline Integration

- [x] 2.1 Replace `RetryPipeline<T>.onEvent` with `TelemetryOptions? telemetry`, optional `name`, and optional `instance`.
- [x] 2.2 Add optional `operationKey` to `RetryPipeline.execute`, `RetryPolicy.execute`, and top-level `retry`.
- [x] 2.3 Update `RetryContext<T>` to expose the execution telemetry sink with source, elapsed time, timestamp, outcome, error, stack trace, duration, and attributes.
- [x] 2.4 Emit pipeline started, completed, failed, and cancelled telemetry.
- [x] 2.5 Ensure listener failures do not affect pipeline results, failures, cancellation, or strategy behavior.

## 3. Strategy Telemetry

- [x] 3.1 Update retry strategy to emit retry attempt, retry scheduled, and retry give-up telemetry with attempt number, duration, handled flag, outcome, and next delay.
- [x] 3.2 Update timeout strategy telemetry with timeout duration, elapsed time, and timeout error.
- [x] 3.3 Update fallback strategy telemetry with handled outcome and fallback error/result context.
- [x] 3.4 Update circuit breaker telemetry for opened, half-open, closed, and rejected events.
- [x] 3.5 Update rate limiter telemetry for rejection and retry-after data.
- [x] 3.6 Update hedging telemetry for scheduled, outcome, and selected events.
- [x] 3.7 Update injection telemetry for throw, delay, result, and behavior events.

## 4. Public Surface Cleanup

- [x] 4.1 Remove or replace `PipelineEvent`/`PipelineEventType` public API and update imports.
- [x] 4.2 Update README examples and documentation from `onEvent` to telemetry options/listeners.
- [x] 4.3 Update OpenSpec tasks and docs to reflect telemetry replacing lightweight events.

## 5. Tests

- [x] 5.1 Add telemetry model tests for listener fanout, callback listener, in-memory listener, default severity, severity override, and suppression.
- [x] 5.2 Add pipeline telemetry tests for lifecycle events, source fields, operation key, duration, outcome/error, stack trace, and listener failure isolation.
- [x] 5.3 Update existing pipeline, retry, timeout, fallback, circuit breaker, rate limiter, hedging, and injection tests to use telemetry.
- [x] 5.4 Add retry attempt telemetry tests covering handled flag, attempt duration, next delay, result outcomes, and error outcomes.

## 6. Verification

- [x] 6.1 Run `dart format` on modified Dart files.
- [x] 6.2 Run `dart analyze`.
- [x] 6.3 Run targeted telemetry, pipeline, retry, timeout, fallback, circuit breaker, rate limiter, hedging, and injection tests.
- [x] 6.4 Run `openspec validate add-telemetry-core --strict`.
