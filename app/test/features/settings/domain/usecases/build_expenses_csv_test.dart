import 'package:glados/glados.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/expenses/domain/entities/default_categories.dart';
import 'package:mizan/features/expenses/domain/entities/expense.dart';
import 'package:mizan/features/expenses/domain/value_objects/expense_source.dart';
import 'package:mizan/features/settings/domain/usecases/build_expenses_csv.dart';

const _build = BuildExpensesCsv();

Expense _expense(
  String id,
  int millimes, {
  String categoryId = 'food',
  int day = 3,
  String? note,
  ExpenseSource source = ExpenseSource.manual,
}) => Expense(
  id: id,
  amount: Money(millimes, Currency.tnd),
  categoryId: categoryId,
  date: DateTime.utc(2026, 10, day),
  note: note,
  source: source,
);

String _csv(List<Expense> expenses) =>
    _build(expenses: expenses, categories: DefaultCategories.all);

/// Parses RFC 4180 CSV (after the byte-order mark) into rows of cells: what
/// a spreadsheet does on import.
List<List<String>> _parse(String csv) {
  expect(csv.startsWith(BuildExpensesCsv.bom), isTrue);
  final text = csv.substring(1);
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (quoted) {
      if (c == '"' && i + 1 < text.length && text[i + 1] == '"') {
        cell.write('"');
        i++;
      } else if (c == '"') {
        quoted = false;
      } else {
        cell.write(c);
      }
    } else if (c == '"') {
      quoted = true;
    } else if (c == ',') {
      row.add(cell.toString());
      cell.clear();
    } else if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') {
      row.add(cell.toString());
      cell.clear();
      rows.add(row);
      row = <String>[];
      i++;
    } else {
      cell.write(c);
    }
  }
  expect(row, isEmpty, reason: 'the last row ends with CRLF');
  return rows;
}

/// Notes with the characters that break naive CSV.
extension _NoteAnys on Any {
  Generator<String> get awkwardNote => any
      .listWithLengthInRange(
        0,
        12,
        any.choose([
          'a',
          'Z',
          ' ',
          ',',
          '"',
          '\n',
          '\r',
          '\r\n',
          ';',
          'é',
          'ق',
          '😀',
          '=',
          '+',
          '-',
          '@',
          '\t',
          "'",
        ]),
      )
      .map((parts) => parts.join());
}

void main() {
  test('a header, then one row per expense, oldest first', () {
    final rows = _parse(
      _csv([
        _expense('b', 3500, day: 5, note: 'Coffee'),
        _expense(
          'a',
          120000,
          categoryId: 'rent',
          day: 1,
          source: ExpenseSource.voice,
        ),
      ]),
    );

    expect(rows, [
      BuildExpensesCsv.header,
      ['2026-10-01', '120.000', 'TND', 'Rent', '', 'voice', 'a'],
      ['2026-10-05', '3.500', 'TND', 'Food', 'Coffee', 'manual', 'b'],
    ]);
  });

  test('CRLF line ends and a byte-order mark', () {
    final csv = _csv([_expense('a', 1000)]);

    expect(csv, startsWith('﻿Date,Amount,'));
    expect(csv, endsWith('\r\n'));
    expect(csv.replaceAll('\r\n', ''), isNot(contains('\n')));
  });

  test('amounts as plain decimals in the currency precision', () {
    expect(
      BuildExpensesCsv.amount(const Money(1234567, Currency.tnd)),
      '1234.567',
    );
    expect(BuildExpensesCsv.amount(const Money(5, Currency.tnd)), '0.005');
    expect(BuildExpensesCsv.amount(const Money(450, Currency.eur)), '4.50');
    expect(BuildExpensesCsv.amount(const Money(-450, Currency.eur)), '-4.50');
  });

  test('commas, quotes and line breaks are quoted', () {
    final csv = _csv([_expense('a', 1000, note: 'Pizza, "large"\nfor 2')]);

    expect(csv, contains('"Pizza, ""large""\nfor 2"'));
    expect(_parse(csv)[1][4], 'Pizza, "large"\nfor 2');
  });

  test('text that a spreadsheet would run as a formula is defused', () {
    final rows = _parse(
      _csv([
        _expense('a', 1000, note: '=HYPERLINK("http://x")'),
        _expense('b', 1000, note: '-2+3'),
        _expense('c', 1000, note: '@SUM(A1)'),
        _expense('d', 1000, note: 'Lunch = 5'),
      ]),
    );

    expect(rows.skip(1).map((r) => r[4]), [
      "'=HYPERLINK(\"http://x\")",
      "'-2+3",
      "'@SUM(A1)",
      'Lunch = 5',
    ]);
  });

  test('unknown and archived categories', () {
    final rows = _parse(
      _build(
        expenses: [
          _expense('a', 1000, categoryId: 'gone'),
          _expense('b', 1000, categoryId: 'leisure'),
        ],
        categories: [DefaultCategories.leisure.copyWith(archived: true)],
      ),
    );

    expect(rows.skip(1).map((r) => r[3]), ['Uncategorised', 'Leisure']);
  });

  test('no expenses: just the header', () {
    expect(_parse(_csv([])), [BuildExpensesCsv.header]);
  });

  Glados2(any.awkwardNote, any.intInRange(1, 100000000)).test(
    'every note and amount reads back as written',
    (note, millimes) {
      final rows = _parse(_csv([_expense('a', millimes, note: note)]));

      expect(rows, hasLength(2));
      expect(rows[1], hasLength(BuildExpensesCsv.header.length));
      final read = rows[1][4];
      // Only a defused formula gains its leading quote.
      final defused = note.isNotEmpty && '=+-@\t\r'.contains(note[0]);
      expect(read, defused ? "'$note" : note);
      final [major, minor] = rows[1][1].split('.');
      expect(int.parse(major) * 1000 + int.parse(minor), millimes);
    },
  );
}
