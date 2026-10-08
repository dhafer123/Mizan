import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money_parser.dart';
import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/expenses/domain/entities/expense.dart';

/// Reads the CSV the app exports (Settings → Export, `BuildExpensesCsv`)
/// back into expenses, for the forecast backtest.
///
/// Needs the `Date` (`YYYY-MM-DD`), `Amount` and `Currency` columns; `ID`,
/// `Category` and `Note` are used when present, so a hand-made spreadsheet
/// with the same headers works too. The category *name* becomes the
/// category id. Throws a [FormatException] naming the line on bad input.
class ExpensesCsvReader {
  const ExpensesCsvReader();

  List<Expense> call(String csv) {
    final rows = _rows(csv.startsWith('﻿') ? csv.substring(1) : csv);
    if (rows.isEmpty) return const [];
    final header = rows.first.map((h) => h.trim()).toList();
    int column(String name, {bool required = true}) {
      final index = header.indexOf(name);
      if (index < 0 && required) {
        throw FormatException('The CSV has no "$name" column.');
      }
      return index;
    }

    final date = column('Date');
    final amount = column('Amount');
    final currency = column('Currency');
    final id = column('ID', required: false);
    final category = column('Category', required: false);
    final note = column('Note', required: false);

    final expenses = <Expense>[];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.every((cell) => cell.trim().isEmpty)) continue;
      String cell(int index) =>
          index < 0 || index >= row.length ? '' : row[index].trim();
      final line = i + 1;

      final code = Currency.fromCode(cell(currency));
      if (code == null) {
        throw FormatException(
          'Line $line: unknown currency "${cell(currency)}".',
        );
      }
      final money = switch (const MoneyParser().parse(
        cell(amount),
        currency: code,
      )) {
        Ok(:final value) when value.isPositive => value,
        _ => throw FormatException(
          'Line $line: "${cell(amount)}" is not an amount above 0.',
        ),
      };
      final day = DateTime.tryParse(cell(date));
      if (day == null || cell(date).length != 10) {
        throw FormatException('Line $line: "${cell(date)}" is not YYYY-MM-DD.');
      }
      final text = _undefused(cell(note));
      expenses.add(
        Expense(
          id: cell(id).isEmpty ? 'line-$line' : cell(id),
          amount: money,
          categoryId: cell(category).isEmpty
              ? 'other'
              : _undefused(cell(category)),
          date: DateTime.utc(day.year, day.month, day.day),
          note: text.isEmpty ? null : text,
        ),
      );
    }
    return expenses;
  }

  /// Undoes the export's `'` before text a spreadsheet would run.
  static String _undefused(String value) =>
      value.length > 1 && value[0] == "'" && '=+-@\t\r'.contains(value[1])
      ? value.substring(1)
      : value;

  /// RFC 4180: comma-separated, quoted cells may hold commas, quotes (as
  /// `""`) and line breaks; CRLF or LF line ends.
  static List<List<String>> _rows(String csv) {
    final rows = <List<String>>[];
    var row = <String>[];
    final cell = StringBuffer();
    var quoted = false;
    for (var i = 0; i < csv.length; i++) {
      final c = csv[i];
      if (quoted) {
        if (c != '"') {
          cell.write(c);
        } else if (i + 1 < csv.length && csv[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else if (c == '"') {
        quoted = true;
      } else if (c == ',') {
        row.add(cell.toString());
        cell.clear();
      } else if (c == '\n' || c == '\r') {
        if (c == '\r' && i + 1 < csv.length && csv[i + 1] == '\n') i++;
        row.add(cell.toString());
        cell.clear();
        rows.add(row);
        row = <String>[];
      } else {
        cell.write(c);
      }
    }
    if (cell.isNotEmpty || row.isNotEmpty) {
      row.add(cell.toString());
      rows.add(row);
    }
    return rows;
  }
}
