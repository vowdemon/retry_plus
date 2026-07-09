## 1. Context Type Boundary

- [x] 1.1 Rename the shared execution context type from `RetryContext<T>` to `RetryPipelineContext<T>`.
- [x] 1.2 Remove retry attempt-local fields and methods from pipeline context, including attempt number, attempt advancement, and latest retry outcome.
- [x] 1.3 Update `RetryPipelineStrategy<T>.execute` and all built-in strategy signatures to accept `RetryPipelineContext<T>`.
- [x] 1.4 Update `StrategyOutcome` and outcome predicate contexts so their context remains pipeline-scoped.

## 2. Retry Attempt Context

- [x] 2.1 Replace `RetryAttempt<T>` with `RetryAttemptContext<T>` carrying pipeline context, outcome, local retry index, local attempt number, elapsed time, and attempt duration.
- [x] 2.2 Update `RetryStrategy<T>` to maintain attempt number and retry index as local variables per strategy execution.
- [x] 2.3 Add coverage proving nested retry strategies keep independent local attempt sequences.
- [x] 2.4 Update retry telemetry attributes to report local attempt metadata for the emitting retry strategy instance.

## 3. Retry Collaborator APIs

- [x] 3.1 Update `RetryIf<T>` and built-in retry decisions to consume `RetryAttemptContext<T>`.
- [x] 3.2 Update `DelayStrategy` so fixed, linear, exponential, random, generated, fallback, additive, and stateful delay paths consume `RetryAttemptContext<T>`.
- [x] 3.3 Update `onRetry` and `onGiveUp` hook signatures and tests to receive `RetryAttemptContext<T>`.
- [x] 3.4 Remove or update old `RetryAttempt` and `RetryContext` public references in README and tests.

## 4. Non-Retry Strategy Isolation

- [x] 4.1 Update timeout, fallback, circuit breaker, rate limiter, hedging, injection, and custom strategy examples to use only `RetryPipelineContext<T>`.
- [x] 4.2 Remove retry attempt-number usage from injection triggers and injection tests.
- [x] 4.3 Add checks or tests showing non-retry strategies cannot access retry attempt-local metadata through their context.
- [x] 4.4 Update active OpenSpec artifacts for injection and telemetry to use `RetryPipelineContext<T>` and `RetryAttemptContext<T>` names consistently before archiving.

## 5. Verification

- [x] 5.1 Run Dart formatting for changed Dart files and tests.
- [x] 5.2 Run static analysis.
- [x] 5.3 Run the full test suite.
- [x] 5.4 Run strict OpenSpec validation for `separate-pipeline-and-retry-attempt-contexts`.
