import 'package:mizan/core/clock/system_clock.dart';
import 'package:test/test.dart';

void main() {
  test('reads the device time', () {
    final before = DateTime.now();
    final now = const SystemClock().now();
    final after = DateTime.now();

    expect(now.isBefore(before), isFalse);
    expect(now.isAfter(after), isFalse);
  });
}
