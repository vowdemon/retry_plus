import 'dart:async';
import 'dart:io';

import 'package:retry_plus/retry_plus.dart';
import 'package:test/test.dart';

void main() {
  group('RetryFuture', () {
    test('is awaitable and exposes generated cancellation token', () async {
      final future = RetryPolicy<int>().execute(() async => 42);

      expect(future, isA<RetryFuture<int>>());
      expect(future.cancelToken.isCancelled, isFalse);
      expect(await future, 42);
      expect(future.phase, RetryPhase.completed);
    });

    test('exposes provided cancellation token', () async {
      final token = CancellationToken();

      final future = RetryPolicy<int>().execute(
        () async => 42,
        cancellationToken: token,
      );

      expect(identical(future.cancelToken, token), isTrue);
      token.cancel('stopped');
      await expectLater(future, throwsA(isA<RetryCancelledException>()));
      expect(future.phase, RetryPhase.cancelled);
    });

    test('delegates Future methods to the execution future', () async {
      final success = RetryPolicy<int>().execute(() async => 7);
      var whenCompleteCalled = false;

      expect(await success.then((value) => value + 1), 8);
      await success.whenComplete(() {
        whenCompleteCalled = true;
      });
      expect(whenCompleteCalled, isTrue);
      expect(await success.asStream().single, 7);
      expect(await success.timeout(const Duration(seconds: 1)), 7);

      final error = StateError('down');
      final failure = RetryPolicy<int>(
        retryIf: RetryIf<int>.never(),
      ).execute(() async => throw error);

      expect(
        await failure.catchError((Object caught) => 99),
        99,
      );
    });

    test('executes synchronous operations through execute', () async {
      var attempts = 0;
      final result = await RetryPolicy<int>(
        delay: DelayStrategy.none(),
        retryIf: RetryIf<int>.exception() & RetryIf<int>.maxRetries(1),
      ).execute(() {
        attempts++;
        if (attempts == 1) {
          throw const SocketException('offline');
        }
        return 7;
      });

      expect(result, 7);
      expect(attempts, 2);
    });

    test('top-level retry executes synchronous operations', () async {
      var attempts = 0;

      final result = await retry<int>(
        () {
          attempts++;
          if (attempts == 1) {
            throw StateError('try again');
          }
          return 9;
        },
        delay: DelayStrategy.none(),
        retryIf: RetryIf<int>.exception() & RetryIf<int>.maxRetries(1),
      );

      expect(result, 9);
      expect(attempts, 2);
    });

    test('cancel cancels the execution token and completes with cancellation',
        () async {
      late RetryFuture<int> future;
      future = RetryPolicy<int>(
        delay: DelayStrategy.none(),
        retryIf: RetryIf<int>.exception() & RetryIf<int>.maxRetries(1),
        onRetry: (_) {
          future.cancel('stopped');
        },
      ).execute(() async {
        throw const SocketException('offline');
      });

      expect(future.cancelToken.isCancelled, isFalse);
      await expectLater(future, throwsA(isA<RetryCancelledException>()));
      expect(future.cancelToken.isCancelled, isTrue);
      expect(future.phase, RetryPhase.cancelled);
    });

    test('exposes phase while attempting and after completion', () async {
      late RetryFuture<int> future;
      final operationStarted = Completer<void>();
      final finishOperation = Completer<int>();

      future = RetryPolicy<int>().execute(() {
        expect(future.phase, RetryPhase.attempting);
        operationStarted.complete();
        return finishOperation.future;
      });

      expect(future.phase, RetryPhase.pending);
      await operationStarted.future;
      expect(future.phase, RetryPhase.attempting);

      finishOperation.complete(5);
      expect(await future, 5);
      expect(future.phase, RetryPhase.completed);
    });

    test('exposes failed phase after non-cancellation failure', () async {
      final error = StateError('down');
      final future = RetryPolicy<int>(
        retryIf: RetryIf<int>.never(),
      ).execute(() async => throw error);

      await expectLater(future, throwsA(same(error)));
      expect(future.phase, RetryPhase.failed);
    });
  });
}
