## Purpose

Defines hedging strategy behavior for racing primary execution with additional actions.
## Requirements
### Requirement: Execute hedged actions
The package SHALL provide a hedging strategy that can execute additional actions concurrently with the primary action to reduce latency or replace handled outcomes.

#### Scenario: Hedge starts after delay
- **WHEN** the primary action has not completed before the configured hedging delay
- **THEN** the hedging strategy starts an additional action without waiting for the primary action to finish

#### Scenario: Maximum hedged attempts is enforced
- **WHEN** the configured maximum number of hedged actions has already been started
- **THEN** the hedging strategy does not start another hedged action

### Requirement: Select first acceptable hedging outcome
The hedging strategy SHALL return the first completed outcome that is not handled by the configured hedging predicate.

#### Scenario: Primary succeeds before hedge
- **WHEN** the primary action completes with an acceptable result before the hedging delay expires
- **THEN** the hedging strategy returns that result and does not start a hedge

#### Scenario: Hedge wins race
- **WHEN** a hedged action completes with an acceptable result before the primary action produces an acceptable outcome
- **THEN** the hedging strategy returns the hedged result

#### Scenario: Handled outcome does not win
- **WHEN** an action completes with an outcome matched by `hedgeIf`
- **THEN** the hedging strategy does not return that handled outcome while additional action capacity remains

### Requirement: Support generated hedging delays
The hedging strategy SHALL support fixed and generated hedging delays using action metadata.

#### Scenario: Delay generator returns duration
- **WHEN** the hedging delay generator returns a duration for the next hedged action
- **THEN** the strategy waits that duration before starting the action unless an acceptable outcome completes first

#### Scenario: Delay generator disables hedging
- **WHEN** the hedging delay generator returns a value indicating no next hedge
- **THEN** the strategy stops scheduling additional hedged actions for that execution

### Requirement: Support generated hedging actions
The hedging strategy SHALL support custom action generation so callers can run the original action or alternate behavior for hedged attempts.

#### Scenario: Default action reruns inner pipeline
- **WHEN** no custom hedging action generator is configured
- **THEN** each hedged action executes the same inner pipeline operation as the primary action

#### Scenario: Custom action generator supplies action
- **WHEN** a custom hedging action generator returns an action for a hedged attempt
- **THEN** the hedging strategy executes that action for the hedged attempt

#### Scenario: Custom action generator skips action
- **WHEN** a custom hedging action generator declines to provide an action
- **THEN** the hedging strategy does not start that hedged attempt

### Requirement: Coordinate hedging cancellation
The hedging strategy SHALL cancel or signal cancellation to losing in-flight actions after an acceptable outcome is selected or caller cancellation occurs.

#### Scenario: Winner cancels losers
- **WHEN** one action wins with an acceptable outcome
- **THEN** the strategy signals cancellation to other in-flight hedged actions where cooperative cancellation is available

#### Scenario: Caller cancellation cancels all actions
- **WHEN** caller cancellation is requested while hedged actions are running
- **THEN** the strategy completes with cancellation and signals cancellation to all in-flight actions

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

