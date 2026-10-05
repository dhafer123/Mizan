import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/budget/domain/entities/income_source.dart';
import 'package:mizan/features/budget/domain/usecases/validate_income_source.dart';
import 'package:mizan/features/budget/domain/value_objects/budget_error.dart';
import 'package:mizan/features/budget/domain/value_objects/budget_failure.dart';
import 'package:mizan/features/budget/domain/value_objects/income_schedule.dart';
import 'package:test/test.dart';

const _validate = ValidateIncomeSource();

IncomeSource _source({
  String name = 'Grant',
  int amount = 450000,
  IncomeSchedule schedule = const IncomeSchedule.monthly(dayOfMonth: 15),
}) => IncomeSource(
  id: 's1',
  name: name,
  amount: Money(amount, Currency.tnd),
  schedule: schedule,
);

BudgetError? _errorOf(IncomeSource source) =>
    _validate(source).failureOrNull?.error;

void main() {
  test('accepts a valid source, name trimmed', () {
    expect(
      _validate(_source(name: ' Grant  ')),
      Ok<IncomeSource, BudgetFailure>(_source()),
    );
  });

  test('name is required and at most 60 characters', () {
    expect(_errorOf(_source(name: '  ')), BudgetError.nameEmpty);
    final longest = 'x' * ValidateIncomeSource.maxNameLength;
    expect(_errorOf(_source(name: longest)), isNull);
    expect(_errorOf(_source(name: '${longest}x')), BudgetError.nameTooLong);
  });

  test('amount must be more than zero', () {
    expect(_errorOf(_source(amount: 0)), BudgetError.amountNotPositive);
    expect(_errorOf(_source(amount: -1)), BudgetError.amountNotPositive);
  });

  test('a monthly day must be 1-31', () {
    for (final day in [1, 28, 31]) {
      expect(
        _errorOf(_source(schedule: IncomeSchedule.monthly(dayOfMonth: day))),
        isNull,
      );
    }
    for (final day in [0, 32, -1]) {
      expect(
        _errorOf(_source(schedule: IncomeSchedule.monthly(dayOfMonth: day))),
        BudgetError.invalidDay,
      );
    }
  });

  test('a one-off date is stored as the calendar day', () {
    final result = _validate(
      _source(
        schedule: IncomeSchedule.oneOff(date: DateTime(2026, 10, 20, 18)),
      ),
    );
    expect(
      result.valueOrNull!.schedule,
      IncomeSchedule.oneOff(date: DateTime.utc(2026, 10, 20)),
    );
  });

  test('irregular needs nothing more', () {
    expect(
      _errorOf(_source(schedule: const IncomeSchedule.irregular())),
      isNull,
    );
  });

  test('every error has a message for the UI', () {
    for (final error in BudgetError.values) {
      expect(BudgetFailure(error).message, isNotEmpty);
    }
  });
}
