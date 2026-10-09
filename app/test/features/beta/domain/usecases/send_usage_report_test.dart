import 'package:mizan/core/clock/fake_clock.dart';
import 'package:mizan/core/ids/uuid_v7_generator.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/beta/domain/entities/usage_sharing.dart';
import 'package:mizan/features/beta/domain/usecases/send_usage_report.dart';
import 'package:mizan/features/beta/domain/value_objects/beta_error.dart';
import 'package:mizan/features/beta/domain/value_objects/beta_failure.dart';
import 'package:mizan/features/beta/domain/value_objects/usage_day.dart';
import 'package:mizan/features/expenses/domain/entities/expense.dart';
import 'package:mizan/features/expenses/domain/value_objects/expense_error.dart';
import 'package:mizan/features/expenses/domain/value_objects/expense_failure.dart';
import 'package:mizan/features/expenses/domain/value_objects/expense_source.dart';
import 'package:test/test.dart';

import '../../../../support/fake_beta_repository.dart';
import '../../../../support/fake_expense_repository.dart';
import '../../../../support/fake_usage_sharing_repository.dart';

final oct8 = DateTime.utc(2026, 10, 8);
final oct9 = DateTime.utc(2026, 10, 9);

Expense voiceExpenseOn(DateTime localTime) => Expense(
  id: UuidV7Generator(FakeClock(localTime)).newId(),
  amount: const Money(2000, Currency.tnd),
  categoryId: 'food',
  date: oct9,
  source: ExpenseSource.voice,
);

void main() {
  late FakeUsageSharingRepository sharing;
  late FakeExpenseRepository expenses;
  late FakeBetaRepository beta;
  late SendUsageReport send;

  void setUpWith(UsageSharing? stored) {
    sharing = FakeUsageSharingRepository(stored);
    expenses = FakeExpenseRepository([
      voiceExpenseOn(DateTime(2026, 10, 9, 12)),
    ]);
    beta = FakeBetaRepository();
    // A local noon, so "today" is 9 October in any time zone.
    send = SendUsageReport(
      sharing,
      expenses,
      beta,
      FakeClock(DateTime(2026, 10, 9, 12)),
      '0.1.0+1',
    );
  }

  test('does nothing while sharing is off', () async {
    setUpWith(null);

    expect(await send(), const Ok<bool, BetaFailure>(false));
    expect(beta.reports, isEmpty);
  });

  test('sends the days since opting in, then remembers today', () async {
    setUpWith(UsageSharing(installId: 'install-1', since: oct8));

    expect(await send(), const Ok<bool, BetaFailure>(true));

    final report = beta.reports.single;
    expect(report.installId, 'install-1');
    expect(report.appVersion, '0.1.0+1');
    expect(report.days, [UsageDay(day: oct8), UsageDay(day: oct9, voice: 1)]);
    expect(sharing.sharing!.lastSentDay, oct9);
  });

  test('sends at most once a day', () async {
    setUpWith(UsageSharing(installId: 'install-1', since: oct8));
    await send();

    expect(await send(), const Ok<bool, BetaFailure>(false));
    expect(beta.reports, hasLength(1));
  });

  test('a failed send is tried again next time', () async {
    setUpWith(UsageSharing(installId: 'install-1', since: oct8));
    beta.failure = const BetaFailure(BetaError.offline);

    expect(
      await send(),
      const Err<bool, BetaFailure>(BetaFailure(BetaError.offline)),
    );
    expect(sharing.sharing!.lastSentDay, isNull);

    beta.failure = null;
    expect(await send(), const Ok<bool, BetaFailure>(true));
  });

  test('storage failures are failures, and nothing is sent', () async {
    setUpWith(UsageSharing(installId: 'install-1', since: oct8));
    expenses.readFailure = const ExpenseFailure(ExpenseError.storage);

    expect(
      await send(),
      const Err<bool, BetaFailure>(BetaFailure(BetaError.storage)),
    );

    sharing.loadFailure = const BetaFailure(BetaError.storage);
    expect(
      await send(),
      const Err<bool, BetaFailure>(BetaFailure(BetaError.storage)),
    );
    expect(beta.reports, isEmpty);
  });
}
