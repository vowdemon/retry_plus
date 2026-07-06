## Purpose

Defines explicit runtime dependencies used by retry pipeline strategies for deterministic execution and observation.

## Requirements

### Requirement: Provide runtime dependency object
The package SHALL provide a runtime dependency object used by pipeline and strategies for time, sleeping, randomness, scheduling, and observation.

#### Scenario: Runtime is passed through pipeline context
- **WHEN** a pipeline execution starts
- **THEN** all strategies use the same runtime dependency object from the execution context

### Requirement: Support deterministic time and delay tests
Runtime dependencies SHALL allow tests to control clock and sleep behavior without real waiting.

#### Scenario: Fake runtime advances elapsed time
- **WHEN** tests use a fake clock and fake sleeper
- **THEN** retry delay, timeout, and circuit recovery behavior can be verified without waiting for wall-clock time

### Requirement: Support deterministic randomness
Runtime dependencies SHALL allow tests to control random values used by jitter and random delay strategies.

#### Scenario: Fake random produces expected jitter
- **WHEN** tests use a deterministic random source
- **THEN** computed jitter and random delay values are predictable

### Requirement: Avoid general-purpose dependency injection
Runtime dependencies SHALL remain explicit library infrastructure and MUST NOT introduce a global container, service locator, reflection, code generation, or framework integration.

#### Scenario: Runtime is configured explicitly
- **WHEN** a caller needs custom runtime behavior
- **THEN** the caller passes a runtime object or explicit runtime fields to the policy or pipeline
