import 'dart:async';

import 'package:mizan/core/clock/year_month.dart';
import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/expenses/domain/entities/expense.dart';
import 'package:mizan/features/expenses/domain/repositories/expense_repository.dart';
import 'package:mizan/features/expenses/domain/value_objects/expense_error.dart';
import 'package:mizan/features/expenses/domain/value_objects/expense_failure.dart';

/// An in-memory [ExpenseRepository] for use case and widget tests.
class FakeExpenseRepository implements ExpenseRepository {
  FakeExpenseRepository([Iterable<Expense> expenses = const []])
    : _live = {for (final e in expenses) e.id: e};

  final Map<String, Expense> _live;
  final _changes = StreamController<void>.broadcast();

  /// Every id passed to [delete], in order.
  final deleted = <String>[];

  /// When set, every write fails with this.
  ExpenseFailure? writeFailure;

  /// When set, [watchMonth] emits this instead of rows.
  ExpenseFailure? watchFailure;

  List<Expense> get live => _live.values.toList();

  @override
  Future<Result<void, ExpenseFailure>> add(Expense expense) async {
    if (writeFailure case final failure?) return Err(failure);
    _live[expense.id] = expense;
    _changes.add(null);
    return const Ok(null);
  }

  @override
  Future<Result<void, ExpenseFailure>> update(Expense expense) async {
    if (writeFailure case final failure?) return Err(failure);
    if (!_live.containsKey(expense.id)) return _notFound;
    _live[expense.id] = expense;
    _changes.add(null);
    return const Ok(null);
  }

  @override
  Future<Result<void, ExpenseFailure>> delete(String id) async {
    if (writeFailure case final failure?) return Err(failure);
    if (_live.remove(id) == null) return _notFound;
    deleted.add(id);
    _changes.add(null);
    return const Ok(null);
  }

  /// When set, [getAll] fails with this.
  ExpenseFailure? readFailure;

  @override
  Future<Result<List<Expense>, ExpenseFailure>> getAll() async =>
      switch (readFailure) {
        final failure? => Err(failure),
        null => Ok(_live.values.toList()),
      };

  @override
  Stream<Result<List<Expense>, ExpenseFailure>> watchMonth(
    YearMonth month,
  ) async* {
    yield _month(month);
    await for (final _ in _changes.stream) {
      yield _month(month);
    }
  }

  Result<List<Expense>, ExpenseFailure> _month(YearMonth month) =>
      switch (watchFailure) {
        final failure? => Err(failure),
        null => Ok(_live.values.where((e) => month.contains(e.date)).toList()),
      };

  static const _notFound = Err<void, ExpenseFailure>(
    ExpenseFailure(ExpenseError.notFound),
  );
}
