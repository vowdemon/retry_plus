## ADDED Requirements

### Requirement: Cover hook and telemetry lifecycle behavior
The hook lifecycle test suite SHALL prove telemetry listeners and side-effect hooks share lifecycle points where appropriate while retaining different failure semantics.

#### Scenario: Event names follow strategy lifecycle
- **WHEN** built-in strategies emit lifecycle telemetry
- **THEN** tests SHALL prove event names follow the `<strategy>.<event>` convention

#### Scenario: Same-kind strategies are distinguishable
- **WHEN** multiple strategies of the same kind emit telemetry in one pipeline
- **THEN** tests SHALL prove strategy names distinguish the event sources

#### Scenario: Telemetry listener failure is isolated
- **WHEN** a telemetry listener throws during a lifecycle point
- **THEN** tests SHALL prove execution and side-effect hooks continue according to telemetry isolation rules

#### Scenario: Side-effect hook failure propagates
- **WHEN** a side-effect hook throws during a lifecycle point
- **THEN** tests SHALL prove the hook failure propagates according to that strategy's hook contract

#### Scenario: Injection hook surface remains minimal
- **WHEN** injection occurs or is skipped
- **THEN** tests SHALL prove injection is observable through telemetry and skipped injection remains silent
