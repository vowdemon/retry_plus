## ADDED Requirements

### Requirement: Support custom retry predicates
Retry predicates SHALL remain open to caller-defined retry decisions through documented public extension contracts and callback-based factories.

#### Scenario: Custom retry predicate class controls retry decision
- **WHEN** a caller supplies a custom `RetryPredicate<T>` implementation
- **THEN** retry uses that predicate to decide whether an attempt outcome should be retried

#### Scenario: Custom retry predicate callback controls retry decision
- **WHEN** a caller supplies a callback-based retry predicate
- **THEN** retry uses that callback to classify attempt outcomes

### Requirement: Support custom delay strategies
Delay strategies SHALL remain open to caller-defined delay algorithms through documented public extension contracts and callback-based factories.

#### Scenario: Custom delay class computes retry wait
- **WHEN** a caller supplies a custom `DelayStrategy` implementation
- **THEN** retry uses that implementation to compute the next retry delay

#### Scenario: Custom delay callback computes retry wait
- **WHEN** a caller supplies a callback-based delay strategy
- **THEN** retry uses that callback with retry context and deterministic random input

### Requirement: Support custom stop strategies
Stop strategies SHALL remain open to caller-defined stop rules through documented public extension contracts and callback-based factories.

#### Scenario: Custom stop class decides final attempt
- **WHEN** a caller supplies a custom `StopStrategy` implementation
- **THEN** retry uses that implementation to decide whether retrying must stop

#### Scenario: Custom stop callback decides final attempt
- **WHEN** a caller supplies a callback-based stop strategy
- **THEN** retry uses that callback with retry context and next-delay metadata

### Requirement: Support custom jitter algorithms
Jitter SHALL remain open to caller-defined randomization algorithms through documented public extension contracts and callback-based factories.

#### Scenario: Custom jitter class transforms delay
- **WHEN** a caller supplies a custom `Jitter` implementation to a jitter-capable delay strategy
- **THEN** the delay strategy applies that jitter to the computed delay

#### Scenario: Custom jitter callback transforms delay
- **WHEN** a caller supplies a callback-based jitter implementation
- **THEN** the jitter receives the base delay and deterministic random input
