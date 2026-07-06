import 'dart:async';

import 'package:retry_plus/retry_plus.dart';

final class FakeRuntime {
  FakeRuntime({
    DateTime? now,
    List<TimeoutScope> timeoutScopesToThrow = const [],
  }) : clock = FakeClock(now ?? DateTime(2026)),
       _timeoutScopesToThrow = List<TimeoutScope>.of(timeoutScopesToThrow);

  final FakeClock clock;
  final delays = <Duration>[];
  final timeouts = <TimeoutScope>[];
  final List<TimeoutScope> _timeoutScopesToThrow;

  RetryRuntime get value {
    return RetryRuntime(
      clock: clock.now,
      sleeper: sleep,
      timeout: timeout,
      random: SequenceRandom([0.5]).nextDouble,
    );
  }

  Future<void> sleep(Duration delay, CancellationToken? token) async {
    token?.throwIfCancelled();
    delays.add(delay);
    clock.advance(delay);
    token?.throwIfCancelled();
  }

  Future<T> timeout<T>(
    Future<T> future,
    Duration duration,
    TimeoutScope scope,
    CancellationToken? token,
  ) async {
    token?.throwIfCancelled();
    timeouts.add(scope);
    if (_timeoutScopesToThrow.isNotEmpty &&
        _timeoutScopesToThrow.removeAt(0) == scope) {
      throw RetryTimeoutException(scope);
    }
    return future;
  }

  Future<T> timeoutOperation<T>() {
    return Future<T>.error(
      const RetryTimeoutException(TimeoutScope.perAttempt),
    );
  }
}

final class FakeClock {
  FakeClock(this._now);

  DateTime _now;

  DateTime now() => _now;

  void advance(Duration duration) {
    _now = _now.add(duration);
  }
}

final class SequenceRandom {
  SequenceRandom(this._values);

  final List<double> _values;
  var _index = 0;

  double nextDouble() {
    final value = _values[_index % _values.length];
    _index++;
    return value;
  }
}
