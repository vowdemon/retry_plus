## ADDED Requirements

### Requirement: Run retry as a pipeline strategy
Retry behavior SHALL run as a pipeline strategy while preserving the existing `RetryPolicy<T>` and top-level `retry<T>(...)` behavior.

#### Scenario: Existing retry behavior is preserved
- **WHEN** callers use retry-only configuration from the existing public API
- **THEN** the operation behavior remains equivalent after retry execution is moved into the pipeline

#### Scenario: Retry strategy composes with timeout
- **WHEN** retry and per-attempt timeout are configured together
- **THEN** retry treats per-attempt timeout as an attempt outcome that can be retried when the retry predicate matches

### Requirement: Compose stop strategies with AND semantics
Stop strategies SHALL support AND composition in addition to existing OR composition.

#### Scenario: AND stop requires both conditions
- **WHEN** two stop strategies are combined with AND semantics
- **THEN** retrying stops only after both strategies indicate that execution must stop

### Requirement: Negate retry predicates
Retry predicates SHALL support negation so callers can exclude specific retryable conditions from broader retry rules.

#### Scenario: Negated predicate excludes condition
- **WHEN** a broad retry predicate is combined with the negation of a more specific predicate
- **THEN** outcomes matching the negated predicate are not retried

### Requirement: Preserve retry failure semantics inside pipeline
Retry strategy SHALL preserve existing final failure behavior when used inside a pipeline.

#### Scenario: Final retryable exception remains original failure
- **WHEN** retry gives up after a retryable exception and no outer strategy handles it
- **THEN** the final exception is rethrown with the captured stack trace

#### Scenario: Final retryable result remains exhausted failure
- **WHEN** retry gives up after retryable result outcomes and no outer strategy handles it
- **THEN** the pipeline completes with `RetryExhaustedException<T>`
