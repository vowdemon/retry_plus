## Context

The telemetry core introduces structured observation, while existing `onXxx` callbacks remain on individual strategies. The current code still has mixed semantics: some event names are broad (`timeout`, `fallback`), some names use shorter strategy labels (`hedge`, `rate_limit`), and retry attempt metadata exposes `nextDelay` even though callers want `onRetry` to run before delay calculation so side effects can influence the next delay.

This change standardizes the lifecycle model before adding more adapters or strategy-specific events. The project is still in development, so breaking public API cleanup is acceptable.

## Goals / Non-Goals

**Goals:**

- Make built-in telemetry event names stable and shaped as `"<strategy>.<event>"`.
- Keep telemetry as the single observation path for logs, metrics, traces, tests, and diagnostics.
- Preserve optional strategy instance names in telemetry source so multiple same-kind strategies in one pipeline remain distinguishable.
- Keep `onXxx` callbacks as awaited side-effect hooks, not telemetry substitutes.
- Define retry timing so `onRetry` runs after retry continuation is accepted but before delay calculation.
- Remove `nextDelay` from retry attempt metadata and retry hooks.
- Replace shared retry hook event typing with direct `RetryAttemptContext<T>` arguments.
- Align hook names with event names where that preserves meaning.
- Add missing side-effect hook coverage for timeout and selected hedging outcomes.

**Non-Goals:**

- Do not add logging adapters, metrics exporters, or tracing exporters.
- Do not add global hook registries or dynamic hook dispatch.
- Do not make telemetry listener failures affect resilience behavior.
- Do not add injection hooks; injection callbacks are already behavior extension points.
- Do not preserve compatibility aliases for old event constants or old retry hook context fields.

## Decisions

### Use canonical event names

Built-in telemetry event names will use strategy category names and lifecycle event names:

| Area | Event names |
| --- | --- |
| Pipeline | `pipeline.started`, `pipeline.succeeded`, `pipeline.failed`, `pipeline.cancelled` |
| Retry | `retry.attempt`, `retry.scheduled`, `retry.give_up` |
| Timeout | `timeout.timed_out` |
| Fallback | `fallback.handling`, `fallback.applied`, `fallback.failed` |
| Circuit breaker | `circuit.opened`, `circuit.half_opened`, `circuit.closed`, `circuit.rejected` |
| Rate limiter | `rate_limiter.rejected` |
| Hedging | `hedging.scheduled`, `hedging.outcome`, `hedging.selected` |
| Injection | `injection.throw`, `injection.delay`, `injection.result`, `injection.behavior` |

Alternative considered: keep existing short names and document them. That leaves inconsistent names in the public API and makes listener filtering less predictable.

### Keep telemetry and hooks separate

Telemetry is observation. It fans out through `TelemetryListener`, assigns severity, and swallows listener failures. Hooks are side effects. They are awaited at documented lifecycle points and hook failures remain visible to the caller.

Alternative considered: express hooks as another listener type. That would blur failure semantics because telemetry must be non-fatal while side effects often need fail-fast behavior.

### Keep strategy instance identity in telemetry source

`RetryPipelineStrategy<T>` carries an optional `name`. Built-in strategies pass that value to telemetry as `TelemetrySource.strategyName`. Event names remain category-level (`retry.scheduled`, `timeout.timed_out`, etc.) so listeners can filter by lifecycle type, while `strategyName` distinguishes multiple strategies of the same kind in one pipeline.

Injection telemetry does not include a separate `kind` attribute because the event type already encodes the injection kind.

Alternative considered: encode instance names into `TelemetryEventType`. That would make event filtering unstable and force every instance to create a different event type for the same lifecycle point.

### Emit telemetry before side-effect hooks at matching lifecycle points

When a telemetry event and hook describe the same lifecycle point, emit telemetry first and then await the hook. This ensures diagnostics still record the decision even when a user side effect fails. The hook still runs before the strategy continues to the next behavior boundary.

Exception: lifecycle telemetry that reports the result of a callback, such as `fallback.applied` or `fallback.failed`, is emitted after that callback returns or throws.

Alternative considered: hook first. Current code often does this, but a hook failure can hide the lifecycle telemetry and make failures harder to diagnose.

### Keep retry telemetry sparse while moving onRetry before delay

Retry has two distinct lifecycle points:

```text
attempt completes
  -> retryIf accepts continuation
  -> onRetry
  -> delay.compute(...)
  -> retry.scheduled
  -> sleep(delay)
```

`onRetry` runs before delay computation. It receives the same `RetryAttemptContext<T>` metadata used by retry decisions, and that metadata does not carry `nextDelay`. The package does not emit a separate pre-delay retry telemetry event because `retry.attempt` already carries the handled decision and `retry.scheduled` reports the computed delay. `retry.scheduled` is telemetry-only because delay is already fixed and the strategy is about to wait.

Alternative considered: keep `onRetry` after delay computation. That prevents side effects from influencing custom delay generation and makes the hook less useful as a behavior extension point.

Alternative considered: add `retry.retrying` before delay computation. That creates three retry events for one handled attempt (`retry.attempt`, `retry.retrying`, `retry.scheduled`) and adds noise without enough extra information.

### Use RetryAttemptContext directly for retry hooks

Remove `RetryEventType` and the shared `RetryEvent<T>` event shape. `onRetry` and `onGiveUp` receive `RetryAttemptContext<T>` directly. It exposes typed attempt outcome, retry index, attempt number, elapsed time, attempt duration, and pipeline context. It does not expose `nextDelay`.

Alternative considered: add purpose-specific hook wrappers around `RetryAttemptContext<T>`. That only creates forwarding types without adding data or preventing invalid states once `nextDelay` is removed.

### Add missing hook surfaces conservatively

Timeout gets `onTimeout(TimeoutContext<T>)` because timeout is a strategy lifecycle point with a concrete side-effect use case. Hedging gets `onSelected(HedgingSelectedContext<T>)` because selected outcome is a distinct decision not covered by `onOutcome`.

Injection does not gain `onInjected` because injection strategies already receive behavior callbacks (`error`, `delay`, `result`, `behavior`) and telemetry covers observation.

## Risks / Trade-offs

- **Breaking API churn** -> Acceptable because the package is in a development version and the change removes ambiguous fields instead of preserving them.
- **More event constants** -> The names mirror actual lifecycle points, which keeps listener filtering clearer than overloading one broad event.
- **Telemetry before hook may surprise existing tests** -> Update tests to assert the documented lifecycle order.
- **Purpose-specific contexts add types** -> The types remove invalid states and make hook contracts clearer.

## Migration Plan

1. Rename built-in `TelemetryEventType` constants and update default severity mapping.
2. Replace retry hook event types with direct `RetryAttemptContext<T>` arguments and remove `nextDelay`.
3. Move retry `onRetry` before delay computation without adding another telemetry event at that point.
4. Emit `retry.scheduled` after delay computation as telemetry-only.
5. Add timeout and hedging selected hook contexts and emission points.
6. Update fallback, circuit breaker, rate limiter, hedging, pipeline, and injection telemetry names.
7. Update README and tests to use new event names and hook contexts.

## Open Questions

None.
