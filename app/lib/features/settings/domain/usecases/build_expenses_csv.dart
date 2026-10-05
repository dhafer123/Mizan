import '../../../../core/money/money.dart';
import '../../../expenses/domain/entities/category.dart';
import '../../../expenses/domain/entities/expense.dart';

/// Expenses as CSV for a spreadsheet (RFC 4180): oldest first, one row
/// each, under a header row.
///
/// - Comma-separated, CRLF line ends, UTF-8 with a byte-order mark so Excel
///   reads accents and Arabic correctly.
/// - Dates as `YYYY-MM-DD`; amounts as plain decimals with a dot (`12.500`)
///   and the currency in its own column, so they sum as numbers.
/// - Text a spreadsheet would run as a formula (starting with `=`, `+`, `-`,
///   `@`) is prefixed with `'`.
class BuildExpensesCsv {
  const BuildExpensesCsv();

  static const header = [
    'Date',
    'Amount',
    'Currency',
    'Category',
    'Note',
    'Source',
    'ID',
  ];

  /// The byte-order mark the CSV starts with.
  static const bom = '﻿';

  String call({
    required List<Expense> expenses,
    required List<Category> categories,
  }) {
    final names = {for (final c in categories) c.id: c.name};
    final sorted = [...expenses]
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        return byDate != 0 ? byDate : a.id.compareTo(b.id);
      });

    final out = StringBuffer(bom)..write(_row(header));
    for (final e in sorted) {
      out.write(
        _row([
          _date(e.date),
          amount(e.amount),
          e.amount.currency.code,
          _text(names[e.categoryId] ?? 'Uncategorised'),
          _text(e.note ?? ''),
          e.source.name,
          e.id,
        ]),
      );
    }
    return out.toString();
  }

  /// `12.500` for 12.5 DT: no grouping, a dot, the currency's decimals.
  static String amount(Money money) {
    final currency = money.currency;
    final units = money.minorUnits.abs();
    final major = units ~/ currency.minorPerMajor;
    final minor = units % currency.minorPerMajor;
    final sign = money.isNegative ? '-' : '';
    if (currency.decimals == 0) return '$sign$major';
    return '$sign$major.${minor.toString().padLeft(currency.decimals, '0')}';
  }

  static String _date(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  /// Free text, defused so a spreadsheet shows it rather than running it.
  static String _text(String value) =>
      value.isNotEmpty && '=+-@\t\r'.contains(value[0]) ? "'$value" : value;

  static String _row(List<String> cells) =>
      '${cells.map(_quote).join(',')}\r\n';

  static String _quote(String cell) {
    final needsQuotes =
        cell.contains(',') ||
        cell.contains('"') ||
        cell.contains('\n') ||
        cell.contains('\r') ||
        cell != cell.trim();
    return needsQuotes ? '"${cell.replaceAll('"', '""')}"' : cell;
  }
}
