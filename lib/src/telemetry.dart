import 'dart:async';

import 'outcome.dart';

/// Type of telemetry event emitted by retry_plus.
extension type const TelemetryEventType(String name) {
  /// Pipeline execution started.
  static const pipelineStarted = TelemetryEventType('pipeline.started');

  /// Pipeline execution completed successfully.
  static const pipelineSucceeded = TelemetryEventType('pipeline.succeeded');

  /// Pipeline execution failed.
  static const pipelineFailed = TelemetryEventType('pipeline.failed');

  /// Pipeline execution was cancelled.
  static const pipelineCancelled = TelemetryEventType('pipeline.cancelled');

  /// A retry attempt completed.
  static const retryAttempt = TelemetryEventType('retry.attempt');

  /// A retry will be scheduled.
  static const retryScheduled = TelemetryEventType('retry.scheduled');

  /// Retry gave up.
  static const retryGiveUp = TelemetryEventType('retry.give_up');

  /// Fallback handling started.
  static const fallbackHandling = TelemetryEventType('fallback.handling');

  /// Fallback produced a result.
  static const fallbackApplied = TelemetryEventType('fallback.applied');

  /// Fallback callback failed.
  static const fallbackFailed = TelemetryEventType('fallback.failed');

  /// Timeout occurred.
  static const timeoutTimedOut = TelemetryEventType('timeout.timed_out');

  /// Circuit breaker opened.
  static const circuitOpened = TelemetryEventType('circuit.opened');

  /// Circuit breaker moved to half-open.
  static const circuitHalfOpened = TelemetryEventType('circuit.half_opened');

  /// Circuit breaker closed.
  static const circuitClosed = TelemetryEventType('circuit.closed');

  /// Circuit breaker rejected execution.
  static const circuitRejected = TelemetryEventType('circuit.rejected');

  /// Rate limiter rejected execution.
  static const rateLimiterRejected =
      TelemetryEventType('rate_limiter.rejected');

  /// A hedged action was scheduled.
  static const hedgingScheduled = TelemetryEventType('hedging.scheduled');

  /// A hedged action produced an outcome.
  static const hedgingOutcome = TelemetryEventType('hedging.outcome');

  /// A hedging outcome was selected.
  static const hedgingSelected = TelemetryEventType('hedging.selected');

  /// A throw injection was triggered.
  static const injectionThrow = TelemetryEventType('injection.throw');

  /// A delay injection was triggered.
  static const injectionDelay = TelemetryEventType('injection.delay');

  /// A result injection was triggered.
  static const injectionResult = TelemetryEventType('injection.result');

  /// A behavior injection was triggered.
  static const injectionBehavior = TelemetryEventType('injection.behavior');
}

/// Severity assigned to telemetry events.
enum TelemetrySeverity {
  /// Verbose diagnostic event.
  trace,

  /// Debug diagnostic event.
  debug,

  /// Informational event.
  information,

  /// Warning event.
  warning,

  /// Error event.
  error,

  /// Critical event.
  critical,

  /// Suppresses the event.
  none,
}

/// Identifies where telemetry originated.
final class TelemetrySource {
  /// Creates a telemetry source.
  const TelemetrySource({
    this.pipelineKey,
    this.operationKey,
    this.strategyName,
  });

  /// Stable key for the pipeline configuration that emitted this event.
  final String? pipelineKey;

  /// Operation key for the current execution.
  final String? operationKey;

  /// Strategy instance name that emitted this event, when applicable.
  final String? strategyName;

  /// Returns a copy with selected source fields replaced.
  TelemetrySource copyWith({
    String? pipelineKey,
    String? operationKey,
    String? strategyName,
  }) {
    return TelemetrySource(
      pipelineKey: pipelineKey ?? this.pipelineKey,
      operationKey: operationKey ?? this.operationKey,
      strategyName: strategyName ?? this.strategyName,
    );
  }
}

/// Structured telemetry event emitted by pipeline execution and strategies.
final class TelemetryEvent<T> {
  /// Creates a telemetry event.
  const TelemetryEvent({
    required this.type,
    required this.source,
    required this.severity,
    required this.timestamp,
    required this.elapsed,
    this.duration,
    this.outcome,
    this.error,
    this.stackTrace,
    this.attributes = const <String, Object?>{},
  });

  /// Event type.
  final TelemetryEventType type;

  /// Event source.
  final TelemetrySource source;

  /// Event severity.
  final TelemetrySeverity severity;

  /// Time the event was emitted.
  final DateTime timestamp;

  /// Elapsed execution time when the event was emitted.
  final Duration elapsed;

  /// Duration associated with the event.
  final Duration? duration;

  /// Outcome associated with the event.
  final StrategyOutcome<T>? outcome;

  /// Error associated with the event.
  final Object? error;

  /// Stack trace associated with [error].
  final StackTrace? stackTrace;

  /// Event-specific structured attributes.
  final Map<String, Object?> attributes;

  /// Returns a copy with changed severity.
  TelemetryEvent<T> withSeverity(TelemetrySeverity severity) {
    return TelemetryEvent<T>(
      type: type,
      source: source,
      severity: severity,
      timestamp: timestamp,
      elapsed: elapsed,
      duration: duration,
      outcome: outcome,
      error: error,
      stackTrace: stackTrace,
      attributes: attributes,
    );
  }
}

/// Callback that can change or suppress telemetry event severity.
typedef TelemetrySeverityProvider = TelemetrySeverity Function(
  TelemetryEvent<Object?> event,
);

/// Listener that consumes telemetry events.
abstract interface class TelemetryListener {
  /// Handles a telemetry [event].
  FutureOr<void> onTelemetry<T>(TelemetryEvent<T> event);
}

/// Listener backed by a callback.
final class CallbackTelemetryListener implements TelemetryListener {
  /// Creates a callback telemetry listener.
  const CallbackTelemetryListener(this.callback);

  /// Callback invoked for every event.
  final FutureOr<void> Function(TelemetryEvent<Object?> event) callback;

  @override
  FutureOr<void> onTelemetry<T>(TelemetryEvent<T> event) {
    return callback(event);
  }
}

/// Test-friendly listener that stores received events.
final class InMemoryTelemetryListener implements TelemetryListener {
  /// Creates an in-memory listener.
  InMemoryTelemetryListener();

  final _events = <TelemetryEvent<Object?>>[];

  /// Events received so far.
  List<TelemetryEvent<Object?>> get events => List.unmodifiable(_events);

  @override
  void onTelemetry<T>(TelemetryEvent<T> event) {
    _events.add(event);
  }
}

/// Telemetry configuration.
final class TelemetryOptions {
  /// Creates telemetry options.
  const TelemetryOptions({
    this.listeners = const <TelemetryListener>[],
    this.severityProvider,
  });

  /// Telemetry listeners.
  final List<TelemetryListener> listeners;

  /// Optional severity override and suppression callback.
  final TelemetrySeverityProvider? severityProvider;
}

/// Returns the default severity for [event].
TelemetrySeverity defaultTelemetrySeverity(TelemetryEvent<Object?> event) {
  return switch (event.type) {
    TelemetryEventType.pipelineStarted => TelemetrySeverity.debug,
    TelemetryEventType.pipelineSucceeded => TelemetrySeverity.information,
    TelemetryEventType.pipelineFailed => TelemetrySeverity.error,
    TelemetryEventType.pipelineCancelled => TelemetrySeverity.warning,
    TelemetryEventType.retryAttempt => event.attributes['handled'] == true
        ? TelemetrySeverity.warning
        : TelemetrySeverity.information,
    TelemetryEventType.retryScheduled => TelemetrySeverity.warning,
    TelemetryEventType.retryGiveUp =>
      event.error == null ? TelemetrySeverity.warning : TelemetrySeverity.error,
    TelemetryEventType.fallbackHandling => TelemetrySeverity.warning,
    TelemetryEventType.fallbackApplied => TelemetrySeverity.warning,
    TelemetryEventType.fallbackFailed => TelemetrySeverity.error,
    TelemetryEventType.timeoutTimedOut => TelemetrySeverity.error,
    TelemetryEventType.circuitOpened => TelemetrySeverity.error,
    TelemetryEventType.circuitHalfOpened => TelemetrySeverity.warning,
    TelemetryEventType.circuitClosed => TelemetrySeverity.information,
    TelemetryEventType.circuitRejected => TelemetrySeverity.error,
    TelemetryEventType.rateLimiterRejected => TelemetrySeverity.warning,
    TelemetryEventType.hedgingScheduled => TelemetrySeverity.warning,
    TelemetryEventType.hedgingOutcome => event.error == null
        ? TelemetrySeverity.information
        : TelemetrySeverity.warning,
    TelemetryEventType.hedgingSelected => TelemetrySeverity.information,
    _ => TelemetrySeverity.information
  };
}

/// Emits telemetry events to configured listeners.
final class TelemetrySink {
  /// Creates a telemetry sink.
  TelemetrySink({
    required this.options,
    required this.source,
    required this.startedAt,
    required DateTime Function() now,
  }) : _now = now;

  /// Telemetry options.
  final TelemetryOptions options;

  /// Base telemetry source for this execution.
  final TelemetrySource source;

  /// Execution start timestamp.
  final DateTime startedAt;

  final DateTime Function() _now;

  /// Emits a telemetry event to all listeners.
  Future<void> emit<T>({
    required TelemetryEventType type,
    Duration? duration,
    StrategyOutcome<T>? outcome,
    Object? error,
    StackTrace? stackTrace,
    String? strategyName,
    Map<String, Object?> attributes = const <String, Object?>{},
  }) async {
    if (options.listeners.isEmpty) {
      return;
    }
    final timestamp = _now();
    final event = TelemetryEvent<T>(
      type: type,
      source: strategyName == null
          ? source
          : source.copyWith(strategyName: strategyName),
      severity: TelemetrySeverity.information,
      timestamp: timestamp,
      elapsed: timestamp.difference(startedAt),
      duration: duration,
      outcome: outcome,
      error: error,
      stackTrace: stackTrace,
      attributes: attributes,
    );
    final objectEvent = event as TelemetryEvent<Object?>;
    final severity = options.severityProvider?.call(objectEvent) ??
        defaultTelemetrySeverity(objectEvent);
    if (severity == TelemetrySeverity.none) {
      return;
    }
    final emitted = event.withSeverity(severity);
    for (final listener in options.listeners) {
      try {
        await listener.onTelemetry<T>(emitted);
      } catch (_) {
        // Telemetry must not affect resilience behavior.
      }
    }
  }
}
