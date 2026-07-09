## 1. Test Layout and Parity Baseline

- [x] 1.1 Create or update `behavior-parity-differences.md` with the agreed difference entry format.
- [x] 1.2 Review the reference behavior classes and map each one to the owning rp capability.
- [x] 1.3 Split mixed strategy tests out of `test/resilience_strategies_test.dart` into module-owned test files without changing assertions.
- [x] 1.4 Split retry-specific behavior out of `test/retry_plus_test.dart` into `test/retry_strategy_test.dart` while leaving facade-specific tests in the facade test.
- [x] 1.5 Keep cross-strategy ordering and same-kind nesting tests in `test/retry_pipeline_test.dart`.
- [x] 1.6 Move shared fixtures, fake clocks, fake limiters, telemetry listeners, and cancellation helpers into `test/test_support.dart`.

## 2. Retry and Pipeline Coverage

- [x] 2.1 Add retry behavior matrix tests for matching exception, non-matching exception, matching result, non-matching result, and cancellation.
- [x] 2.2 Add retry final-outcome tests proving final exception is rethrown and final result is returned after retry budget is exhausted.
- [x] 2.3 Add retry delay policy tests for zero delay, generated delay, async generated delay, null fallback, max/budget behavior, and jitter bounds.
- [x] 2.4 Add retry hook tests for retry hook, give-up hook, async hook ordering, hook state visibility to delay computation, and hook failure propagation.
- [x] 2.5 Add retry telemetry tests for strategy name, local attempt metadata, handled flag, outcome, duration, and nested retry distinguishability.
- [x] 2.6 Add pipeline tests for empty sync/async execution, ordered wrapping, same-kind nested strategies, and custom strategy telemetry.
- [x] 2.7 Add pipeline context tests proving non-retry strategies cannot read retry attempt-local state.
- [x] 2.8 Add pipeline composition tests for retry-timeout ordering, fallback-circuit ordering, injection placement, and same-kind retry nesting.

## 3. Timeout, Fallback, and Circuit Breaker Coverage

- [x] 3.1 Add timeout tests for fast operation preservation, timeout failure metadata, generated timeout, disabled timeout, and caller cancellation winning over timeout.
- [x] 3.2 Add timeout hook and telemetry tests proving events only fire for actual timeout failures.
- [x] 3.3 Add fallback tests for matching exception/result, non-matching exception/result, callback context helpers, async fallback, and callback failure propagation.
- [x] 3.4 Add fallback cancellation tests proving broad predicates and custom predicates do not handle cancellation.
- [x] 3.5 Add fallback hook and telemetry tests for handling start, result applied, and callback failure.
- [x] 3.6 Add circuit breaker state tests for closed, open, half-open, reclosed, reopened, isolated, and manually closed states.
- [x] 3.7 Add circuit breaker metering tests for consecutive failure, failure ratio, minimum throughput, sampling window, reset after success, and generated break duration.
- [x] 3.8 Add circuit breaker predicate tests for matching exceptions, non-matching exceptions, matching results, cancellation bypass, and custom predicate composition.
- [x] 3.9 Add circuit breaker lifecycle tests for state provider, open/half-open/closed/rejected hooks, telemetry, and retry exhaustion counting as one guarded failure.

## 4. Hedging, Rate Limiter, and Injection Coverage

- [x] 4.1 Add hedging tests for delayed hedge start, max hedged attempts, zero delay, disabled delay, and effectively infinite delay.
- [x] 4.2 Add hedging selection tests for primary success, hedge win, handled outcome not winning while capacity remains, all attempts fail, and last outcome semantics.
- [x] 4.3 Add hedging action generator tests for generated action, skipped action, generator failure, default rerun, and per-action context behavior.
- [x] 4.4 Add hedging cancellation tests proving winners cancel losers and caller cancellation reaches all running actions.
- [x] 4.5 Add hedging hook and telemetry tests for scheduled, outcome observed, selected, strategy name, and hook failure propagation.
- [x] 4.6 Add rate limiter tests for lease acquired, lease released after success, lease released after failure, rejection without inner execution, and retry-after metadata.
- [x] 4.7 Add concurrency limiter tests for FIFO queueing, queue-full rejection, queued cancellation, and permit non-leakage.
- [x] 4.8 Add rate limiter hook, telemetry, internal resource disposal, and external resource non-disposal tests.
- [x] 4.9 Add injection trigger tests for always, never, rate boundaries, random source, custom async trigger, and boolean trigger composition.
- [x] 4.10 Add injection strategy tests for throw, result, delay, and behavior injection, including pipeline placement visibility to outer strategies.
- [x] 4.11 Add injection cancellation and telemetry tests for delay cancellation, skipped injection silence, and strategy name on emitted events.

## 5. Outcome, Predicate, Telemetry, and Extension Coverage

- [x] 5.1 Add outcome tests for typed result, error, stack trace, metadata, helper availability, and unavailable metadata failures.
- [x] 5.2 Add default cancellation exclusion tests for broad outcome predicates and strategy predicates.
- [x] 5.3 Add unified predicate tests proving OR, AND, NOT, and async boolean semantics are shared across retry, fallback, circuit breaker, hedging, and injection predicates.
- [x] 5.4 Add built-in predicate tests for exception outcomes, result outcomes, any non-cancellation outcome, and never.
- [x] 5.5 Add telemetry tests for stable event type strings, custom const event types, source fields, listener fan-out, listener failure isolation, severity override, and suppression.
- [x] 5.6 Add pipeline lifecycle telemetry tests for success, failure, cancellation, outcome, stack trace, duration, pipeline key, and operation key.
- [x] 5.7 Add hook lifecycle tests proving telemetry listener failures are isolated while side-effect hook failures propagate.
- [x] 5.8 Add public extension tests for custom pipeline strategy, custom predicates, custom timing policies, custom jitter, custom limiter, and custom telemetry listener.

## 6. Difference Review and Verification

- [x] 6.1 For every failing or intentionally different reference-derived behavior, add or update a `behavior-parity-differences.md` entry with module, reference behavior, rp behavior, test, status, reason, and decision.
- [x] 6.2 Mark any reference behavior that rp cannot express as `bug` or `undecided` unless an rp spec explicitly defines a different behavior.
- [x] 6.3 Run `dart format` on changed Dart test files.
- [x] 6.4 Run `dart analyze`.
- [x] 6.5 Run `dart test`.
- [x] 6.6 Run OpenSpec validation/status checks for `test-parity-behavior-suite`.
