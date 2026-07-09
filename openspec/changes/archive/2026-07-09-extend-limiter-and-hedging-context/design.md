## Context

`retry_plus` currently has a clean limiter model: `RateLimiterStrategy` delegates algorithm decisions to a public `RateLimiter` contract. The only built-in limiter is concurrency-based. Time-window limiting can be implemented by users through `RateLimiter`, but common algorithms are not available out of the box.

## Goals / Non-Goals

**Goals:**

- Add built-in token bucket, fixed window, and sliding window limiters without changing `RateLimiterStrategy`.
- Define deterministic `retryAfter` behavior for limiter rejections.
- Keep time-based limiter state driven by calls and `clock.now()` instead of background timers.

**Non-Goals:**

- No distributed limiter, partitioned limiter, adaptive limiter, or framework registry integration.
- No background refill worker or disposer lifecycle for built-in limiters.
- No compatibility shim for old development APIs if naming changes are needed during implementation.

## Decisions

### Keep `RateLimiterStrategy` algorithm-agnostic

Built-in limiter classes SHALL implement the existing `RateLimiter` contract and return `RateLimitLease` values. `RateLimiterStrategy` should not branch on limiter type.

Alternative considered: add strategy-level options for each algorithm. That would make the strategy configuration-oriented and less open than the current design.

### Use lazy, clock-driven time accounting

Time-based limiters SHALL refresh their state during `acquire()` using the current pipeline clock. They SHALL NOT start timers, isolates, or background refill work.

This keeps tests deterministic with `package:clock`, avoids resource disposal concerns, and keeps limiter instances simple library objects.

### Provide immediate rejection for time-based limiters

The first implementation SHOULD reject immediately when a time-based limiter has no capacity. It SHALL provide `retryAfter` when the next permitted time can be computed.

Queuing is already covered by `ConcurrencyLimiter`. Adding queues to every time algorithm would introduce cancellation and fairness complexity that is not needed to cover the core rate-limiting behavior.

## Risks / Trade-offs

- [Risk] Time-based limiters without queues may be seen as incomplete for throttling workloads. → Mitigation: keep the `RateLimiter` contract open so users can provide queued or distributed algorithms later.
- [Risk] Sliding window math can be off by one around segment boundaries. → Mitigation: write clock-controlled boundary tests for segment rotation, stale segment removal, and retry-after.

## Migration Plan

- Add tests for built-in limiter algorithms first.
- Implement limiters behind the existing `RateLimiter` interface.
- Run format, analyze, tests, and OpenSpec validation.

No runtime data migration is required.
