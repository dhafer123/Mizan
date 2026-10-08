import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/core/clock/fake_clock.dart';
import 'package:mizan/core/clock/year_month.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/budget/domain/usecases/send_budget_alerts.dart';
import 'package:mizan/features/budget/domain/value_objects/alert_type.dart';
import 'package:mizan/features/budget/domain/value_objects/budget_alert.dart';
import 'package:mizan/features/budget/domain/value_objects/budget_error.dart';
import 'package:mizan/features/budget/domain/value_objects/budget_failure.dart';
import 'package:mizan/features/budget/domain/value_objects/sent_alert.dart';

import '../../../../support/fake_alert_log.dart';
import '../../../../support/fake_alert_notifier.dart';

Money _dt(int dinars) => Money(dinars * 1000, Currency.tnd);

BudgetAlert _category(String id) => BudgetAlert.categoryLimit(
  categoryId: id,
  categoryName: id,
  month: const YearMonth(2026, 10),
  spent: _dt(85),
  limit: _dt(100),
  usedPercent: 85,
);

List<BudgetAlert> _shown(Result<List<BudgetAlert>, BudgetFailure> result) =>
    (result as Ok<List<BudgetAlert>, BudgetFailure>).value;

final _runOut = BudgetAlert.runOut(runOut: DateTime.utc(2026, 10, 23));

void main() {
  late FakeAlertLog log;
  late FakeAlertNotifier notifier;
  late FakeClock clock;
  late SendBudgetAlerts send;

  setUp(() {
    log = FakeAlertLog();
    notifier = FakeAlertNotifier();
    // Evening, local time: the day is still 20 October.
    clock = FakeClock(DateTime(2026, 10, 20, 21, 30));
    send = SendBudgetAlerts(log, notifier, clock);
  });

  test('shows the due alerts and logs them for today', () async {
    final result = await send([_category('food'), _runOut]);

    expect(_shown(result), [_category('food'), _runOut]);
    expect(notifier.shown, [_category('food'), _runOut]);
    expect(log.sent, [
      SentAlert(
        type: AlertType.categoryLimit,
        situation: _category('food').situation,
        sentOn: DateTime.utc(2026, 10, 20),
      ),
      SentAlert(
        type: AlertType.runOut,
        situation: 'no-income',
        sentOn: DateTime.utc(2026, 10, 20),
        runOut: DateTime.utc(2026, 10, 23),
      ),
    ]);
  });

  test('cooldown: a second check the same day sends nothing of that type, '
      'the next day it does', () async {
    await send([_category('food')]);
    notifier.shown.clear();

    await send([_category('food'), _category('study')]);
    expect(notifier.shown, isEmpty);

    clock.advance(const Duration(hours: 3)); // past midnight
    await send([_category('food'), _category('study')]);
    expect(notifier.shown, [_category('study')]);
  });

  test('alerts sent long ago are not read', () async {
    log.sent.add(
      SentAlert(
        type: AlertType.runOut,
        situation: 'no-income',
        sentOn: DateTime.utc(2026, 8, 1),
        runOut: DateTime.utc(2026, 8, 3),
      ),
    );
    await send([_runOut]);
    expect(notifier.shown, [_runOut]);
  });

  test('notifications off: nothing logged, so it is tried again', () async {
    notifier.enabled = false;
    expect(_shown(await send([_runOut])), isEmpty);
    expect(log.sent, isEmpty);

    notifier.enabled = true;
    await send([_runOut]);
    expect(notifier.shown, [_runOut]);
  });

  test('a storage failure is returned, not thrown', () async {
    log.failure = BudgetError.storage;
    expect(
      await send([_runOut]),
      const Err<List<BudgetAlert>, BudgetFailure>(
        BudgetFailure(BudgetError.storage),
      ),
    );
    expect(notifier.shown, isEmpty);
  });

  test('overlapping checks send an alert once', () async {
    await Future.wait([
      send([_runOut]),
      send([_runOut]),
      send([_runOut]),
    ]);
    expect(notifier.shown, [_runOut]);
  });

  test('no candidates: nothing is read or sent', () async {
    log.failure = BudgetError.storage;
    expect(_shown(await send([])), isEmpty);
  });
}
