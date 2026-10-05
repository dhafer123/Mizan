import 'package:mizan/core/clock/fake_clock.dart';
import 'package:test/test.dart';

void main() {
  test('stands still until moved', () {
    final clock = FakeClock(DateTime.utc(2026, 10, 6, 9));

    expect(clock.now(), DateTime.utc(2026, 10, 6, 9));
    expect(clock.now(), DateTime.utc(2026, 10, 6, 9));

    clock.advance(const Duration(days: 1, minutes: 30));
    expect(clock.now(), DateTime.utc(2026, 10, 7, 9, 30));

    clock.setTo(DateTime.utc(2027));
    expect(clock.now(), DateTime.utc(2027));
  });
}
