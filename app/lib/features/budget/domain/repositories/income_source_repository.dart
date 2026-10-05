import '../../../../core/result/result.dart';
import '../entities/income_source.dart';
import '../value_objects/budget_failure.dart';

/// Income sources on this device. Every write is also queued for sync.
abstract interface class IncomeSourceRepository {
  /// The live (not deleted) sources, re-emitted on every change. In no
  /// particular order.
  Stream<Result<List<IncomeSource>, BudgetFailure>> watchAll();

  Future<Result<void, BudgetFailure>> add(IncomeSource source);

  /// Fails with `notFound` if the source is missing or deleted.
  Future<Result<void, BudgetFailure>> update(IncomeSource source);

  /// Leaves a tombstone, so the delete can sync. Fails with `notFound` if the
  /// source is missing or already deleted.
  Future<Result<void, BudgetFailure>> delete(String id);
}
