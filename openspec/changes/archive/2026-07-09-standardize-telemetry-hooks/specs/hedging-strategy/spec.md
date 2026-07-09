## MODIFIED Requirements

### Requirement: Emit hedging hooks and events
The hedging strategy SHALL expose asynchronous side-effect hooks and telemetry when hedged actions are scheduled, when action outcomes are observed, and when an outcome is selected.

#### Scenario: Hedge scheduled hook runs
- **WHEN** a hedged action is scheduled
- **THEN** telemetry listeners receive `hedging.scheduled` and the strategy invokes the configured hook with action index, delay, context, and currently observed outcomes

#### Scenario: Hedging outcome hook runs
- **WHEN** any hedging action produces an outcome
- **THEN** telemetry listeners receive `hedging.outcome` and the strategy invokes the configured outcome hook with action index, outcome, context, and previously observed outcomes

#### Scenario: Hedging selected hook runs
- **WHEN** a hedging outcome is selected as the final outcome
- **THEN** telemetry listeners receive `hedging.selected` and the strategy invokes the configured selected hook before returning or throwing that selected outcome
