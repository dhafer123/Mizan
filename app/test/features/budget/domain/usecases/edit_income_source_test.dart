import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/budget/domain/entities/income_source.dart';
import 'package:mizan/features/budget/domain/usecases/edit_income_source.dart';
import 'package:mizan/features/budget/domain/usecases/validate_income_source.dart';
import 'package:mizan/features/budget/domain/value_objects/budget_error.dart';
import 'package:mizan/features/budget/domain/value_objects/budget_failure.dart';
import 'package:mizan/features/budget/domain/value_objects/income_schedule.dart';
import 'package:test/test.dart';

import '../../../../support/fake_income_source_repository.dart';

const _grant = IncomeSource(
  id: 's1',
  name: 'Grant',
  amount: Money(450000, Currency.tnd),
  schedule: IncomeSchedule.monthly(dayOfMonth: 15),
);

void main() {
  late FakeIncomeSourceRepository repository;
  late EditIncomeSource editIncomeSource;

  setUp(() {
    repository = FakeIncomeSourceRepository([_grant]);
    editIncomeSource = EditIncomeSource(
      repository,
      const ValidateIncomeSource(),
    );
  });

  test('saves the validated changes, schedule included', () async {
    final result = await editIncomeSource(
      _grant.copyWith(
        name: 'Grant ',
        schedule: const IncomeSchedule.irregular(),
      ),
    );

    final expected = _grant.copyWith(
      schedule: const IncomeSchedule.irregular(),
    );
    expect(result, Ok<IncomeSource, BudgetFailure>(expected));
    expect(repository.live, [expected]);
  });

  test('changes nothing when invalid', () async {
    final result = await editIncomeSource(_grant.copyWith(name: ''));

    expect(result.failureOrNull?.error, BudgetError.nameEmpty);
    expect(repository.live, [_grant]);
  });

  test('fails for a source that is gone', () async {
    await repository.delete('s1');

    final result = await editIncomeSource(_grant);

    expect(result.failureOrNull?.error, BudgetError.notFound);
  });
}
