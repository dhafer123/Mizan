import 'clock.dart';

/// A [Clock] that only moves when told to. For unit, widget and integration
/// tests.
final class FakeClock implements Clock {
  FakeClock(this._now);

  DateTime _now;

  @override
  DateTime now() => _now;

  void setTo(DateTime time) => _now = time;

  void advance(Duration duration) => _now = _now.add(duration);
}
