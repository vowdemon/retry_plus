## Context

`retry_plus` currently exposes `RetryPolicy.execute(Future<T> Function())` for async work and `executeSync(T Function())` for sync work. Both paths ultimately run through the same pipeline, but the public API splits them and returns a plain `Future<T>`.

Cancellation is currently controlled by passing a `CancellationToken` into `execute`. That works, but the returned future does not carry the token or any execution observability. Callers must keep the token separately and cannot inspect the current retry lifecycle phase from the returned value.

The package has not shipped yet, so this change can reshape the API directly before release.

## Goals / Non-Goals

**Goals:**

- Make `execute` and top-level `retry` accept both sync and async operations through `FutureOr<T> Function()`.
- Return `RetryFuture<T>` from execution APIs so one retry run is awaitable and controllable from the same object.
- Give every `RetryFuture<T>` an effective `CancellationToken`.
- Expose `RetryFuture.cancel([reason])` as the direct cancellation method for the run.
- Expose only the current retry lifecycle phase through `RetryFuture.phase`.
- Remove the separate sync execution API.

**Non-Goals:**

- Do not introduce a public `RetryState` object.
- Do not expose attempt counters, outcomes, delays, or elapsed time from `RetryFuture` in this change.
- Do not add stream/listener observability in this change.
- Do not forcefully stop an already running user operation when cancellation is requested.
- Do not keep the old execution API shape.

## Decisions

### `execute` accepts `FutureOr<T> Function()`

`RetryPolicy.execute`, `RetryPipeline.execute`, and top-level `retry` will accept `FutureOr<T> Function()` operations. Internally, each attempt should adapt the operation with `Future.sync` or equivalent behavior so synchronous return values and synchronous throws enter the same async retry pipeline as `Future` results and errors.

Alternative considered: keep `executeSync`. That leaves an artificial API split before release. Since the package has not shipped, removing the split is simpler.

### Execution APIs return `RetryFuture<T>`

`RetryFuture<T>` will implement `Future<T>` and delegate all future behavior to the underlying execution future. This keeps existing await/then/catchError ergonomics while adding retry-specific control and observability.

The public shape should stay narrow:

```dart
abstract interface class RetryFuture<T> implements Future<T> {
  CancellationToken get cancelToken;
  RetryPhase get phase;

  void cancel([Object? reason]);
}
```

Alternative considered: return a separate operation object with a `.future` property. That makes control explicit but makes simple calls noisier. Making `RetryFuture<T>` future-compatible keeps the primary use case simple: `await policy.execute(...)`.

### `RetryPhase` is the only public execution state

The change will expose a `RetryPhase` enum instead of a `RetryState` abstraction. The phase communicates the lifecycle state without committing the public API to internal retry metadata.

Suggested phases:

```dart
enum RetryPhase {
  pending,
  attempting,
  waiting,
  completed,
  failed,
  cancelled,
}
```

Phase transitions are owned by the execution engine:

```text
pending
  |
  v
attempting
  |-- success ------------> completed
  |-- non-cancel failure -> failed
  |-- cancellation -------> cancelled
  `-- retryable outcome --> waiting --> attempting
```

Alternative considered: expose `RetryState` with attempt metadata. That provides more observability, but it expands the public contract prematurely. The current requirement is lifecycle visibility and control, so phase is enough.

### `PipelineContext` owns phase and token state

Every execution has one effective `CancellationToken`, exposed as `RetryFuture.cancelToken`. When the caller passes a token, the execution uses that token. When the caller omits one, the pipeline creates a token for that execution. `RetryFuture.cancel([reason])` delegates to the effective token.

`PipelineContext<T>` stores the current `RetryPhase` and effective token because it already represents one pipeline execution and is shared through all strategies. The concrete `RetryFuture<T>` should read `phase` and `cancelToken` from the context and delegate `Future<T>` methods to the underlying execution future.

Alternative considered: use a separate `RetryFutureController`. That adds another mutable object with the same lifetime as `PipelineContext<T>`. Storing phase and token on the context keeps per-execution state in one place.

## Risks / Trade-offs

- **Risk: Implementing `Future<T>` manually can miss `Future` contract details.** -> Mitigate by delegating every method to an internal `Future<T>` and covering `await`, `then`, `catchError`, `whenComplete`, `asStream`, and `timeout` in tests.
- **Risk: Phase reads are live and can change between microtasks.** -> Document `phase` as current best-effort lifecycle state, not a historical event log.
- **Risk: Cancellation may be misread as forceful interruption.** -> Keep existing cooperative cancellation semantics and document that running user operations are not force-stopped.
- **Risk: Removing `executeSync` is breaking.** -> Accept this because the package has not shipped; update examples and tests in the same change.
