import 'package:glados/glados.dart';
import 'package:mizan/core/clock/year_month.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/budget/domain/entities/income_source.dart';
import 'package:mizan/features/budget/domain/usecases/select_alerts_to_send.dart';
import 'package:mizan/features/budget/domain/value_objects/budget_alert.dart';
import 'package:mizan/features/budget/domain/value_objects/income_schedule.dart';
import 'package:mizan/features/budget/domain/value_objects/next_income.dart';
import 'package:mizan/features/budget/domain/value_objects/sent_alert.dart';

final _today = DateTime.utc(2026, 10, 20);
final _yesterday = DateTime.utc(2026, 10, 19);
const _select = SelectAlertsToSend();

Money _dt(int dinars) => Money(dinars * 1000, Currency.tnd);

DateTime _day(int month, int day) => DateTime.utc(2026, month, day);

BudgetAlert _category(String id, int percent, {int month = 10}) =>
    BudgetAlert.categoryLimit(
      categoryId: id,
      categoryName: id,
      month: YearMonth(2026, month),
      spent: _dt(percent),
      limit: _dt(100),
      usedPercent: percent,
    );

final _payday = NextIncome(
  source: IncomeSource(
    id: 'grant',
    name: 'Grant',
    amount: _dt(300),
    schedule: const IncomeSchedule.monthly(dayOfMonth: 25),
  ),
  date: _day(10, 25),
);

BudgetAlert _runOut(int day, {NextIncome? next}) =>
    BudgetAlert.runOut(runOut: _day(10, day), next: next ?? _payday);

BudgetAlert _unusual(String id, int dinars, int median) =>
    BudgetAlert.unusualSpending(
      expenseId: id,
      categoryName: 'Food',
      date: _today,
      amount: _dt(dinars),
      median: _dt(median),
    );

SentAlert _sent(BudgetAlert alert, DateTime on) => SentAlert(
  type: alert.type,
  situation: alert.situation,
  sentOn: on,
  runOut: alert is RunOutAlert ? alert.runOut : null,
);

List<BudgetAlert> _pick(
  List<BudgetAlert> candidates, [
  List<SentAlert> sent = const [],
]) => _select(today: _today, candidates: candidates, sent: sent);

void main() {
  test('nothing sent yet: one of each type, in type order', () {
    expect(_pick([_unusual('e', 90, 12), _runOut(22), _category('food', 85)]), [
      _category('food', 85),
      _runOut(22),
      _unusual('e', 90, 12),
    ]);
  });

  group('at most one a day per type', () {
    test('a type sent today sends nothing else today', () {
      final sent = [_sent(_category('food', 85), _today)];
      expect(_pick([_category('study', 90)], sent), isEmpty);
    });

    test('the cooldown is per type', () {
      final sent = [_sent(_category('food', 85), _today)];
      expect(_pick([_category('study', 90), _runOut(22)], sent), [_runOut(22)]);
    });

    test('ends the next day', () {
      final sent = [_sent(_category('food', 85), _yesterday)];
      expect(_pick([_category('study', 90)], sent), [_category('study', 90)]);
    });

    test('of several candidates, the most pressing is sent', () {
      expect(_pick([_category('food', 85), _category('study', 120)]), [
        _category('study', 120),
      ]);
      // 50 / 10 = 5× beats 90 / 30 = 3×.
      expect(_pick([_unusual('a', 90, 30), _unusual('b', 50, 10)]), [
        _unusual('b', 50, 10),
      ]);
    });
  });

  group('once per situation', () {
    test('a category alerts once a month', () {
      final sent = [_sent(_category('food', 82), _day(10, 3))];
      expect(_pick([_category('food', 95)], sent), isEmpty);
      // A new month is a new situation.
      expect(
        _select(
          today: _day(11, 2),
          candidates: [_category('food', 81, month: 11)],
          sent: sent,
        ),
        hasLength(1),
      );
    });

    test('a category already sent leaves room for another one', () {
      final sent = [_sent(_category('food', 82), _day(10, 3))];
      expect(_pick([_category('food', 95), _category('study', 80)], sent), [
        _category('study', 80),
      ]);
    });

    test('an unusual expense alerts once', () {
      final sent = [_sent(_unusual('e', 90, 12), _yesterday)];
      expect(_pick([_unusual('e', 90, 12)], sent), isEmpty);
      expect(_pick([_unusual('f', 90, 12)], sent), hasLength(1));
    });

    test(
      'run-out: again for the same payday only if the date moves earlier',
      () {
        final sent = [_sent(_runOut(22), _day(10, 15))];
        expect(_pick([_runOut(22)], sent), isEmpty);
        expect(_pick([_runOut(23)], sent), isEmpty);
        expect(_pick([_runOut(21)], sent), [_runOut(21)]);
      },
    );

    test('run-out: earlier than every warning before it', () {
      final sent = [
        _sent(_runOut(22), _day(10, 10)),
        _sent(_runOut(18), _day(10, 15)),
      ];
      expect(_pick([_runOut(21)], sent), isEmpty);
      expect(_pick([_runOut(17)], sent), [_runOut(17)]);
    });

    test('run-out: a new payday is a new situation', () {
      final novemberPayday = _payday.copyWith(date: _day(11, 25));
      final sent = [_sent(_runOut(22), _day(10, 15))];
      final later = BudgetAlert.runOut(
        runOut: _day(11, 20),
        next: novemberPayday,
      );
      expect(_pick([later], sent), [later]);
    });
  });

  group('properties', () {
    Glados(any.alertScenario).test(
      'never two of a type, never a type already sent today, never a '
      'situation already sent (run-outs only if earlier)',
      (scenario) {
        final (candidates, sent) = scenario;
        final picked = _pick(candidates, sent);
        final types = picked.map((a) => a.type).toList();
        expect(types.toSet(), hasLength(types.length));
        for (final alert in picked) {
          expect(candidates, contains(alert));
          expect(
            sent.where((s) => s.type == alert.type && s.sentOn == _today),
            isEmpty,
          );
          for (final s in sent.where(
            (s) => s.type == alert.type && s.situation == alert.situation,
          )) {
            expect(alert, isA<RunOutAlert>());
            expect((alert as RunOutAlert).runOut.isBefore(s.runOut!), isTrue);
          }
        }
      },
    );
  });
}

extension _AlertAnys on Any {
  Generator<(List<BudgetAlert>, List<SentAlert>)> get alertScenario =>
      intInRange(0, 1 << 32).map((seed) {
        final random = Random(seed);
        BudgetAlert alert() => switch (random.nextInt(3)) {
          0 => _category('c${random.nextInt(4)}', 80 + random.nextInt(60)),
          1 => _runOut(1 + random.nextInt(24)),
          _ => _unusual('e${random.nextInt(5)}', 30 + random.nextInt(90), 10),
        };
        final candidates = List.generate(random.nextInt(8), (_) => alert());
        final sent = List.generate(
          random.nextInt(6),
          (_) => _sent(alert(), _day(10, 15 + random.nextInt(6))),
        );
        return (candidates, sent);
      });
}
