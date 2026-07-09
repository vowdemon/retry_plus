## ADDED Requirements

### Requirement: Cover outcome behavior parity
The outcome test suite SHALL cover result/error representation, metadata, cancellation exclusion, and predicate behavior required by strategy tests.

#### Scenario: Outcome represents result and error
- **WHEN** strategy execution produces a result or error
- **THEN** tests SHALL prove outcome exposes the correct typed value, error, stack trace, and availability rules

#### Scenario: Outcome metadata is available to predicates
- **WHEN** a strategy predicate receives outcome context
- **THEN** tests SHALL prove elapsed time, attempt-independent pipeline context, and strategy-provided metadata are readable through public helpers

#### Scenario: Cancellation is excluded by defaults
- **WHEN** a default broad outcome predicate receives cancellation
- **THEN** tests SHALL prove cancellation is not treated as a handled outcome

#### Scenario: Outcome predicates can be asynchronous
- **WHEN** an outcome predicate returns a future
- **THEN** tests SHALL prove strategy handling awaits the predicate and preserves boolean semantics
