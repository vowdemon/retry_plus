## Context

`retry_plus` currently models retry continuation with two separate concepts: outcome predicates decide whether an outcome is retryable, while stop strategies decide whether retry budget has been exhausted. This split works, but it forces callers to distribute one question across two APIs: "should this execution schedule another attempt?"

Polly retry exposes the same broad capability through `ShouldHandle`, `MaxRetryAttempts`, delay generation, jitter, and `OnRetry`. The goal for `retry_plus` is not to copy Polly's option object or enum-based backoff API. The goal is to make the existing open Dart-style model expressive enough to cover those capabilities.

## Goals / Non-Goals

**Goals:**

- Make `retryIf` the single public continuation decision for retry.
- Let retry decisions inspect both outcome and budget metadata.
- Let retry decision, delay generation, and retry hooks be synchronous or asynchronous.
- Keep delay behavior open and composable rather than enum-driven.
- Preserve final exception rethrow semantics and return final results when result retry stops.
- Keep pipeline execution and cancellation semantics compatible with existing retry behavior where possible.

**Non-Goals:**

- Do not introduce Polly-compatible API names or option objects.
- Do not add `BackoffType` or other fixed backoff enums.
- Do not implement non-retry Polly strategies such as timeout, fallback, circuit breaker, hedging, or rate limiting in this change.
- Do not add runtime dependency injection or external dependencies.

## Decisions

### Decision: remove public stop strategy from the retry decision model

`retryIf` will answer whether another attempt should be scheduled. It will receive a retry attempt view that contains enough metadata to express both outcome predicates and budget rules. Budget conditions such as maximum retry count and elapsed time become retry decision combinators instead of separate stop strategies.

Alternative considered: keep `stopIf` alongside `retryIf`. This preserves the old separation, but keeps two places responsible for one continuation decision and makes custom retry logic harder to reason about.

### Decision: expose attempt-oriented retry decisions

Retry decisions will be based on a typed attempt argument rather than outcome alone. The attempt argument will include the typed outcome, zero-based retry index, one-based attempt number, elapsed time, attempt duration, and shared retry context.

This lets built-in combinators express Polly's `ShouldHandle` and `MaxRetryAttempts`, while custom callbacks can express domain-specific budgets.

### Decision: support `FutureOr` for decision, delay, and hook callbacks

Polly supports asynchronous `ShouldHandle`, delay generation, and retry hooks. `retry_plus` will support the same capability through Dart `FutureOr` rather than separate sync/async APIs.

This keeps the API small while allowing callers to inspect asynchronous signals such as response body content or external budget state.

### Decision: keep delay as an open strategy model

Delay remains a strategy/extension point. Fixed, linear, exponential, random, generated, jittered, capped, fallback, and stateful delays are expressed as delay implementations and combinators. No enum is introduced.

Generated delay may return `null`; callers can combine that with fallback delay behavior to model Polly's "use generated delay when valid, otherwise use calculated delay" semantics.

### Decision: make hooks observational

`onRetry` observes scheduled retries and may be asynchronous, but it does not decide whether retry occurs. Continuation stays in `retryIf`; wait calculation stays in `delay`.

Hook arguments include outcome, retry delay, retry index, attempt number, attempt duration, and elapsed time so callers can implement telemetry without altering retry logic.

## Risks / Trade-offs

- **Breaking API churn**: Existing `StopStrategy` callers must migrate to retry decision combinators and time strategy composition. Mitigation: provide direct combinators such as max retries, keep timeout/time strategy composition for time budgets, and update examples.
- **Large `retryIf` callbacks**: Putting all continuation logic in `retryIf` can tempt callers into monolithic predicates. Mitigation: provide composable retry decision helpers with OR, AND, and NOT semantics.
- **Async decision complexity**: Async predicates can add latency before retry delay is computed. Mitigation: document that `retryIf` runs after each attempt and before delay generation.
- **Stateful delay leakage**: Stateful jitter algorithms can accidentally share state between executions. Mitigation: delay strategies that need mutable state must create per-execution state from the retry context or an execution-scoped helper.
- **Result exhaustion semantics**: If `retryIf` returns false after retryable-looking results due to budget, the engine returns the final result to match Polly-style retry outcome behavior. Mitigation: keep give-up metadata for observation without turning the result into a failure.

## Migration Plan

1. Add the new attempt-oriented retry decision and delay contracts behind tests.
2. Replace stop-strategy-driven retry loop logic with unified `retryIf` continuation logic.
3. Add built-in retry decision combinators for exception/result matching, max retries, and boolean composition.
4. Add delay combinators needed to cover Polly retry delay behavior.
5. Migrate existing tests and examples from stop strategies to retry decision combinators.
6. Remove or unexport the old stop-strategy public path for retry.

Rollback is straightforward while this remains unreleased: revert this change and keep the existing stop-strategy model.

## Open Questions

- None.
