import 'package:glados/glados.dart';
import 'package:mizan/core/clock/year_month.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/budget/domain/entities/income_source.dart';
import 'package:mizan/features/budget/domain/value_objects/budget_alert.dart';
import 'package:mizan/features/budget/domain/value_objects/income_schedule.dart';
import 'package:mizan/features/budget/domain/value_objects/next_income.dart';
import 'package:mizan/features/budget/domain/value_objects/run_out_forecast.dart';
import 'package:mizan/features/budget/domain/value_objects/spend_rate.dart';
import 'package:mizan/features/mascot/domain/usecases/read_penny.dart';
import 'package:mizan/features/mascot/domain/value_objects/penny_mood.dart';
import 'package:mizan/features/mascot/domain/value_objects/penny_reason.dart';
import 'package:mizan/features/mascot/domain/value_objects/penny_state.dart';

Money _dt(int dinars) => Money(dinars * 1000, Currency.tnd);
DateTime _oct(int day) => DateTime.utc(2026, 10, day);

final _payday = NextIncome(
  source: IncomeSource(
    id: 'g',
    name: 'Grant',
    amount: _dt(300),
    schedule: const IncomeSchedule.monthly(dayOfMonth: 15),
  ),
  date: _oct(15),
);

ProjectedForecast _projected({DateTime? runOut}) =>
    RunOutForecast.projected(
          today: _oct(6),
          horizonEnd: _oct(6).add(const Duration(days: 60)),
          start: _dt(100),
          runOut: runOut,
          rate: SpendRate.flat(_dt(5)),
          coldStart: false,
        )
        as ProjectedForecast;

BudgetAlert _limit(String name, int spent, int limit) =>
    BudgetAlert.categoryLimit(
      categoryId: name.toLowerCase(),
      categoryName: name,
      month: const YearMonth(2026, 10),
      spent: _dt(spent),
      limit: _dt(limit),
      usedPercent: spent * 100 ~/ limit,
    );

BudgetAlert _unusual(String name, int amount) => BudgetAlert.unusualSpending(
  expenseId: 'e-$name-$amount',
  categoryName: name,
  date: _oct(6),
  amount: _dt(amount),
  median: _dt(5),
);

final _runOut = BudgetAlert.runOut(runOut: _oct(10), next: _payday);

PennyState _read({
  List<BudgetAlert> alerts = const [],
  RunOutForecast? forecast,
  NextIncome? next,
  bool hasIncome = true,
  bool spent = true,
  bool offline = false,
}) => const ReadPenny()(
  alerts: alerts,
  forecast: forecast ?? _projected(),
  next: next,
  hasIncome: hasIncome,
  spentThisMonth: spent,
  offline: offline,
);

void main() {
  group('the most pressing reason wins', () {
    test('running out before payday: worried, with both dates', () {
      expect(
        _read(alerts: [_limit('Food', 200, 100), _runOut], next: _payday),
        PennyState(
          mood: PennyMood.worried,
          reason: PennyReason.runningOut(runOut: _oct(10), payday: _oct(15)),
        ),
      );
    });

    test('already run out: says so, not "around today"', () {
      final reason = _read(
        alerts: [BudgetAlert.runOut(runOut: _oct(6), next: _payday)],
        next: _payday,
      ).reason;
      expect(
        reason,
        PennyReason.runningOut(
          runOut: _oct(6),
          payday: _oct(15),
          alreadyOut: true,
        ),
      );
    });

    test('over a limit: worried about the most over', () {
      expect(
        _read(
          alerts: [
            _limit('Food', 120, 100), // 20 over
            _limit('Leisure', 90, 30), // 60 over
            _unusual('Food', 80),
          ],
        ),
        PennyState(
          mood: PennyMood.worried,
          reason: PennyReason.overLimit(category: 'Leisure', over: _dt(60)),
        ),
      );
    });

    test('a big expense: surprised by the biggest', () {
      expect(
        _read(
          alerts: [
            _limit('Food', 85, 100),
            _unusual('Food', 40),
            _unusual('Leisure', 90),
          ],
        ),
        PennyState(
          mood: PennyMood.surprised,
          reason: PennyReason.bigExpense(category: 'Leisure', amount: _dt(90)),
        ),
      );
    });

    test('near a limit: worried about the fullest', () {
      expect(
        _read(alerts: [_limit('Food', 82, 100), _limit('Study', 95, 100)]),
        const PennyState(
          mood: PennyMood.worried,
          reason: PennyReason.nearLimit(category: 'Study', percent: 95),
        ),
      );
    });

    test('exactly at the limit is near, not over', () {
      expect(
        _read(alerts: [_limit('Food', 100, 100)]).reason,
        const PennyReason.nearLimit(category: 'Food', percent: 99),
      );
    });

    test('offline with nothing to worry about: sleepy', () {
      expect(
        _read(offline: true),
        const PennyState(mood: PennyMood.sleepy, reason: PennyReason.offline()),
      );
      expect(
        _read(offline: true, alerts: [_runOut]).mood,
        PennyMood.worried,
        reason: 'money comes first',
      );
    });

    test('no income: calm, asking for it', () {
      expect(
        _read(hasIncome: false),
        const PennyState(
          mood: PennyMood.calm,
          reason: PennyReason.needsIncome(),
        ),
      );
    });

    test('nothing spent this month: calm', () {
      expect(_read(spent: false).reason, const PennyReason.quietMonth());
      expect(_read(spent: false).mood, PennyMood.calm);
    });

    test('too little history: calm, counting the days to a forecast', () {
      expect(
        _read(forecast: const RunOutForecast.needsData(daysOfData: 9)),
        const PennyState(
          mood: PennyMood.calm,
          reason: PennyReason.learning(daysToGo: 5),
        ),
      );
    });

    test('on track: happy, until payday', () {
      expect(
        _read(
          forecast: _projected(runOut: _oct(25)),
          next: _payday,
        ),
        PennyState(
          mood: PennyMood.happy,
          reason: PennyReason.onTrack(until: _oct(15), untilPayday: true),
        ),
      );
    });

    test('on track with no payday ahead: happy, until the horizon', () {
      expect(
        _read().reason,
        PennyReason.onTrack(
          until: _oct(6).add(const Duration(days: 60)),
          untilPayday: false,
        ),
      );
    });
  });

  group('invariants', () {
    Glados3(
      any.int,
      any.bool,
      any.bool,
    ).test('happy only when no alert holds; worried whenever one about the '
        'budget or the forecast does', (seed, offline, spent) {
      final pool = [
        _runOut,
        _limit('Food', 130, 100),
        _limit('Study', 85, 100),
        _unusual('Leisure', 60),
      ];
      final alerts = [
        for (final (i, alert) in pool.indexed)
          if (seed >> i & 1 == 1) alert,
      ];
      final state = _read(alerts: alerts, offline: offline, spent: spent);

      // Running out or over a limit always worries her; near a limit
      // does unless a big expense (fresher news) surprised her first.
      final serious = alerts.any(
        (a) =>
            a is RunOutAlert || (a is CategoryLimitAlert && a.spent > a.limit),
      );
      final near = alerts.any((a) => a is CategoryLimitAlert);
      final big = alerts.any((a) => a is UnusualSpendingAlert);
      if (serious || (near && !big)) expect(state.mood, PennyMood.worried);
      if (!serious && big) expect(state.mood, PennyMood.surprised);
      if (state.mood == PennyMood.happy) expect(alerts, isEmpty);
      if (alerts.isEmpty && offline) expect(state.mood, PennyMood.sleepy);
    });
  });
}
