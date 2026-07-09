## ADDED Requirements

### Requirement: Support token bucket limiter
The package SHALL provide a built-in token bucket limiter that grants leases by consuming tokens from a bounded bucket that refills over time.

#### Scenario: Token is available
- **WHEN** a token bucket limiter has at least one token available
- **THEN** acquiring a lease consumes one token and returns an acquired lease

#### Scenario: Token bucket is empty
- **WHEN** a token bucket limiter has no token available
- **THEN** acquiring a lease returns a rejected lease with `retryAfter` set to the time until the next token can be available

#### Scenario: Token bucket refills over time
- **WHEN** enough time has elapsed for one or more refill periods
- **THEN** later acquisitions can use the refilled tokens

#### Scenario: Token bucket respects capacity
- **WHEN** more refill time elapses than needed to fill the bucket
- **THEN** the bucket stores no more than its configured capacity

### Requirement: Support fixed window limiter
The package SHALL provide a built-in fixed window limiter that allows a configured number of leases per fixed time window.

#### Scenario: Fixed window permit is available
- **WHEN** the current fixed window has remaining permits
- **THEN** acquiring a lease consumes one permit and returns an acquired lease

#### Scenario: Fixed window is exhausted
- **WHEN** the current fixed window has consumed all permits
- **THEN** acquiring a lease returns a rejected lease with `retryAfter` set to the remaining time in the current window

#### Scenario: Fixed window resets
- **WHEN** acquisition occurs after the current fixed window has ended
- **THEN** the limiter starts a new window with the full permit limit available

### Requirement: Support sliding window limiter
The package SHALL provide a built-in sliding window limiter that divides a window into segments and limits acquisitions across the rolling window.

#### Scenario: Sliding window permit is available
- **WHEN** the rolling window has fewer consumed permits than the configured permit limit
- **THEN** acquiring a lease records the acquisition in the current segment and returns an acquired lease

#### Scenario: Sliding window is exhausted
- **WHEN** the rolling window has consumed the configured permit limit
- **THEN** acquiring a lease returns a rejected lease with `retryAfter` set to the time until enough recorded acquisitions expire

#### Scenario: Sliding window drops stale segments
- **WHEN** acquisitions were recorded outside the active rolling window
- **THEN** those stale acquisitions no longer count against the current permit limit

### Requirement: Keep time-based limiters passive
Built-in time-based limiters SHALL update their state during lease acquisition and SHALL NOT require background timers, background workers, or explicit disposal.

#### Scenario: Time advances without acquisition
- **WHEN** time advances while no acquisition is attempted
- **THEN** the limiter performs no background work and applies elapsed time on the next acquisition

#### Scenario: Limiter is shared by multiple strategies
- **WHEN** the same built-in limiter instance is used by multiple rate limiter strategies
- **THEN** the limiter state is shared through that limiter instance and not through the strategies
