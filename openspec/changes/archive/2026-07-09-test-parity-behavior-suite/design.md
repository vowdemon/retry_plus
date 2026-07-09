## Context

The current test suite already covers many `retry_plus` behaviors, but several strategy tests are grouped by implementation history rather than by the owning OpenSpec capability. The package also uses a reference implementation's tests as a behavior benchmark, while deliberately avoiding API compatibility as a goal.

This change turns the benchmark into a repeatable behavior parity process:

- every module spec owns the behavior tests for that module;
- cross-strategy ordering and same-kind nesting belong to `retry-pipeline`;
- reference differences are explicit and documented.

## Goals / Non-Goals

**Goals:**

- Make each module spec describe the behavior tests that prove its own contract.
- Keep strategy-specific tests in strategy-specific files.
- Keep pipeline-order and interaction tests in pipeline tests.
- Compare rp behavior against reference tests at the logical behavior level.
- Produce a difference report when rp behavior intentionally or accidentally differs.
- Preserve rp API design freedom, including open predicates, open policies, and explicit strategy ordering.

**Non-Goals:**

- Do not copy the reference API shape.
- Do not port implementation-detail tests that only verify internal helper mechanics.
- Do not require runtime code changes unless tests expose an actual behavior gap.
- Do not make one global parity test file responsible for all strategy behavior.

## Decisions

### Decision: Test ownership follows spec ownership

Each `openspec/specs/<capability>/spec.md` receives its own behavior-test requirement. The matching tests should live in a corresponding test file when possible:

- `strategy-retry` -> `test/retry_strategy_test.dart`
- `timeout-strategy` -> `test/timeout_strategy_test.dart`
- `fallback-strategy` -> `test/fallback_strategy_test.dart`
- `circuit-breaker-strategy` -> `test/circuit_breaker_strategy_test.dart`
- `hedging-strategy` -> `test/hedging_strategy_test.dart`
- `rate-limiter-strategy` -> `test/rate_limiter_strategy_test.dart`
- `injection-strategy` -> `test/injection_strategy_test.dart`
- `telemetry-core` and `telemetry-hook-lifecycle` -> `test/telemetry_test.dart`
- `outcome-handling` and `outcome-predicate-unification` -> `test/outcome_handling_test.dart`
- `retry-pipeline` -> `test/retry_pipeline_test.dart`

Alternative considered: keep all reference parity tests in one file. That would make comparison easy at first, but it would hide ownership and make failures harder to map back to module specs.

### Decision: Pipeline tests own composition semantics

Any behavior whose result changes when strategy order changes belongs to `retry-pipeline`. Strategy specs should only test the strategy's local contract and the minimum external interactions needed to prove that contract.

Examples:

- Retry's local final-outcome semantics belong to `strategy-retry`.
- `retry outside timeout` versus `timeout outside retry` belongs to `retry-pipeline`.
- Circuit breaker state transitions belong to `circuit-breaker-strategy`.
- "Retry exhaustion counts as one breaker failure" belongs to `circuit-breaker-strategy` because it defines breaker accounting for one guarded execution.

### Decision: Compare capabilities, not APIs

The reference suite is used to identify behavior classes: handled outcome, retry budget, cancellation boundary, hook timing, telemetry, state transition, and resource ownership. rp tests should express the same capability through rp's own API.

If the reference test asserts a fixed enum or configuration model and rp uses an open function/policy model, the rp test should assert the equivalent observable behavior rather than the same options.

### Decision: Difference reports are part of the workflow

When an rp behavior test produces a different result than the reference behavior, the implementation must add or update a difference report entry. The entry should say whether the difference is intentional, a bug, or undecided.

Suggested report path:

- `behavior-parity-differences.md`

Suggested entry shape:

```md
## Difference: <short behavior name>

- Module: <capability>
- Reference behavior: <observable behavior>
- rp behavior: <observable behavior>
- Test: <rp test path and test name>
- Status: intentional | bug | undecided
- Reason:
- Decision:
```

### Decision: Use behavior matrices before adding many edge tests

For each strategy, prioritize a compact matrix:

- handled exception
- unhandled exception
- handled result
- unhandled result
- cancellation
- hook success/failure
- telemetry event

Then add strategy-specific mechanics: retry delay, timeout duration, circuit state, hedge selection, limiter lease, injection trigger, etc.

## Risks / Trade-offs

- [Risk] The test suite becomes too large and slow. -> Mitigation: start with behavior matrices and only port reference cases that add distinct public behavior coverage.
- [Risk] Tests overfit reference implementation details. -> Mitigation: require every reference-derived test to be phrased as observable rp behavior.
- [Risk] Difference reports become stale. -> Mitigation: require each intentional difference to name the rp test that proves current behavior.
- [Risk] Splitting tests creates temporary duplication. -> Mitigation: move tests module-by-module and keep shared helpers in `test/test_support.dart`.
- [Risk] Cross-strategy ownership is ambiguous. -> Mitigation: if order changes the result, place it under `retry-pipeline`; otherwise place it under the strategy that owns the state or decision.
