import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/budget/domain/entities/income_source.dart';
import 'package:mizan/features/budget/domain/usecases/add_income_source.dart';
import 'package:mizan/features/budget/domain/usecases/validate_income_source.dart';
import 'package:mizan/features/budget/domain/value_objects/budget_error.dart';
import 'package:mizan/features/budget/domain/value_objects/budget_failure.dart';
import 'package:mizan/features/budget/domain/value_objects/income_schedule.dart';
import 'package:test/test.dart';

import '../../../../support/fake_income_source_repository.dart';
import '../../../../support/sequential_id_generator.dart';

void main() {
  late FakeIncomeSourceRepository repository;
  late AddIncomeSource addIncomeSource;

  setUp(() {
    repository = FakeIncomeSourceRepository();
    addIncomeSource = AddIncomeSource(
      repository,
      SequentialIdGenerator(prefix: 's'),
      const ValidateIncomeSource(),
    );
  });

  test('saves a new source with a fresh id and returns it', () async {
    final result = await addIncomeSource(
      name: ' Grant ',
      amount: const Money(450000, Currency.tnd),
      schedule: const IncomeSchedule.monthly(dayOfMonth: 15),
    );

    const expected = IncomeSource(
      id: 's1',
      name: 'Grant',
      amount: Money(450000, Currency.tnd),
      schedule: IncomeSchedule.monthly(dayOfMonth: 15),
    );
    expect(result, const Ok<IncomeSource, BudgetFailure>(expected));
    expect(repository.live, [expected]);
  });

  test('saves nothing when invalid', () async {
    final result = await addIncomeSource(
      name: 'Grant',
      amount: const Money(0, Currency.tnd),
      schedule: const IncomeSchedule.irregular(),
    );

    expect(result.failureOrNull?.error, BudgetError.amountNotPositive);
    expect(repository.live, isEmpty);
  });

  test('passes on a storage failure', () async {
    repository.writeFailure = const BudgetFailure(BudgetError.storage);

    final result = await addIncomeSource(
      name: 'Grant',
      amount: const Money(1, Currency.tnd),
      schedule: const IncomeSchedule.irregular(),
    );

    expect(result.failureOrNull?.error, BudgetError.storage);
  });
}
