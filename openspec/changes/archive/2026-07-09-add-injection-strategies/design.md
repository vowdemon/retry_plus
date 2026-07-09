## Context

`retry_plus` now has an explicit `RetryPipeline<T>` composition model and first-class retry, timeout, fallback, circuit breaker, hedging, and rate limiter strategies. Tests and resilience drills still need a way to deliberately disturb pipeline executions without changing production strategies or depending on external service failures.

The design must fit the existing open model: strategy order decides scope, predicates are composable and async-capable, cancellation is cooperative, and observation flows through `PipelineEvent` instead of per-feature hooks when hooks are not necessary.

## Goals / Non-Goals

**Goals:**

- Add explicit injection strategies for throw, delay, result, and custom behavior disturbances.
- Keep trigger logic open through `InjectionTrigger<T>` rather than fixed enum-style configuration.
- Preserve existing pipeline ordering semantics so injection can be placed inside retry, inside timeout, outside circuit breaker, and so on.
- Use `PipelineEvent` for observation instead of injection-specific hooks.
- Keep injection out of `RetryPolicy<T>` convenience fields so callers opt into it through `RetryPipeline<T>`.

**Non-Goals:**

- Do not use chaos or mock naming.
- Do not add global injection registries, global enable/disable switches, DI containers, or dynamic reload.
- Do not change retry, fallback, circuit breaker, timeout, hedging, or rate limiter internals.
- Do not make skipped injection produce events by default.

## Decisions

### Use `Injection*` naming

The public API will use `InjectionTrigger<T>`, `RetryPipelineContext<T>`, and strategy names such as `InjectionThrowStrategy<T>`. This keeps the feature aligned with the fault-injection concept while avoiding external project names and the testing-double implication of `Mock`.

Alternative considered: `Fault*`. It is technically accurate, but names such as `FaultResultStrategy` can read like a strategy for handling faults rather than deliberately producing them.

### Model injection as ordinary pipeline strategies

Each injection strategy implements `RetryPipelineStrategy<T>`. Strategy position determines whether retry sees injection errors, timeout covers injection delays, fallback handles injection outcomes, or circuit breaker counts injection-produced failures.

`RetryPolicy<T>` will not grow injection fields. Callers who need injection use `RetryPipeline<T>` explicitly.

Alternative considered: add `injection` to `RetryPolicy<T>`. That would make a test/drill feature too prominent in the convenience API and obscure ordering semantics.

### Use one open trigger abstraction

`InjectionTrigger<T>` will extend the existing context-predicate composition model and expose factories such as:

- `InjectionTrigger.rate(double rate)`
- `InjectionTrigger.always()`
- `InjectionTrigger.never()`
- `InjectionTrigger.where(FutureOr<bool> Function(RetryPipelineContext<T> context))`

The trigger receives the current `RetryPipelineContext<T>` directly. This covers rate-based, elapsed-time-based, environment-based, cancellation-aware, and async external-control decisions without fixed configuration enums or an injection-specific forwarding context.

### Keep four focused strategies

- `InjectionThrowStrategy<T>`: when triggered, throws an error produced by a callback and does not call the inner pipeline.
- `InjectionDelayStrategy<T>`: when triggered, waits for a generated delay using `RetryPipelineContext.sleep`, then calls the inner pipeline.
- `InjectionResultStrategy<T>`: when triggered, returns a generated result and does not call the inner pipeline.
- `InjectionBehaviorStrategy<T>`: when triggered, runs a custom behavior callback, then calls the inner pipeline.

`InjectionBehaviorStrategy<T>` intentionally does not replace the result. Callers that need replacement use `InjectionResultStrategy<T>`, keeping behavior effects and outcome replacement separate.

### Observe through pipeline events only

The feature will add `PipelineEventType` values:

- `injectionThrow`
- `injectionDelay`
- `injectionResult`
- `injectionBehavior`

Triggered injection emits one event before returning, throwing, delaying, or running behavior. Skipped injection emits no event. Telemetry source includes `strategyName` when named, and event attributes include `elapsed` plus kind-specific data such as `delay`. Injection does not expose retry attempt metadata because it receives only `RetryPipelineContext<T>`.

No `onInjection` or `onSkipped` hook is added. Existing `onEvent` provides a single observation path.

### Preserve cancellation semantics

Every strategy checks cancellation before evaluating or applying injection. Delay injection uses `RetryPipelineContext.sleep(delay)` instead of bare timers, so caller cancellation is observed before and after the delay. Cancellation remains cancellation and is not converted into an injection outcome.

## Risks / Trade-offs

- **Injection can be accidentally used in production** -> Keep it out of `RetryPolicy<T>` convenience API, document it as test/drill-oriented, and make usage explicit through `RetryPipeline<T>`.
- **Rate-based behavior can make tests flaky** -> Use `RetryPipelineContext.random` consistently and provide `InjectionTrigger.where` for deterministic tests.
- **`InjectionBehaviorStrategy<T>` can perform arbitrary side effects** -> Keep it narrow: behavior runs only when triggered and then calls the inner pipeline. Result replacement belongs to `InjectionResultStrategy<T>`.
- **No skipped events means less observability for non-triggered checks** -> This is intentional to avoid event noise. Tests can use deterministic triggers when they need exact behavior.
