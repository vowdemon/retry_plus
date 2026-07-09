import 'dart:async';

import 'package:retry_plus/retry_plus.dart';
import 'package:test/test.dart' hide Retry;

void main() {
  group('timeout strategy', () {
    test('preserves fast operation result without timeout telemetry', () async {
      final listener = InMemoryTelemetryListener();
      final policy = Retry<int>(
        timeout: TimeoutStrategy(const Duration(seconds: 1)),
        telemetry: TelemetryOptions(listeners: [listener]),
      );

      final result = await policy.execute(() async => 7);

      expect(result, 7);
      expect(
        listener.events.map((event) => event.type),
        isNot(contains(TelemetryEventType.timeoutTimedOut)),
      );
    });

    test('policy applies position-scoped timeout strategy', () async {
      final policy = Retry<int>(
        timeout: TimeoutStrategy(const Duration(milliseconds: 1)),
      );

      await expectLater(
        policy.execute(() => Completer<int>().future),
        throwsA(isA<RetryTimeoutException>()),
      );
    });

    test('generated timeout duration is applied per execution', () async {
      var generated = false;
      final policy = Retry<int>(
        timeout: TimeoutStrategy<int>.generated((context) {
          generated = true;
          return const Duration(milliseconds: 1);
        }),
      );

      await expectLater(
        policy.execute(() => Completer<int>().future),
        throwsA(isA<RetryTimeoutException>()),
      );
      expect(generated, isTrue);
    });

    test('generated null timeout disables timeout for execution', () async {
      final policy = Retry<int>(
        timeout: TimeoutStrategy<int>.generated((context) => null),
      );

      final result = await policy.execute(() async {
        await Future<void>.delayed(const Duration(milliseconds: 2));
        return 7;
      });

      expect(result, 7);
    });

    test('timeout failure reports timeout metadata', () async {
      final listener = InMemoryTelemetryListener();
      final policy = Retry<int>(
        timeout: TimeoutStrategy(
          const Duration(milliseconds: 1),
          name: 'policy-timeout',
        ),
        telemetry: TelemetryOptions(listeners: [listener]),
      );

      final call = policy.execute(() => Completer<int>().future);

      await expectLater(
        call,
        throwsA(
          isA<RetryTimeoutException>().having(
            (error) => error.timeout,
            'timeout',
            const Duration(milliseconds: 1),
          ),
        ),
      );
      final timeoutEvent = listener.events.singleWhere(
        (event) => event.type == TelemetryEventType.timeoutTimedOut,
      );
      expect(
        (timeoutEvent.error as RetryTimeoutException).strategy,
        'policy-timeout',
      );
      expect(
          timeoutEvent.attributes['timeout'], const Duration(milliseconds: 1));
    });

    test('timeout hook runs after timeout telemetry', () async {
      final listener = InMemoryTelemetryListener();
      final hookTimeouts = <Duration>[];
      final policy = Retry<int>(
        timeout: TimeoutStrategy(
          const Duration(milliseconds: 1),
          onTimeout: (context) {
            hookTimeouts.add(context.timeout);
            expect(context.error, isA<RetryTimeoutException>());
          },
        ),
        telemetry: TelemetryOptions(listeners: [listener]),
      );

      await expectLater(
        policy.execute(() => Completer<int>().future),
        throwsA(isA<RetryTimeoutException>()),
      );

      expect(hookTimeouts, [const Duration(milliseconds: 1)]);
      expect(
        listener.events.map((event) => event.type),
        contains(TelemetryEventType.timeoutTimedOut),
      );
    });

    test('cancellation before timeout reports cancellation', () async {
      final token = CancellationToken();
      token.cancel(const RetryCancelledException('stopped'));
      final policy = Retry<int>(
        timeout: TimeoutStrategy(const Duration(seconds: 1)),
      );

      await expectLater(
        policy.execute(() async => 1, cancellationToken: token),
        throwsA(isA<RetryCancelledException>()),
      );
    });

    test('position-scoped timeout preserves cancellation outcome', () async {
      final pipeline = RetryPipeline<int>(
        strategies: [
          TimeoutStrategy<int>(const Duration(milliseconds: 20)),
        ],
      );

      await expectLater(
        pipeline.execute(() async {
          await Future<void>.delayed(Duration.zero);
          throw const RetryCancelledException('stopped');
        }),
        throwsA(isA<RetryCancelledException>()),
      );
    });
  });
}
