import 'package:glados/glados.dart';
import 'package:mizan/core/clock/year_month.dart';

extension _YearMonthAnys on Any {
  Generator<YearMonth> get yearMonth =>
      combine2(intInRange(1970, 2200), intInRange(1, 13), YearMonth.new);
}

void main() {
  test('bounds are the first days of this month and the next', () {
    const october = YearMonth(2026, 10);
    expect(october.firstDay, DateTime.utc(2026, 10));
    expect(october.endExclusive, DateTime.utc(2026, 11));
    expect(const YearMonth(2026, 12).endExclusive, DateTime.utc(2027));
  });

  test('steps across year ends', () {
    expect(const YearMonth(2026, 12).next, const YearMonth(2027, 1));
    expect(const YearMonth(2027, 1).previous, const YearMonth(2026, 12));
  });

  test('of takes the month in the date own time zone', () {
    expect(
      YearMonth.of(DateTime(2026, 10, 31, 23, 59)),
      const YearMonth(2026, 10),
    );
  });

  test('contains every day of the month and nothing else', () {
    const february = YearMonth(2028, 2); // leap year
    expect(february.contains(DateTime.utc(2028, 1, 31)), isFalse);
    expect(february.contains(DateTime.utc(2028, 2)), isTrue);
    expect(february.contains(DateTime.utc(2028, 2, 29)), isTrue);
    expect(february.contains(DateTime.utc(2028, 3)), isFalse);
  });

  test('orders by year, then month', () {
    expect(
      const YearMonth(2026, 12).compareTo(const YearMonth(2027, 1)),
      isNegative,
    );
    expect(
      const YearMonth(2026, 5).compareTo(const YearMonth(2026, 3)),
      isPositive,
    );
    expect(const YearMonth(2026, 5).compareTo(const YearMonth(2026, 5)), 0);
  });

  test('rejects a month outside 1-12', () {
    expect(() => YearMonth(2026, 13), throwsA(isA<AssertionError>()));
    expect(() => YearMonth(2026, 0), throwsA(isA<AssertionError>()));
  });

  Glados(any.yearMonth).test('next and previous undo each other', (month) {
    expect(month.next.previous, month);
    expect(month.previous.next, month);
    expect(month.next.compareTo(month), isPositive);
  });

  Glados(any.yearMonth).test('months tile time with no gap or overlap', (
    month,
  ) {
    expect(month.endExclusive, month.next.firstDay);
    expect(month.contains(month.firstDay), isTrue);
    expect(month.contains(month.endExclusive), isFalse);
    expect(
      month.contains(month.endExclusive.subtract(const Duration(days: 1))),
      isTrue,
    );
  });
}
