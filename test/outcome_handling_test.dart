import 'dart:async';

import 'package:retry_plus/retry_plus.dart';
import 'package:test/test.dart' hide Retry;

void main() {
  group('StrategyOutcome', () {
    test('represents typed result outcomes', () {
      final context =
          RetryPipelineContext<int>(elapsed: const Duration(seconds: 2));

      final outcome = StrategyOutcome<int>.result(
        7,
        context: context,
      );

      expect(outcome.context, same(context));
      expect(outcome.elapsed, const Duration(seconds: 2));
      expect(
        switch (outcome) {
          StrategyOutcomeResult<int>(:final result) => result,
          StrategyOutcomeError<int>() => fail('expected result outcome'),
        },
        7,
      );
    });

    test('represents exception outcomes with stack traces', () {
      final context = RetryPipelineContext<int>();
      final error = StateError('failed');
      final stackTrace = StackTrace.current;

      final outcome = StrategyOutcome<int>.error(
        error,
        stackTrace,
        context: context,
      );

      expect(outcome.context, same(context));
      switch (outcome) {
        case StrategyOutcomeResult<int>():
          fail('expected error outcome');
        case StrategyOutcomeError<int>(
            error: final actualError,
            stackTrace: final actualStackTrace,
          ):
          expect(actualError, same(error));
          expect(actualStackTrace, same(stackTrace));
      }
    });

    test('exposes strategy metadata', () {
      final context = RetryPipelineContext<int>();

      final outcome = StrategyOutcome<int>.result(
        7,
        context: context,
        metadata: {'attemptNumber': 3, 'strategy': 'retry'},
      );

      expect(outcome.metadata['attemptNumber'], 3);
      expect(outcome.metadata['strategy'], 'retry');
    });
  });

  group('OutcomePredicate', () {
    test('supports synchronous and asynchronous callbacks', () async {
      final context = RetryPipelineContext<int>();
      final outcome = StrategyOutcome<int>.result(7, context: context);

      final sync = OutcomePredicate<int>.where(
        (outcome) => outcome is StrategyOutcomeResult<int>,
      );
      final async = OutcomePredicate<int>.where((outcome) async {
        await Future<void>.delayed(Duration.zero);
        return outcome is StrategyOutcomeResult<int>;
      });

      expect(await sync.shouldHandle(outcome), isTrue);
      expect(await async.shouldHandle(outcome), isTrue);
    });

    test('matches result and exception outcomes', () async {
      final context = RetryPipelineContext<int>();
      final result = StrategyOutcome<int>.result(7, context: context);
      final error = StrategyOutcome<int>.error(
        StateError('failed'),
        StackTrace.current,
        context: context,
      );

      expect(
        await OutcomePredicate<int>.result((value) => value == 7)
            .shouldHandle(result),
        isTrue,
      );
      expect(
        await OutcomePredicate.exceptionType<StateError, int>()
            .shouldHandle(error),
        isTrue,
      );
      expect(
        await OutcomePredicate<int>.result((value) => value == 7)
            .shouldHandle(error),
        isFalse,
      );
    });

    test('default broad predicates exclude cancellation outcomes', () async {
      final context = RetryPipelineContext<int>();
      final cancellation = StrategyOutcome<int>.error(
        const RetryCancelledException('stopped'),
        StackTrace.current,
        context: context,
      );

      expect(await OutcomePredicate<int>.any().shouldHandle(cancellation),
          isFalse);
      expect(
        await OutcomePredicate<int>.exception().shouldHandle(cancellation),
        isFalse,
      );
    });

    test('composes with OR AND and NOT', () async {
      final context = RetryPipelineContext<int>();
      final result = StrategyOutcome<int>.result(7, context: context);

      final isSeven = OutcomePredicate<int>.result((value) => value == 7);
      final isPositive = OutcomePredicate<int>.result((value) => value > 0);
      final isNegative = OutcomePredicate<int>.result((value) => value < 0);

      expect(await (isSeven & isPositive).shouldHandle(result), isTrue);
      expect(await (isSeven & isNegative).shouldHandle(result), isFalse);
      expect(await (isNegative | isSeven).shouldHandle(result), isTrue);
      expect(await (~isNegative).shouldHandle(result), isTrue);
    });
  });

  group('OutcomeContext', () {
    test('shared helpers expose result and error metadata', () {
      final resultContext = _OutcomeTestContext<int>(
        outcome: StrategyOutcome<int>.result(7,
            context: RetryPipelineContext<int>()),
        pipelineContext: RetryPipelineContext<int>(),
        elapsed: const Duration(milliseconds: 2),
      );
      final error = StateError('failed');
      final stackTrace = StackTrace.current;
      final errorContext = _OutcomeTestContext<int>(
        outcome: StrategyOutcome<int>.error(
          error,
          stackTrace,
          context: RetryPipelineContext<int>(),
        ),
        pipelineContext: RetryPipelineContext<int>(),
        elapsed: const Duration(milliseconds: 3),
      );

      expect(resultContext.result, 7);
      expect(resultContext.hasResult, isTrue);
      expect(resultContext.error, isNull);
      expect(resultContext.stackTrace, isNull);
      expect(errorContext.error, same(error));
      expect(errorContext.stackTrace, same(stackTrace));
      expect(errorContext.hasError, isTrue);
      expect(errorContext.result, isNull);
    });
  });

  group('ContextPredicate', () {
    test('shares OR AND and NOT composition for async predicates', () async {
      final isEven = _IntPredicate((value) => value.isEven);
      final isThree = _IntPredicate((value) async {
        await Future<void>.delayed(Duration.zero);
        return value == 3;
      });

      expect(await (isEven | isThree).shouldHandle(3), isTrue);
      expect(await (isEven & isThree).shouldHandle(3), isFalse);
      expect(await (~isEven).shouldHandle(3), isTrue);
    });
  });
}

final class _OutcomeTestContext<T> implements OutcomeContext<T> {
  const _OutcomeTestContext({
    required this.outcome,
    required this.pipelineContext,
    required this.elapsed,
  });

  @override
  final StrategyOutcome<T> outcome;

  @override
  final RetryPipelineContext<T> pipelineContext;

  @override
  final Duration elapsed;
}

final class _IntPredicate extends ContextPredicate<int, _IntPredicate> {
  const _IntPredicate(this._callback);

  final FutureOr<bool> Function(int value) _callback;

  @override
  FutureOr<bool> shouldHandle(int context) => _callback(context);

  @override
  _IntPredicate build(FutureOr<bool> Function(int context) shouldHandle) {
    return _IntPredicate(shouldHandle);
  }
}
