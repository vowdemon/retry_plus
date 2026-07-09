# behavior-test-parity Specification

## Purpose
TBD - created by archiving change test-parity-behavior-suite. Update Purpose after archive.
## Requirements
### Requirement: Plan behavior parity tests by capability
The project SHALL plan reference-derived behavior tests under the capability that owns the behavior being verified.

#### Scenario: Strategy behavior is owned by strategy spec
- **WHEN** a reference-derived behavior verifies retry, timeout, fallback, circuit breaker, hedging, rate limiter, injection, outcome, predicate, telemetry, or extension behavior
- **THEN** the corresponding capability spec SHALL define the rp behavior to test

#### Scenario: Order-dependent behavior is owned by pipeline spec
- **WHEN** a behavior result depends on strategy order or same-kind strategy nesting
- **THEN** the `retry-pipeline` capability SHALL define the behavior to test

### Requirement: Compare observable behavior instead of API shape
The project SHALL compare rp against the reference suite by observable behavior and capability, not by identical API names, option enums, or implementation structure.

#### Scenario: API shape differs but behavior is expressible
- **WHEN** the reference suite uses a fixed configuration shape and rp expresses the same capability through open predicates, policies, or callbacks
- **THEN** the rp test SHALL assert the equivalent observable behavior through rp APIs

#### Scenario: Reference test is implementation detail only
- **WHEN** a reference test only verifies private helper mechanics without public behavior impact
- **THEN** the rp test plan SHALL omit that test or cover only the public behavior it implies

### Requirement: Record behavior differences
The project SHALL maintain a behavior parity difference report for observable behavior differences between rp and the reference suite.

#### Scenario: Behavior differs from reference
- **WHEN** an rp behavior intentionally or unintentionally differs from the reference behavior
- **THEN** the difference report SHALL record the module, reference behavior, rp behavior, proving test, status, reason, and decision

#### Scenario: Reference behavior cannot be expressed
- **WHEN** a reference behavior cannot be expressed by rp
- **THEN** the difference report SHALL mark the gap as `bug` or `undecided` unless the corresponding spec explicitly defines a different rp behavior

### Requirement: Keep behavior tests module-owned
The test suite SHALL keep module-specific tests in module-specific test files and reserve pipeline tests for composition semantics.

#### Scenario: Module-specific behavior test is added
- **WHEN** a test covers local behavior of one strategy or support module
- **THEN** the test SHALL live in that module's test file or a clearly named support file

#### Scenario: Composition behavior test is added
- **WHEN** a test covers cross-strategy scope, ordering, nesting, or visibility
- **THEN** the test SHALL live in the pipeline behavior tests

