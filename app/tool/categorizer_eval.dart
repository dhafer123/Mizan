// Measures the categorizer on a real history (task 5.7): replays the app's
// CSV export in order, suggesting each expense's category from the ones
// before it (memory + keywords) and from keywords alone, against what the
// user chose.
//
// Usage (from app/): dart run tool/categorizer_eval.dart <expenses.csv>
//
// Category names in the CSV that match a default category ("Food") count as
// it; others are the user's own. Only expenses with a note are replayed.
import 'dart:io';

import 'package:mizan/features/expenses/domain/entities/category.dart';
import 'package:mizan/features/expenses/domain/entities/default_categories.dart';
import 'package:mizan/features/expenses/domain/entities/expense.dart';

import 'backtest/expenses_csv_reader.dart';
import 'categorizer/categorizer_replay.dart';

void main(List<String> args) {
  if (args.length != 1 || !File(args.single).existsSync()) {
    stderr.writeln('Usage: dart run tool/categorizer_eval.dart <expenses.csv>');
    exitCode = 64;
    return;
  }
  final List<Expense> read;
  try {
    read = const ExpensesCsvReader()(File(args.single).readAsStringSync());
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    exitCode = 64;
    return;
  }

  // The CSV holds category names: map default names back to their ids.
  final defaults = {
    for (final c in DefaultCategories.all) c.name.toLowerCase(): c,
  };
  String idOf(String name) => defaults[name.toLowerCase()]?.id ?? name;
  final expenses = [
    for (final e in read) e.copyWith(categoryId: idOf(e.categoryId)),
  ];
  final categories = <Category>[
    ...DefaultCategories.all,
    for (final name in {for (final e in read) e.categoryId})
      if (!defaults.containsKey(name.toLowerCase()))
        Category(id: name, name: name, icon: 'other'),
  ];

  stdout.writeln(CategorizerReplay.of(expenses, categories: categories));
}
