import 'package:clock/clock.dart';

Future<T> withFakeClock<T>(
  FakeClock fakeClock,
  Future<T> Function() body,
) {
  return withClock(Clock(fakeClock.now), body);
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
