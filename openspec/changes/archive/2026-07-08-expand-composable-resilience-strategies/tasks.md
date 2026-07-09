## 1. Shared Outcome Foundation

- [x] 1.1 Add tests for a shared typed outcome object representing result and exception outcomes with stack traces.
- [x] 1.2 Add tests for outcome metadata exposing pipeline context, elapsed time, and strategy-local metadata.
- [x] 1.3 Implement shared outcome contracts and metadata types without breaking retry attempt metadata.
- [x] 1.4 Add tests for synchronous and asynchronous outcome predicates.
- [x] 1.5 Implement composable outcome predicates for result matching, exception matching, any, never, OR, AND, and NOT.
- [x] 1.6 Migrate retry decision internals to interoperate with the shared outcome model while preserving public retry semantics.

## 2. Pipeline And Timeout Composition

- [x] 2.1 Add tests documenting outer-to-inner pipeline order with multiple strategies of the same kind.
- [x] 2.2 Add tests showing timeout inside retry acts per attempt and timeout outside retry acts over the whole retry flow.
- [x] 2.3 Add tests for nested timeout strategies and timeout event metadata identifying the producing strategy.
- [x] 2.4 Replace timeout scope-specific core behavior with position-scoped timeout strategy behavior.
- [x] 2.5 Add fixed and generated timeout duration support, including disabled-timeout results from generators.
- [x] 2.6 Preserve caller cancellation vs timeout cancellation distinction in timeout tests and implementation.
- [x] 2.7 Update `RetryPolicy<T>` convenience behavior and docs so explicit `RetryPipeline<T>` is the advanced composition surface.

## 3. Outcome-Based Fallback

- [x] 3.1 Add tests for fallback handling matching exception outcomes and result outcomes.
- [x] 3.2 Add tests for asynchronous fallback callbacks and fallback hooks.
- [x] 3.3 Replace exception-only fallback predicates with outcome-aware fallback predicates and callback factories.
- [x] 3.4 Update fallback execution to pass typed outcome metadata and preserve cancellation bypass.
- [x] 3.5 Update fallback documentation and examples for result fallback and ordered composition.

## 4. Circuit Breaker Expansion

- [x] 4.1 Add tests for circuit failure predicates matching exception outcomes and result outcomes.
- [x] 4.2 Add tests for consecutive-failure meter preserving existing simple breaker behavior.
- [x] 4.3 Add tests for failure-ratio meter with sampling duration and minimum throughput.
- [x] 4.4 Implement pluggable circuit meter contracts and built-in consecutive/ratio meters.
- [x] 4.5 Add tests and implementation for fixed and generated break durations.
- [x] 4.6 Add state provider and manual control APIs with tests for isolate, close, and state observation.
- [x] 4.7 Add asynchronous circuit lifecycle hooks for opened, half-opened, closed, and rejected events.
- [x] 4.8 Ensure circuit rejection exposes retry-after metadata when break duration is known.

## 5. Rate Limiter And Concurrency Limiter

- [x] 5.1 Add tests for lease acquisition, release after success, release after failure, and rejection without invoking inner pipeline.
- [x] 5.2 Define public limiter, lease, limiter context, rejection exception, and rejection hook contracts.
- [x] 5.3 Implement rate limiter strategy using the lease abstraction.
- [x] 5.4 Add built-in concurrency limiter tests for permit limit, FIFO queueing, queue rejection, and queued cancellation.
- [x] 5.5 Implement built-in concurrency limiter.
- [x] 5.6 Add custom limiter tests for retry-after metadata and outer retry handling rate-limit rejection.
- [x] 5.7 Update documentation with limiter and retry composition examples.

## 6. Hedging Strategy

- [x] 6.1 Add tests for hedge delay starting an additional action while the primary action is still running.
- [x] 6.2 Add tests for first acceptable outcome selection across primary and hedged actions.
- [x] 6.3 Add tests that handled outcomes do not win while hedged action capacity remains.
- [x] 6.4 Define hedging predicate, delay generator, action generator, action context, and hook contracts.
- [x] 6.5 Implement hedging execution with maximum hedged attempts and default action generation.
- [x] 6.6 Implement custom hedging action generation and skip semantics.
- [x] 6.7 Add cooperative cancellation tests for losing actions and caller cancellation.
- [x] 6.8 Emit hedging hooks and pipeline events with action metadata.

## 7. Integration And Capability Coverage

- [x] 7.1 Add integration tests for retry + timeout, retry + rate limiter, fallback + timeout, circuit breaker + timeout, and hedging + timeout ordering.
- [x] 7.2 Add tests for nested retry/timeout/hedging combinations equivalent to position-scoped semantics.
- [x] 7.3 Update README strategy composition diagrams and examples.
- [x] 7.4 Update `capability report` to reflect covered capabilities and remaining non-goals.
- [x] 7.5 Run focused tests for outcome, timeout, fallback, circuit breaker, rate limiter, hedging, and pipeline behavior.
- [x] 7.6 Run full Dart test suite.
- [x] 7.7 Run Dart analyzer.
- [x] 7.8 Validate OpenSpec change with strict validation.
