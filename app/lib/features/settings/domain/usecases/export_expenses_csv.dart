import 'dart:convert';

import '../../../../core/clock/clock.dart';
import '../../../../core/result/result.dart';
import '../../../expenses/domain/repositories/category_repository.dart';
import '../../../expenses/domain/repositories/expense_repository.dart';
import '../repositories/file_exporter.dart';
import '../value_objects/settings_error.dart';
import '../value_objects/settings_failure.dart';
import 'build_expenses_csv.dart';

/// Writes every expense to a CSV file the user saves where they choose.
/// Ok(count exported), or Ok(null) if they cancelled the save.
class ExportExpensesCsv {
  const ExportExpensesCsv(
    this._expenses,
    this._categories,
    this._exporter,
    this._clock, {
    BuildExpensesCsv build = const BuildExpensesCsv(),
  }) : _build = build;

  final ExpenseRepository _expenses;
  final CategoryRepository _categories;
  final FileExporter _exporter;
  final Clock _clock;
  final BuildExpensesCsv _build;

  static const mimeType = 'text/csv';

  Future<Result<int?, SettingsFailure>> call() async {
    const storage = Err<int?, SettingsFailure>(
      SettingsFailure(SettingsError.storage),
    );
    final expenses = switch (await _expenses.getAll()) {
      Ok(:final value) => value,
      Err() => null,
    };
    if (expenses == null) return storage;
    if (expenses.isEmpty) {
      return const Err(SettingsFailure(SettingsError.nothingToExport));
    }
    final categories = switch (await _categories.getAll()) {
      Ok(:final value) => value,
      Err() => null,
    };
    if (categories == null) return storage;

    final csv = _build(expenses: expenses, categories: categories);
    final saved = await _exporter.save(
      fileName: fileName(_clock.now()),
      mimeType: mimeType,
      bytes: utf8.encode(csv),
    );
    return switch (saved) {
      Ok(value: true) => Ok(expenses.length),
      Ok() => const Ok(null),
      Err(:final failure) => Err(failure),
    };
  }

  /// `mizan-expenses-2026-10-05.csv`, for the day [now] falls on.
  static String fileName(DateTime now) =>
      'mizan-expenses-${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}.csv';
}
