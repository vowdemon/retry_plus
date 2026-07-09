## ADDED Requirements

### Requirement: Cover public extension behavior parity
The extension-point test suite SHALL prove package users can express custom behavior through public contracts without depending on internal implementations.

#### Scenario: Custom strategy participates in pipeline order
- **WHEN** a caller implements a custom pipeline strategy
- **THEN** tests SHALL prove it receives pipeline context, wraps inner execution in order, and can emit telemetry

#### Scenario: Custom predicates control strategy behavior
- **WHEN** a caller implements custom retry, fallback, circuit, hedging, injection, or outcome predicates
- **THEN** tests SHALL prove the custom predicate controls handling and composes with built-ins

#### Scenario: Custom timing policies control delays
- **WHEN** a caller implements custom delay, timeout, hedging delay, break duration, or jitter behavior
- **THEN** tests SHALL prove the custom timing policy controls observable scheduling without relying on fixed option enums

#### Scenario: Custom infrastructure contracts are testable
- **WHEN** a caller implements custom limiter or telemetry listener behavior
- **THEN** tests SHALL prove the custom implementation can be verified through public APIs and test support
