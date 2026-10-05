import '../../../../core/result/result.dart';
import '../entities/budget.dart';
import '../value_objects/budget_failure.dart';

/// Month budgets on this device. Every write is also queued for sync.
abstract interface class BudgetRepository {
  /// Every month's budget that was ever set, re-emitted on every change. In
  /// no particular order.
  Stream<Result<List<Budget>, BudgetFailure>> watchAll();

  /// Stores [budget] as its month's budget, replacing any set before.
  Future<Result<void, BudgetFailure>> save(Budget budget);
}
