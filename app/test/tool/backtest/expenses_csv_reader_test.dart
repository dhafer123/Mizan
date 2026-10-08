import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/expenses/domain/entities/category.dart';
import 'package:mizan/features/expenses/domain/entities/expense.dart';
import 'package:mizan/features/settings/domain/usecases/build_expenses_csv.dart';

import '../../../tool/backtest/expenses_csv_reader.dart';

const _read = ExpensesCsvReader();

void main() {
  test("reads back the app's own export", () {
    final expenses = [
      Expense(
        id: 'a',
        amount: const Money(4500, Currency.tnd),
        categoryId: 'food',
        date: DateTime.utc(2026, 10, 1),
        note: 'coffee, "big" one\nwith cake',
      ),
      Expense(
        id: 'b',
        amount: const Money(12000, Currency.tnd),
        categoryId: 'gone',
        date: DateTime.utc(2026, 10, 2),
        note: '=SUM(A1)',
      ),
    ];
    final csv = const BuildExpensesCsv()(
      expenses: expenses,
      categories: const [Category(id: 'food', name: 'Food', icon: 'food')],
    );

    final read = _read(csv);

    expect(read, hasLength(2));
    expect(read[0].id, 'a');
    expect(read[0].amount, const Money(4500, Currency.tnd));
    expect(read[0].date, DateTime.utc(2026, 10, 1));
    expect(read[0].categoryId, 'Food');
    expect(read[0].note, 'coffee, "big" one\nwith cake');
    expect(read[1].categoryId, 'Uncategorised');
    expect(read[1].note, '=SUM(A1)');
  });

  test('needs only Date, Amount and Currency', () {
    final read = _read('Date,Amount,Currency\n2026-10-01,3.5,EUR\n\n');
    expect(read.single.amount, const Money(350, Currency.eur));
    expect(read.single.categoryId, 'other');
    expect(read.single.id, 'line-2');
    expect(read.single.note, isNull);
  });

  test('bad input names the line', () {
    expect(
      () => _read('Date,Currency\n2026-10-01,TND\n'),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => _read('Date,Amount,Currency\n1/10/2026,3,TND\n'),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('Line 2'),
        ),
      ),
    );
    expect(
      () => _read('Date,Amount,Currency\n2026-10-01,abc,TND\n'),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => _read('Date,Amount,Currency\n2026-10-01,3,XYZ\n'),
      throwsA(isA<FormatException>()),
    );
  });

  test('an empty file has no expenses', () {
    expect(_read(''), isEmpty);
  });
}
