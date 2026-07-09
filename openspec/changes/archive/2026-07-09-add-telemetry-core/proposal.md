## Why

`retry_plus` currently exposes lightweight `PipelineEvent` callbacks, but the event model is not structured enough for reliable logging, metrics, tracing adapters, or cross-strategy diagnostics. A first-class telemetry core gives all resilience strategies one stable observation model without making logging or metrics part of strategy behavior.

## What Changes

- **BREAKING** Replace the lightweight `PipelineEvent`/`onEvent` observation surface with a structured telemetry model.
- Add `TelemetryEvent<T>` with event type, source, severity, timestamp, elapsed time, optional duration, optional outcome, optional error/stack trace, and structured attributes.
- Add `TelemetrySource` for pipeline key and operation key.
- Add `TelemetrySeverity` and a severity provider that can downgrade, upgrade, or suppress events with `none`.
- Add `TelemetryListener` and `TelemetryOptions` so callers can attach one or more event consumers.
- Emit telemetry for pipeline lifecycle events and all built-in strategy events, including retry, timeout, fallback, circuit breaker, rate limiter, hedging, and injection.
- Add retry attempt telemetry with attempt number, duration, handled flag, outcome, and next delay.
- Do not add built-in logging adapters, metrics counters/histograms, OpenTelemetry exporters, dependency injection, registry, or dynamic reload in this change.

## Capabilities

### New Capabilities

- `telemetry-core`: Structured telemetry events, sources, severities, listener fanout, suppression, and strategy event coverage.

### Modified Capabilities

- `retry-pipeline`: Replace lightweight event callbacks with structured telemetry configuration and document pipeline naming/source behavior.
- `public-extension-points`: Add telemetry listeners and telemetry severity providers to the documented extension surface.

## Impact

- Adds public telemetry API in `lib/src/telemetry.dart` and exports it from `retry_plus.dart`.
- Updates `RetryPipeline<T>`, `RetryPolicy<T>`, `RetryContext<T>`, and all built-in strategies to emit structured telemetry.
- Removes or replaces `onEvent` and `PipelineEvent` public usage in tests and README because this is a development version and compatibility is not required.
- Adds focused telemetry tests for event ordering, source metadata, severity suppression, listener fanout, retry attempt telemetry, and strategy coverage.
- Updates README examples from `onEvent` to `telemetry`.
