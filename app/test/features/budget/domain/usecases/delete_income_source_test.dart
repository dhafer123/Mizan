import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/budget/domain/entities/income_source.dart';
import 'package:mizan/features/budget/domain/usecases/delete_income_source.dart';
import 'package:mizan/features/budget/domain/value_objects/budget_error.dart';
import 'package:mizan/features/budget/domain/value_objects/income_schedule.dart';
import 'package:test/test.dart';

import '../../../../support/fake_income_source_repository.dart';

void main() {
  test('removes the source', () async {
    final repository = FakeIncomeSourceRepository([
      const IncomeSource(
        id: 's1',
        name: 'Grant',
        amount: Money(450000, Currency.tnd),
        schedule: IncomeSchedule.irregular(),
      ),
    ]);

    expect((await DeleteIncomeSource(repository)('s1')).isOk, isTrue);
    expect(repository.live, isEmpty);
  });

  test('fails for an unknown id', () async {
    final result = await DeleteIncomeSource(FakeIncomeSourceRepository())('x');
    expect(result.failureOrNull?.error, BudgetError.notFound);
  });
}
