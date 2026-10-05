import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/core/clock/fake_clock.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/expenses/domain/entities/default_categories.dart';
import 'package:mizan/features/expenses/domain/entities/expense.dart';
import 'package:mizan/features/expenses/domain/value_objects/expense_error.dart';
import 'package:mizan/features/expenses/domain/value_objects/expense_failure.dart';
import 'package:mizan/features/settings/domain/usecases/export_expenses_csv.dart';
import 'package:mizan/features/settings/domain/value_objects/settings_error.dart';
import 'package:mizan/features/settings/domain/value_objects/settings_failure.dart';

import '../../../../support/fake_category_repository.dart';
import '../../../../support/fake_expense_repository.dart';
import '../../../../support/fake_file_exporter.dart';

Expense _expense(String id) => Expense(
  id: id,
  amount: const Money(3500, Currency.tnd),
  categoryId: 'food',
  date: DateTime.utc(2026, 10, 3),
);

void main() {
  late FakeExpenseRepository expenses;
  late FakeFileExporter exporter;
  late ExportExpensesCsv export;

  setUp(() {
    expenses = FakeExpenseRepository([_expense('a'), _expense('b')]);
    exporter = FakeFileExporter();
    export = ExportExpensesCsv(
      expenses,
      FakeCategoryRepository(DefaultCategories.all),
      exporter,
      FakeClock(DateTime.utc(2026, 10, 6, 9)),
    );
  });

  test('saves every expense as a dated CSV file', () async {
    expect(await export(), const Ok<int?, SettingsFailure>(2));

    expect(exporter.fileName, 'mizan-expenses-2026-10-06.csv');
    expect(exporter.mimeType, 'text/csv');
    // UTF-8 with a byte-order mark (utf8.decode drops it, so check bytes).
    expect(exporter.bytes!.take(3), [0xEF, 0xBB, 0xBF]);
    expect(exporter.text, startsWith('Date,Amount,'));
    expect('\r\n'.allMatches(exporter.text!), hasLength(3));
  });

  test('cancelling the picker is not an error', () async {
    exporter.saves = false;

    expect(await export(), const Ok<int?, SettingsFailure>(null));
  });

  test('nothing to export', () async {
    await expenses.delete('a');
    await expenses.delete('b');

    expect(
      await export(),
      const Err<int?, SettingsFailure>(
        SettingsFailure(SettingsError.nothingToExport),
      ),
    );
    expect(exporter.bytes, isNull);
  });

  test('a database failure', () async {
    expenses.readFailure = const ExpenseFailure(ExpenseError.storage);

    expect(
      await export(),
      const Err<int?, SettingsFailure>(SettingsFailure(SettingsError.storage)),
    );
  });

  test('a failed write', () async {
    exporter.failure = const SettingsFailure(SettingsError.exportFailed);

    expect(
      await export(),
      const Err<int?, SettingsFailure>(
        SettingsFailure(SettingsError.exportFailed),
      ),
    );
  });
}
