## Why

Telemetry event names and strategy hooks currently overlap in purpose but are not defined by one lifecycle model. This makes retry delay timing ambiguous, leaves some event names too broad, and forces callers to infer whether an `onXxx` callback is observation or behavior.

## What Changes

- **BREAKING** Standardize built-in telemetry event type names as `"<strategy>.<event>"`.
- **BREAKING** Split retry lifecycle semantics so `onRetry` happens before delay calculation and retry attempt metadata does not expose `nextDelay`.
- **BREAKING** Replace retry hook event typing with direct `RetryAttemptContext<T>` arguments instead of a shared `RetryEventType`.
- Clarify that telemetry is the unified observation channel and must not affect resilience behavior.
- Add optional strategy instance names to telemetry source so same-kind strategies in a pipeline can be distinguished without changing event types.
- Clarify that `onXxx` hooks are awaited side-effect callbacks and may affect execution if they throw.
- Add missing lifecycle coverage where needed, including timeout side-effect hooks and selected hedging outcome hooks.
- Align strategy event names and hook names without forcing names to match when it would reduce semantic clarity.

## Capabilities

### New Capabilities

- `telemetry-hook-lifecycle`: Canonical built-in telemetry event names, hook context definitions, and trigger timing across pipeline and strategies.

### Modified Capabilities

- `public-extension-points`: Document telemetry as observation and `onXxx` hooks as awaited side-effect extension points.
- `strategy-retry`: Change retry hook timing and remove `nextDelay` from retry attempt metadata.
- `timeout-strategy`: Add timeout hook semantics aligned with timeout telemetry.
- `fallback-strategy`: Clarify fallback handling/applied/failed telemetry timing and `onFallback` timing.
- `circuit-breaker-strategy`: Align circuit breaker telemetry event names with state transition semantics.
- `rate-limiter-strategy`: Align rate limiter rejection telemetry naming and hook timing.
- `hedging-strategy`: Align hedging telemetry naming and add selected-outcome hook semantics.
- `retry-pipeline`: Rename pipeline completion telemetry to success/failure/cancellation lifecycle names.

## Impact

- Updates public telemetry event constants in `lib/src/telemetry.dart`.
- Updates retry hook API in `lib/src/retry_strategy.dart`, `lib/src/retry_policy.dart`, and top-level retry helpers.
- Updates timeout, fallback, circuit breaker, rate limiter, and hedging strategy hook/telemetry emission sites.
- Updates pipeline strategy identity and telemetry source fields for optional strategy instance names.
- Updates tests and README examples for new event names, retry hook timing, and hook context fields.
- No new runtime dependencies.
