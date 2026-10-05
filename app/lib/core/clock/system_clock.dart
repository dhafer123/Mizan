import 'clock.dart';

/// The device clock. The only place allowed to call `DateTime.now()`.
final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}
