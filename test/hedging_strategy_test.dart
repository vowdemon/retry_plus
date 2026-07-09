import 'dart:async';

import 'package:retry_plus/retry_plus.dart';
import 'package:test/test.dart' hide Retry;

void main() {
  group('hedging strategy', () {
    test('starts a hedged action after delay while primary is running',
        () async {
      final first = Completer<int>();
      final second = Completer<int>();
      var starts = 0;
      final pipeline = RetryPipeline<int>(
        strategies: [
          HedgingStrategy<int>(
            delay: const Duration(milliseconds: 1),
            maxHedgedAttempts: 1,
          ),
        ],
      );

      final run = pipeline.execute(() {
        starts++;
        return starts == 1 ? first.future : second.future;
      });

      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(starts, 2);
      second.complete(2);
      expect(await run, 2);
    });

    test('returns first acceptable hedged result', () async {
      final first = Completer<int>();
      var starts = 0;
      final pipeline = RetryPipeline<int>(
        strategies: [
          HedgingStrategy<int>(
            delay: Duration.zero,
            maxHedgedAttempts: 1,
          ),
        ],
      );

      final result = await pipeline.execute(() {
        starts++;
        return starts == 1 ? first.future : Future<int>.value(2);
      });

      expect(result, 2);
      expect(starts, 2);
    });

    test('zero delay starts all allowed hedged actions', () async {
      final completers = [Completer<int>(), Completer<int>(), Completer<int>()];
      var starts = 0;
      final pipeline = RetryPipeline<int>(
        strategies: [
          HedgingStrategy<int>(
            delay: Duration.zero,
            maxHedgedAttempts: 2,
          ),
        ],
      );

      final run = pipeline.execute(() => completers[starts++].future);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(starts, 3);
      completers.last.complete(3);
      expect(await run, 3);
    });

    test('effectively infinite delay does not start concurrent hedge',
        () async {
      var starts = 0;
      final pipeline = RetryPipeline<int>(
        strategies: [
          HedgingStrategy<int>(
            delay: const Duration(days: 1),
            maxHedgedAttempts: 1,
          ),
        ],
      );

      final result = await pipeline.execute(() {
        starts++;
        return 1;
      });

      expect(result, 1);
      expect(starts, 1);
    });

    test('handled outcome does not win while hedge capacity remains', () async {
      var starts = 0;
      final pipeline = RetryPipeline<int>(
        strategies: [
          HedgingStrategy<int>(
            delay: const Duration(days: 1),
            maxHedgedAttempts: 1,
            hedgeIf: HedgingPredicate<int>.result((value) => value == 0),
          ),
        ],
      );

      final result = await pipeline.execute(() {
        starts++;
        return starts == 1 ? 0 : 1;
      });

      expect(result, 1);
      expect(starts, 2);
    });

    test('last handled outcome is returned when hedge capacity is exhausted',
        () async {
      var starts = 0;
      final pipeline = RetryPipeline<int>(
        strategies: [
          HedgingStrategy<int>(
            delay: Duration.zero,
            maxHedgedAttempts: 1,
            hedgeIf: HedgingPredicate<int>.result((value) => value < 10),
          ),
        ],
      );

      final result = await pipeline.execute(() {
        starts++;
        return starts == 1 ? 0 : 5;
      });

      expect(result, 5);
      expect(starts, 2);
    });

    test('explicit hedging any handles result outcomes', () async {
      var starts = 0;
      final pipeline = RetryPipeline<int>(
        strategies: [
          HedgingStrategy<int>(
            delay: const Duration(days: 1),
            maxHedgedAttempts: 1,
            hedgeIf: HedgingPredicate<int>.any(),
          ),
        ],
      );

      final result = await pipeline.execute(() {
        starts++;
        return starts == 1 ? 0 : 1;
      });

      expect(result, 1);
      expect(starts, 2);
    });

    test('hedging predicates compose with shared boolean semantics', () async {
      final context = RetryPipelineContext<int>();
      final outcomeContext = HedgingOutcomeContext<int>(
        outcome: StrategyOutcome<int>.result(7, context: context),
        actionIndex: 0,
        pipelineContext: context,
        observedOutcomes: const [],
      );
      final isSeven = HedgingPredicate<int>.result((value) => value == 7);
      final isPositive = HedgingPredicate<int>.result((value) async {
        await Future<void>.delayed(Duration.zero);
        return value > 0;
      });
      final isNegative = HedgingPredicate<int>.result((value) => value < 0);

      expect(await (isSeven & isPositive).shouldHandle(outcomeContext), isTrue);
      expect(
        await (isSeven & isNegative).shouldHandle(outcomeContext),
        isFalse,
      );
      expect(await (isNegative | isSeven).shouldHandle(outcomeContext), isTrue);
      expect(await (~isNegative).shouldHandle(outcomeContext), isTrue);
      expect(outcomeContext.result, 7);
      expect(outcomeContext.elapsed, Duration.zero);
    });

    test('generated delay can disable hedging', () async {
      var starts = 0;
      final pipeline = RetryPipeline<int>(
        strategies: [
          HedgingStrategy<int>(
            maxHedgedAttempts: 1,
            delayGenerator: (context) => null,
          ),
        ],
      );

      final result = await pipeline.execute(() {
        starts++;
        return 1;
      });

      expect(result, 1);
      expect(starts, 1);
    });

    test('custom action generator supplies hedged action', () async {
      final primary = Completer<int>();
      final pipeline = RetryPipeline<int>(
        strategies: [
          HedgingStrategy<int>(
            delay: Duration.zero,
            maxHedgedAttempts: 1,
            actionGenerator: (context) {
              expect(context.actionIndex, 1);
              return (_) async => 7;
            },
          ),
        ],
      );

      final result = await pipeline.execute(() => primary.future);

      expect(result, 7);
    });

    test('custom action generator can skip hedged action', () async {
      var starts = 0;
      final pipeline = RetryPipeline<int>(
        strategies: [
          HedgingStrategy<int>(
            delay: Duration.zero,
            maxHedgedAttempts: 1,
            actionGenerator: (_) => null,
          ),
        ],
      );

      final result = await pipeline.execute(() {
        starts++;
        return 1;
      });

      expect(result, 1);
      expect(starts, 1);
    });

    test('custom action generator failure becomes a hedged outcome', () async {
      final error = StateError('generator failed');
      final outcomes = <Object?>[];
      final pipeline = RetryPipeline<int>(
        strategies: [
          HedgingStrategy<int>(
            delay: Duration.zero,
            maxHedgedAttempts: 1,
            hedgeIf: HedgingPredicate<int>.never(),
            onOutcome: (context) {
              outcomes.add(context.failure);
            },
            actionGenerator: (_) => throw error,
          ),
        ],
      );

      await expectLater(
        pipeline.execute(() => Completer<int>().future),
        throwsA(same(error)),
      );
      expect(outcomes, hasLength(1));
      expect(outcomes.single, same(error));
    });

    test('winner signals cancellation to losing custom hedged action',
        () async {
      final primary = Completer<int>();
      final hedgeStarted = Completer<void>();
      CancellationToken? hedgeToken;
      final pipeline = RetryPipeline<int>(
        strategies: [
          HedgingStrategy<int>(
            delay: Duration.zero,
            maxHedgedAttempts: 1,
            actionGenerator: (context) {
              hedgeToken = context.cancellationToken;
              return (context) {
                hedgeStarted.complete();
                return Completer<int>().future;
              };
            },
          ),
        ],
      );

      final run = pipeline.execute(() => primary.future);
      await hedgeStarted.future;
      primary.complete(1);

      expect(await run, 1);
      expect(hedgeToken?.isCancelled, isTrue);
    });

    test('caller cancellation cancels running hedged actions', () async {
      final primary = Completer<int>();
      final hedgeStarted = Completer<void>();
      CancellationToken? hedgeToken;
      final pipeline = RetryPipeline<int>(
        strategies: [
          HedgingStrategy<int>(
            delay: Duration.zero,
            maxHedgedAttempts: 1,
            actionGenerator: (context) {
              hedgeToken = context.cancellationToken;
              return (_) {
                hedgeStarted.complete();
                return Completer<int>().future;
              };
            },
          ),
        ],
      );

      final run = pipeline.execute(() => primary.future);
      await hedgeStarted.future;
      run.cancel(const RetryCancelledException('stopped'));

      await expectLater(run, throwsA(isA<RetryCancelledException>()));
      expect(hedgeToken?.isCancelled, isTrue);
    });

    test('emits hedging hooks and pipeline events', () async {
      final hookIndexes = <int>[];
      final selectedIndexes = <int>[];
      final eventTypes = <TelemetryEventType>[];
      final pipeline = RetryPipeline<int>(
        telemetry: TelemetryOptions(
          listeners: [
            CallbackTelemetryListener((event) => eventTypes.add(event.type)),
          ],
        ),
        strategies: [
          HedgingStrategy<int>(
            delay: Duration.zero,
            maxHedgedAttempts: 1,
            onHedge: (context) {
              hookIndexes.add(context.actionIndex);
            },
            onSelected: (context) {
              selectedIndexes.add(context.actionIndex);
            },
          ),
        ],
      );
      var starts = 0;
      final primary = Completer<int>();

      final result = await pipeline.execute(() {
        starts++;
        return starts == 1 ? primary.future : Future<int>.value(2);
      });

      expect(result, 2);
      expect(hookIndexes, [1]);
      expect(selectedIndexes, [1]);
      expect(eventTypes, contains(TelemetryEventType.hedgingScheduled));
      expect(eventTypes, contains(TelemetryEventType.hedgingOutcome));
      expect(eventTypes, contains(TelemetryEventType.hedgingSelected));
    });

    test('hedging hook failure propagates', () async {
      final error = StateError('hook failed');
      final pipeline = RetryPipeline<int>(
        strategies: [
          HedgingStrategy<int>(
            delay: Duration.zero,
            maxHedgedAttempts: 1,
            onHedge: (_) => throw error,
          ),
        ],
      );

      await expectLater(
        pipeline.execute(() => Completer<int>().future),
        throwsA(same(error)),
      );
    });
  });
}
