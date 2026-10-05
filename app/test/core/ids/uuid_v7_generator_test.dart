import 'dart:math';

import 'package:mizan/core/clock/fake_clock.dart';
import 'package:mizan/core/ids/uuid_v7_generator.dart';
import 'package:test/test.dart';

void main() {
  final v7 = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );
  final time = DateTime.utc(2026, 10, 6, 9);

  test('produces RFC 9562 version-7 UUIDs', () {
    final ids = UuidV7Generator(FakeClock(time));
    for (var i = 0; i < 100; i++) {
      expect(ids.newId(), matches(v7));
    }
  });

  test('the first 48 bits are the clock time in milliseconds', () {
    final id = UuidV7Generator(FakeClock(time)).newId();
    final millis = int.parse(
      id.replaceAll('-', '').substring(0, 12),
      radix: 16,
    );
    expect(millis, time.millisecondsSinceEpoch);
  });

  test('later clock time sorts later', () {
    final clock = FakeClock(time);
    final ids = UuidV7Generator(clock);
    final first = ids.newId();
    clock.advance(const Duration(milliseconds: 1));
    final second = ids.newId();
    expect(first.compareTo(second), lessThan(0));
  });

  test('IDs are unique even at the same instant', () {
    final ids = UuidV7Generator(FakeClock(time));
    final generated = {for (var i = 0; i < 10000; i++) ids.newId()};
    expect(generated, hasLength(10000));
  });

  test('a seeded Random makes IDs reproducible', () {
    String idWithSeed(int seed) =>
        UuidV7Generator(FakeClock(time), random: Random(seed)).newId();

    expect(idWithSeed(1), idWithSeed(1));
    expect(idWithSeed(1), isNot(idWithSeed(2)));
  });
}
