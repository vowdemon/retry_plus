## 1. Telemetry Event Model

- [x] 1.1 Rename built-in `TelemetryEventType` constants to the canonical `"<strategy>.<event>"` names.
- [x] 1.2 Update `defaultTelemetrySeverity` to use the renamed event constants.
- [x] 1.3 Update all built-in telemetry emission sites to use canonical event names and stable attributes.
- [x] 1.4 Update telemetry tests that assert event type names, ordering, severity, and suppression.

## 2. Retry Hook Lifecycle

- [x] 2.1 Replace shared retry hook event typing with direct `RetryAttemptContext<T>` hook arguments.
- [x] 2.2 Remove `nextDelay` from retry attempt metadata and public retry hook assertions.
- [x] 2.3 Move `onRetry` to after `retryIf` accepts continuation and before delay calculation without adding another telemetry event at that point.
- [x] 2.4 Emit `retry.scheduled` after delay calculation with computed delay as telemetry-only.
- [x] 2.5 Update `RetryStrategy`, `RetryPolicy`, and top-level retry helper signatures for direct retry attempt hook arguments.
- [x] 2.6 Add tests proving `onRetry` can affect state read by the next delay calculation.

## 3. Strategy Hook And Telemetry Alignment

- [x] 3.1 Add timeout hook context and `onTimeout` execution for strategy-owned timeouts only.
- [x] 3.2 Split fallback telemetry into `fallback.handling`, `fallback.applied`, and `fallback.failed`.
- [x] 3.3 Align circuit breaker telemetry with `circuit.opened`, `circuit.half_opened`, `circuit.closed`, and `circuit.rejected`.
- [x] 3.4 Align rate limiter telemetry with `rate_limiter.rejected` and preserve rejection hook timing.
- [x] 3.5 Rename hedging telemetry to `hedging.*` and add selected-outcome hook context and callback.
- [x] 3.6 Keep injection telemetry on canonical `injection.*` events and avoid adding generic injection hooks.
- [x] 3.7 Add optional strategy instance names to pipeline strategies and telemetry source.
- [x] 3.8 Remove redundant injection `kind` telemetry attributes because event names already encode injection kind.

## 4. Documentation And Examples

- [x] 4.1 Update README telemetry examples to use canonical event names.
- [x] 4.2 Update README retry hook examples so `onRetry` no longer reads `nextDelay`.
- [x] 4.3 Document telemetry as observation and `onXxx` callbacks as awaited side-effect hooks.
- [x] 4.4 Remove stale references to old event constants, `RetryEventType`, and retry hook `nextDelay`.

## 5. Verification

- [x] 5.1 Run Dart formatting for changed Dart files and tests.
- [x] 5.2 Run static analysis.
- [x] 5.3 Run the full test suite.
- [x] 5.4 Run strict OpenSpec validation for `standardize-telemetry-hooks`.
