import 'package:glados/glados.dart';
import 'package:mizan/core/clock/fake_clock.dart';
import 'package:mizan/core/ids/random_id_generator.dart';
import 'package:mizan/core/ids/uuid_v7_generator.dart';
import 'package:mizan/core/ids/uuid_v7_time.dart';

void main() {
  test('reads back the time a UUIDv7 was made, to the millisecond', () {
    final made = DateTime(2026, 10, 9, 21, 45, 12, 345);
    final id = UuidV7Generator(FakeClock(made)).newId();

    expect(uuidV7Time(id), made);
  });

  test('is in local time', () {
    final id = UuidV7Generator(FakeClock(DateTime.utc(2026, 10, 9))).newId();

    expect(uuidV7Time(id)!.isUtc, isFalse);
  });

  test('ids that are not UUIDv7 give null', () {
    expect(uuidV7Time(const RandomIdGenerator().newId()), isNull);
    expect(uuidV7Time('food'), isNull);
    expect(uuidV7Time('op-1'), isNull);
    expect(uuidV7Time('zzzzzzzz-zzzz-7zzz-8zzz-zzzzzzzzzzzz'), isNull);
  });

  Glados(any.intInRange(0, 1 << 47)).test(
    'any millisecond up to the year 6000 round-trips',
    (millis) {
      final made = DateTime.fromMillisecondsSinceEpoch(millis);
      expect(uuidV7Time(UuidV7Generator(FakeClock(made)).newId()), made);
    },
  );
}
