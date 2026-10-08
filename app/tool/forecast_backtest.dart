// Backtests the run-out forecast on a real spending history (task 5.3,
// ARCHITECTURE.md §7, ADR 0014) and prints the mean absolute error in days.
//
// Usage (from app/):
//   dart run tool/forecast_backtest.dart <expenses.csv>
//       [--income AMOUNT:WHEN]... [--budget AMOUNT] [--end YYYY-MM-DD] [--days]
//
// - expenses.csv: the app's export (Settings → Export expenses), or any CSV
//   with Date, Amount and Currency columns.
// - --income: one per income source, as set in the app. WHEN is a day of
//   the month (monthly), a date (one-off) or "irregular". E.g. 450:1.
// - --budget: the monthly budget, for cold-start forecasts.
// - --end: the last day the data covers (default: the last expense's day).
//   Use the export day, so quiet days at the end count as no spending.
// - --days: also print every replayed day.
import 'dart:io';

import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/core/money/money_parser.dart';
import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/budget/domain/entities/income_source.dart';
import 'package:mizan/features/budget/domain/value_objects/income_schedule.dart';

import 'backtest/backtest_forecast.dart';
import 'backtest/backtest_summary.dart';
import 'backtest/expenses_csv_reader.dart';

void main(List<String> args) {
  try {
    _run(args);
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    stderr.writeln(
      'Usage: dart run tool/forecast_backtest.dart <expenses.csv> '
      '[--income AMOUNT:WHEN]... [--budget AMOUNT] [--end YYYY-MM-DD] '
      '[--days]',
    );
    exitCode = 64;
  }
}

void _run(List<String> args) {
  String? path;
  final incomeArgs = <String>[];
  String? budgetArg;
  String? endArg;
  var printDays = false;
  for (var i = 0; i < args.length; i++) {
    String value() => i + 1 < args.length
        ? args[++i]
        : throw FormatException('${args[i]} needs a value.');
    switch (args[i]) {
      case '--income':
        incomeArgs.add(value());
      case '--budget':
        budgetArg = value();
      case '--end':
        endArg = value();
      case '--days':
        printDays = true;
      case final arg when arg.startsWith('--'):
        throw FormatException('Unknown option $arg.');
      case final arg:
        if (path != null) throw const FormatException('Give one CSV file.');
        path = arg;
    }
  }
  if (path == null) throw const FormatException('Give the expenses CSV.');

  final file = File(path);
  if (!file.existsSync()) throw FormatException('No file at $path.');
  final expenses = const ExpensesCsvReader()(file.readAsStringSync());
  if (expenses.isEmpty) throw const FormatException('The CSV has no expenses.');
  final currencies = {for (final e in expenses) e.amount.currency};
  if (currencies.length > 1) {
    throw const FormatException('The CSV mixes currencies.');
  }
  final currency = currencies.single;

  final incomes = [
    for (final (i, arg) in incomeArgs.indexed) _income(arg, i, currency),
  ];
  final budget = budgetArg == null ? null : _money(budgetArg, currency);
  final lastExpense = expenses
      .map((e) => e.date)
      .reduce((a, b) => a.isAfter(b) ? a : b);
  final end = endArg == null ? lastExpense : _date(endArg);
  if (end.isBefore(lastExpense)) {
    throw const FormatException('--end is before the last expense.');
  }

  final days = const BacktestForecast()(
    expenses: expenses,
    incomes: incomes,
    currency: currency,
    end: end,
    monthlyBudget: budget,
  );
  String date(DateTime d) => d.toIso8601String().substring(0, 10);
  final first = expenses
      .map((e) => e.date)
      .reduce((a, b) => a.isBefore(b) ? a : b);
  stdout.writeln(
    '${expenses.length} expenses, ${date(first)} to ${date(end)} '
    '(${end.difference(first).inDays + 1} days), ${incomes.length} income '
    'source(s), budget ${budgetArg ?? 'none'}.\n',
  );
  if (printDays) {
    days.forEach(stdout.writeln);
    stdout.writeln();
  }
  stdout.writeln('All days\n${BacktestSummary.of(days)}\n');
  stdout.writeln(
    'Learned rate only (no cold start)\n'
    '${BacktestSummary.of(days.where((d) => !d.coldStart))}',
  );
}

IncomeSource _income(String arg, int index, Currency currency) {
  final colon = arg.lastIndexOf(':');
  if (colon < 0) throw FormatException('--income $arg is not AMOUNT:WHEN.');
  final amount = _money(arg.substring(0, colon), currency);
  final when = arg.substring(colon + 1);
  final day = int.tryParse(when);
  final schedule = when == 'irregular'
      ? const IncomeSchedule.irregular()
      : day != null
      ? (day >= 1 && day <= 31
            ? IncomeSchedule.monthly(dayOfMonth: day)
            : throw FormatException('--income day $day is not 1-31.'))
      : IncomeSchedule.oneOff(date: _date(when));
  return IncomeSource(
    id: 'income-$index',
    name: 'Income ${index + 1}',
    amount: amount,
    schedule: schedule,
  );
}

Money _money(String text, Currency currency) =>
    switch (const MoneyParser().parse(text, currency: currency)) {
      Ok(:final value) when value.isPositive => value,
      _ => throw FormatException('"$text" is not an amount above 0.'),
    };

DateTime _date(String text) {
  final d = DateTime.tryParse(text);
  if (d == null || text.length != 10) {
    throw FormatException('"$text" is not YYYY-MM-DD.');
  }
  return DateTime.utc(d.year, d.month, d.day);
}
