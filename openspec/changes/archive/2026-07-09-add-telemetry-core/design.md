## Context

`retry_plus` has a lightweight `PipelineEvent` model with a single `onEvent` callback. That is enough for simple tests, but it is not a stable telemetry foundation: event payloads are loosely shaped maps, source information is incomplete, event severity is absent, retry attempt outcomes are not consistently reported, and logging/metrics adapters would have to infer too much.

The project is still in a development version, so compatibility is not required. The design can replace the current observation surface instead of layering a long-lived compatibility shim on top of it.

## Goals / Non-Goals

**Goals:**

- Add structured telemetry events for pipeline and strategy observation.
- Keep telemetry event types open so custom strategies can emit their own typed events.
- Make telemetry independent from strategy behavior; no logging strategy.
- Support multiple listeners through one telemetry sink.
- Support severity assignment and suppression through an open callback.
- Provide stable event source fields: pipeline key and operation key.
- Emit retry attempt telemetry with duration, handled flag, outcome, and next delay.
- Preserve an open attributes map for strategy-specific fields such as `attemptNumber`, `delay`, `retryAfter`, `state`, and `actionIndex`.

**Non-Goals:**

- Do not add logging adapters in this change.
- Do not add metrics counters, histograms, or OpenTelemetry exporters in this change.
- Do not add telemetry enrichers in this change.
- Do not add dependency injection, pipeline registry, dynamic reload, or global telemetry configuration.
- Do not make telemetry listeners affect resilience behavior.

## Decisions

### Replace `PipelineEvent` with `TelemetryEvent<T>`

The public event model will move from `PipelineEvent` to `TelemetryEvent<T>`. The new event carries:

- `TelemetryEventType type`
- `TelemetrySource source`
- `TelemetrySeverity severity`
- `DateTime timestamp`
- `Duration elapsed`
- optional `Duration duration`
- optional `StrategyOutcome<T> outcome`
- optional `Object error`
- optional `StackTrace stackTrace`
- `Map<String, Object?> attributes`

Alternative considered: keep `PipelineEvent` and add fields. That would preserve a name tied to pipeline lifecycle rather than strategy telemetry and keep the map-heavy old shape visible.

`TelemetryEventType` is a const extension type over a string name, not an enum.
Built-in events are exposed as static constants, while custom strategies can
define their own const event types without waiting for the package to add enum
members.

### Keep source explicit but optional

`TelemetrySource` will carry `pipelineKey` and `operationKey`. Both fields remain optional so callers can start small, but the fields are stable when they need production diagnostics.

`RetryPipeline<T>` owns the pipeline key default. `RetryPipeline.execute` accepts `operationKey` so call sites can identify one operation without rebuilding the pipeline. Strategy category is represented by `TelemetryEventType`; strategy-specific labels remain local to strategy errors or context objects instead of becoming source identity.

Alternative considered: store arbitrary source tags in metadata. This repeats the `metadata` problem and makes listener implementations less reliable.

### Use listeners, not hooks per strategy

`TelemetryOptions` will contain a list of `TelemetryListener`s. A listener receives every event that is not suppressed. Logging, metrics, tracing, and tests can all be listeners.

The existing strategy-specific hooks such as `onRetry`, `onFallback`, `onOpened`, and `onHedge` remain behavior lifecycle callbacks. They are not telemetry replacements and should not be required for observation.

Alternative considered: add one hook per telemetry event type. That fragments observation and makes fanout the caller's problem.

### Add severity provider but no enricher

Built-in default severity will be assigned by event type. A caller can provide a severity callback to change the severity or return `TelemetrySeverity.none` to suppress the event.

No `TelemetryEnricher` is added in the first version. If callers need common attributes, they can wrap or implement a listener. This keeps the core model smaller and avoids mutable event-builder APIs for now.

### Make listener failures non-fatal

Telemetry must not change resilience behavior. Listener failures are swallowed by the telemetry sink. A failing listener must not turn a successful operation into a failed operation, nor block retry/fallback/circuit decisions.

Alternative considered: propagate listener errors. That makes observation part of resilience semantics and is too surprising for telemetry.

### Keep attributes structured but narrow

`attributes` remains a `Map<String, Object?>` for event-specific fields. It is not a caller-supplied freeform strategy metadata bag. Built-in strategies populate stable field names that tests can assert.

## Risks / Trade-offs

- **Breaking API churn** -> Acceptable because this is a development version. README and tests will be updated in the same change.
- **Listener errors can be hidden** -> This is intentional for resilience safety. Test listeners can expose errors by storing them internally.
- **No metrics/logging adapter in first change** -> The structured event model is the foundation. Adapters can be added later without changing strategy behavior.
- **Event attributes still use a map** -> The map is constrained to stable built-in fields. Core fields are strongly typed on `TelemetryEvent`.

## Migration Plan

1. Add `telemetry.dart` public model.
2. Replace `PipelineEvent` emission with the telemetry sink exposed by `RetryContext`.
3. Update `RetryPipeline`, `RetryPolicy`, and top-level `retry` to accept `TelemetryOptions` and source fields.
4. Update all strategy event emission sites.
5. Update tests and README from `onEvent` to telemetry listeners.
6. Remove obsolete `pipeline_event.dart` exports if no public references remain.

## Open Questions

None for this change. Logging, metrics, OpenTelemetry, and enrichers are intentionally left for later changes.
