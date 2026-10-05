import 'package:mizan/core/clock/fake_clock.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/expenses/domain/entities/expense.dart';
import 'package:mizan/features/expenses/domain/usecases/validate_expense.dart';
import 'package:mizan/features/expenses/domain/value_objects/expense_error.dart';
import 'package:mizan/features/expenses/domain/value_objects/expense_failure.dart';
import 'package:test/test.dart';

Expense _expense({
  int amount = 4500,
  String categoryId = 'food',
  DateTime? date,
  String? note,
}) => Expense(
  id: 'e1',
  amount: Money(amount, Currency.tnd),
  categoryId: categoryId,
  date: date ?? DateTime.utc(2026, 10, 6),
  note: note,
);

void main() {
  // 6 October, late evening local time.
  final validate = ValidateExpense(FakeClock(DateTime(2026, 10, 6, 23, 30)));

  ExpenseError? errorOf(Expense expense) =>
      validate(expense).failureOrNull?.error;

  test('accepts a valid expense unchanged', () {
    final expense = _expense(note: 'coffee');
    expect(validate(expense), Ok<Expense, ExpenseFailure>(expense));
  });

  group('amount', () {
    test('must be more than zero', () {
      expect(errorOf(_expense(amount: 0)), ExpenseError.amountNotPositive);
      expect(errorOf(_expense(amount: -1)), ExpenseError.amountNotPositive);
      expect(errorOf(_expense(amount: 1)), isNull);
    });
  });

  group('category', () {
    test('is required', () {
      expect(errorOf(_expense(categoryId: '')), ExpenseError.noCategory);
      expect(errorOf(_expense(categoryId: '  ')), ExpenseError.noCategory);
    });
  });

  group('note', () {
    test('is trimmed, and a blank note becomes none', () {
      expect(validate(_expense(note: '  coffee ')).valueOrNull!.note, 'coffee');
      expect(validate(_expense(note: '   ')).valueOrNull!.note, isNull);
      expect(validate(_expense(note: '')).valueOrNull!.note, isNull);
    });

    test('has a maximum length, counted after trimming', () {
      final longest = 'x' * ValidateExpense.maxNoteLength;
      expect(errorOf(_expense(note: ' $longest ')), isNull);
      expect(errorOf(_expense(note: '${longest}x')), ExpenseError.noteTooLong);
    });
  });

  group('date', () {
    test('is stored as the calendar day', () {
      final result = validate(_expense(date: DateTime(2026, 10, 5, 18, 45)));
      expect(result.valueOrNull!.date, DateTime.utc(2026, 10, 5));
    });

    test('may be today (by the local clock), not later', () {
      expect(errorOf(_expense(date: DateTime.utc(2026, 10, 6))), isNull);
      expect(
        errorOf(_expense(date: DateTime.utc(2026, 10, 7))),
        ExpenseError.dateInFuture,
      );
    });
  });

  test('every error has a message for the UI', () {
    for (final error in ExpenseError.values) {
      expect(ExpenseFailure(error).message, isNotEmpty);
    }
  });
}
