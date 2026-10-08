import '../../../../core/clock/year_month.dart';
import '../../../../core/result/result.dart';
import '../entities/expense.dart';
import '../value_objects/expense_failure.dart';

/// Personal expenses on this device. Every write is also queued for sync.
abstract interface class ExpenseRepository {
  Future<Result<void, ExpenseFailure>> add(Expense expense);

  /// Adds all of [expenses] in one transaction: all are saved, or none.
  Future<Result<void, ExpenseFailure>> addAll(List<Expense> expenses);

  /// Fails with `notFound` if the expense is missing or deleted.
  Future<Result<void, ExpenseFailure>> update(Expense expense);

  /// Leaves a tombstone, so the delete can sync. Fails with `notFound` if the
  /// expense is missing or already deleted.
  Future<Result<void, ExpenseFailure>> delete(String id);

  /// Every live (not deleted) expense, read once. In no particular order.
  Future<Result<List<Expense>, ExpenseFailure>> getAll();

  /// The live (not deleted) expenses dated in [month], re-emitted on every
  /// change. In no particular order.
  Stream<Result<List<Expense>, ExpenseFailure>> watchMonth(YearMonth month);
}
