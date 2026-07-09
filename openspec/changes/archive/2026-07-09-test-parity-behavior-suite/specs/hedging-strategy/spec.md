## ADDED Requirements

### Requirement: Cover hedging behavior parity
The hedging test suite SHALL cover hedged execution, winner selection, generated delays/actions, cancellation, hook, and telemetry behavior represented by the reference suite.

#### Scenario: Hedge starts after delay
- **WHEN** the primary action is still pending after hedging delay
- **THEN** tests SHALL prove a hedged action starts according to max attempt limits

#### Scenario: First acceptable outcome wins
- **WHEN** primary and hedged actions race
- **THEN** tests SHALL prove the first acceptable outcome is selected and handled outcomes do not win while another hedge can run

#### Scenario: Hedging delay is computed
- **WHEN** hedging uses generated delay
- **THEN** tests SHALL cover generated durations, disabled hedging, zero delay, and effectively infinite delay behavior

#### Scenario: Hedging action is generated
- **WHEN** hedging uses custom action generation
- **THEN** tests SHALL cover generated action, skipped action, generator failure, and default rerun behavior

#### Scenario: Hedging coordinates cancellation
- **WHEN** an outcome is selected or caller cancellation occurs
- **THEN** tests SHALL prove losing actions are cancelled or cleaned up and caller cancellation reaches all running actions

#### Scenario: Hedging observations are emitted
- **WHEN** hedge is scheduled, an outcome is observed, or an outcome is selected
- **THEN** tests SHALL cover hook arguments, telemetry event data, strategy name, and per-action context behavior
