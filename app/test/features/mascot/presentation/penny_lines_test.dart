import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/mascot/domain/value_objects/penny_reason.dart';
import 'package:mizan/features/mascot/presentation/penny_lines.dart';

String _day(DateTime d) => 'DAY${d.day}';
String _money(Money m) => 'MONEY${m.minorUnits}';

List<String> _lines(PennyReason reason) =>
    PennyLines.forReason(reason, day: _day, money: _money);

void main() {
  // Each reason, and the facts every one of its lines must contain.
  final cases = <PennyReason, List<String>>{
    PennyReason.runningOut(
      runOut: DateTime.utc(2026, 10, 10),
      payday: DateTime.utc(2026, 10, 15),
    ): [
      'DAY10',
      'DAY15',
    ],
    PennyReason.runningOut(runOut: DateTime.utc(2026, 10, 10)): ['DAY10'],
    PennyReason.runningOut(
      runOut: DateTime.utc(2026, 10, 6),
      payday: DateTime.utc(2026, 10, 15),
      alreadyOut: true,
    ): [
      'run out',
      'DAY15',
    ],
    PennyReason.runningOut(runOut: DateTime.utc(2026, 10, 6), alreadyOut: true):
        ['run out', 'no income'],
    const PennyReason.overLimit(
      category: 'Food',
      over: Money(20000, Currency.tnd),
    ): [
      'Food',
      'MONEY20000',
    ],
    const PennyReason.nearLimit(category: 'Study', percent: 85): [
      'Study',
      '85%',
    ],
    const PennyReason.bigExpense(
      category: 'Leisure',
      amount: Money(90000, Currency.tnd),
    ): [
      'Leisure',
      'MONEY90000',
    ],
    const PennyReason.offline(): ['sync'],
    const PennyReason.needsIncome(): ['income'],
    const PennyReason.quietMonth(): ['month'],
    const PennyReason.learning(daysToGo: 5): ['5 days'],
    const PennyReason.learning(daysToGo: 1): ['1 day '],
    PennyReason.onTrack(until: DateTime.utc(2026, 10, 15), untilPayday: true): [
      'DAY15',
      'payday',
    ],
    PennyReason.onTrack(until: DateTime.utc(2026, 12, 5), untilPayday: false): [
      'DAY5',
    ],
  };

  for (final MapEntry(key: reason, value: facts) in cases.entries) {
    test('every line for $reason says ${facts.join(', ')}', () {
      final lines = _lines(reason);
      expect(lines, isNotEmpty);
      for (final line in lines) {
        for (final fact in facts) {
          expect(
            line.toLowerCase(),
            contains(fact.toLowerCase()),
            reason: line,
          );
        }
      }
    });
  }

  test('every moment has something to say', () {
    for (final moment in PennyMoment.values) {
      expect(PennyLines.forMoment(moment), isNotEmpty, reason: '$moment');
    }
  });

  test('the same pick gives the same line, and picks cycle', () {
    final lines = ['a', 'b', 'c'];
    expect(PennyLines.pick(lines, 4), PennyLines.pick(lines, 4));
    expect([for (var i = 0; i < 3; i++) PennyLines.pick(lines, i)], lines);
    expect(PennyLines.pick(lines, 3), 'a');
  });
}
