import 'dart:async';

import 'package:retry_plus/retry_plus.dart';
import 'package:test/test.dart' hide Retry;

void main() {
  group('telemetry', () {
    test('fans out events to configured listeners', () async {
      final first = <TelemetryEventType>[];
      final second = <TelemetryEventType>[];
      final pipeline = RetryPipeline<int>(
        telemetry: TelemetryOptions(
          listeners: [
            CallbackTelemetryListener((event) async {
              await Future<void>.delayed(Duration.zero);
              first.add(event.type);
            }),
            CallbackTelemetryListener((event) => second.add(event.type)),
          ],
        ),
      );

      final result = await pipeline.execute(() => 1);

      expect(result, 1);
      expect(first, [
        TelemetryEventType.pipelineStarted,
        TelemetryEventType.pipelineSucceeded,
      ]);
      expect(second, first);
    });

    test('accepts custom const event types', () async {
      const customEvent = TelemetryEventType('custom.audit');
      final listener = InMemoryTelemetryListener();
      final pipeline = RetryPipeline<int>(
        telemetry: TelemetryOptions(listeners: [listener]),
        strategies: const [_CustomTelemetryStrategy<int>(customEvent)],
      );

      final result = await pipeline.execute(() => 1);

      expect(result, 1);
      final event = listener.events.singleWhere(
        (event) => event.type == customEvent,
      );
      expect(event.type.name, 'custom.audit');
      expect(event.severity, TelemetrySeverity.information);
    });

    test('event type exposes stable name', () {
      expect(TelemetryEventType.retryAttempt.name, 'retry.attempt');
    });

    test('captures pipeline operation source fields', () async {
      final listener = InMemoryTelemetryListener();
      var attempts = 0;
      final pipeline = RetryPipeline<int>(
        pipelineKey: 'fetch-user',
        telemetry: TelemetryOptions(listeners: [listener]),
        strategies: [
          RetryStrategy<int>(
            name: 'transient-retry',
            delay: DelayPolicy.none(),
            retryIf: RetryIf<int>.exception() & RetryIf<int>.maxRetries(1),
          ),
        ],
      );

      final result = await pipeline.execute(
        () {
          attempts++;
          if (attempts == 1) {
            throw StateError('transient');
          }
          return 7;
        },
        operationKey: 'GET /users/{id}',
      );

      expect(result, 7);
      final retryEvent = listener.events.singleWhere(
        (event) => event.type == TelemetryEventType.retryScheduled,
      );
      expect(retryEvent.source.pipelineKey, 'fetch-user');
      expect(retryEvent.source.operationKey, 'GET /users/{id}');
      expect(retryEvent.source.strategyName, 'transient-retry');
      expect(retryEvent.attributes['attemptNumber'], 1);
      expect(retryEvent.attributes['retryIndex'], 0);
    });

    test('retry telemetry carries handled flag duration and outcomes',
        () async {
      final listener = InMemoryTelemetryListener();
      var attempts = 0;
      final error = StateError('transient');
      final pipeline = RetryPipeline<int>(
        telemetry: TelemetryOptions(listeners: [listener]),
        strategies: [
          RetryStrategy<int>(
            delay: DelayPolicy.fixed(const Duration(milliseconds: 2)),
            retryIf: RetryIf<int>.exception() & RetryIf<int>.maxRetries(1),
          ),
        ],
      );

      final result = await pipeline.execute(() {
        attempts++;
        if (attempts == 1) {
          throw error;
        }
        return 9;
      });

      expect(result, 9);
      final retryAttempts = listener.events
          .where((event) => event.type == TelemetryEventType.retryAttempt)
          .toList();
      expect(retryAttempts, hasLength(2));
      expect(retryAttempts.first.error, same(error));
      expect(retryAttempts.first.duration, isA<Duration>());
      expect(retryAttempts.first.attributes['handled'], isTrue);
      expect(retryAttempts.first.attributes, isNot(contains('nextDelay')));
      expect(retryAttempts.last.attributes['handled'], isFalse);
      expect(
        switch (retryAttempts.last.outcome) {
          StrategyOutcomeResult<Object?>(:final result) => result,
          StrategyOutcomeError<Object?>() => fail('expected result outcome'),
          null => fail('expected outcome'),
        },
        9,
      );

      final scheduled = listener.events.singleWhere(
        (event) => event.type == TelemetryEventType.retryScheduled,
      );
      expect(
        scheduled.attributes['nextDelay'],
        const Duration(milliseconds: 2),
      );
    });

    test('nested retry telemetry is distinguishable by strategy name',
        () async {
      final listener = InMemoryTelemetryListener();
      var attempts = 0;
      final pipeline = RetryPipeline<int>(
        telemetry: TelemetryOptions(listeners: [listener]),
        strategies: [
          RetryStrategy<int>(
            name: 'outer-retry',
            delay: DelayPolicy.none(),
            retryIf: RetryIf<int>.exception() & RetryIf<int>.maxRetries(1),
          ),
          RetryStrategy<int>(
            name: 'inner-retry',
            delay: DelayPolicy.none(),
            retryIf: RetryIf<int>.exception() & RetryIf<int>.maxRetries(1),
          ),
        ],
      );

      await expectLater(
        pipeline.execute(() {
          attempts++;
          throw StateError('down');
        }),
        throwsA(isA<StateError>()),
      );

      final scheduledNames = listener.events
          .where((event) => event.type == TelemetryEventType.retryScheduled)
          .map((event) => event.source.strategyName)
          .toList();

      expect(attempts, 4);
      expect(
        scheduledNames.where((name) => name == 'inner-retry'),
        hasLength(2),
      );
      expect(
        scheduledNames.where((name) => name == 'outer-retry'),
        hasLength(1),
      );
    });

    test('allows severity override and event suppression', () async {
      final listener = InMemoryTelemetryListener();
      final pipeline = RetryPipeline<int>(
        telemetry: TelemetryOptions(
          listeners: [listener],
          severityProvider: (event) =>
              event.type == TelemetryEventType.pipelineStarted
                  ? TelemetrySeverity.none
                  : TelemetrySeverity.critical,
        ),
      );

      await pipeline.execute(() => 1);

      expect(
        listener.events.map((event) => event.type),
        [TelemetryEventType.pipelineSucceeded],
      );
      expect(listener.events.single.severity, TelemetrySeverity.critical);
    });

    test('listener failures do not affect execution or later listeners',
        () async {
      final received = <TelemetryEventType>[];
      final pipeline = RetryPipeline<int>(
        telemetry: TelemetryOptions(
          listeners: [
            const _ThrowingTelemetryListener(),
            CallbackTelemetryListener((event) => received.add(event.type)),
          ],
        ),
      );

      final result = await pipeline.execute(() => 3);

      expect(result, 3);
      expect(received, [
        TelemetryEventType.pipelineStarted,
        TelemetryEventType.pipelineSucceeded,
      ]);
    });

    test('completed pipeline event carries outcome and duration', () async {
      final listener = InMemoryTelemetryListener();
      final pipeline = RetryPipeline<int>(
        telemetry: TelemetryOptions(listeners: [listener]),
      );

      await pipeline.execute(() => 5);

      final completed = listener.events.singleWhere(
        (event) => event.type == TelemetryEventType.pipelineSucceeded,
      );
      expect(completed.duration, isA<Duration>());
      expect(completed.severity, TelemetrySeverity.information);
      expect(
        switch (completed.outcome) {
          StrategyOutcomeResult<Object?>(:final result) => result,
          StrategyOutcomeError<Object?>() => fail('expected result outcome'),
          null => fail('expected outcome'),
        },
        5,
      );
    });

    test('failed pipeline event carries error stack trace and duration',
        () async {
      final listener = InMemoryTelemetryListener();
      final error = StateError('failed');
      final pipeline = RetryPipeline<int>(
        telemetry: TelemetryOptions(listeners: [listener]),
      );

      await expectLater(
        pipeline.execute(() => throw error),
        throwsA(same(error)),
      );

      final failed = listener.events.singleWhere(
        (event) => event.type == TelemetryEventType.pipelineFailed,
      );
      expect(failed.error, same(error));
      expect(failed.stackTrace, isA<StackTrace>());
      expect(failed.duration, isA<Duration>());
      expect(failed.severity, TelemetrySeverity.error);
      expect(failed.outcome, isA<StrategyOutcomeError<Object?>>());
    });

    test('cancelled pipeline event carries cancellation error and duration',
        () async {
      final listener = InMemoryTelemetryListener();
      final pipeline = RetryPipeline<int>(
        telemetry: TelemetryOptions(listeners: [listener]),
      );

      await expectLater(
        pipeline.execute(
          () => throw const RetryCancelledException('stopped'),
        ),
        throwsA(isA<RetryCancelledException>()),
      );

      final cancelled = listener.events.singleWhere(
        (event) => event.type == TelemetryEventType.pipelineCancelled,
      );
      expect(cancelled.error, isA<RetryCancelledException>());
      expect(cancelled.duration, isA<Duration>());
      expect(cancelled.severity, TelemetrySeverity.warning);
      expect(cancelled.outcome, isA<StrategyOutcomeError<Object?>>());
    });
  });
}

final class _ThrowingTelemetryListener implements TelemetryListener {
  const _ThrowingTelemetryListener();

  @override
  void onTelemetry<T>(TelemetryEvent<T> event) {
    throw StateError('telemetry failed');
  }
}

final class _CustomTelemetryStrategy<T> extends RetryPipelineStrategy<T> {
  const _CustomTelemetryStrategy(this.type) : super(name: 'custom');

  final TelemetryEventType type;

  @override
  Future<T> execute(
      RetryPipelineContext<T> context, Future<T> Function() next) async {
    await context.telemetry?.emit<T>(type: type, strategyName: name);
    return next();
  }
}
