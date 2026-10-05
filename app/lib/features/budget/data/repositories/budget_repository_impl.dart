import '../../../../core/money/currency.dart';
import '../../../../core/result/result.dart';
import '../../../../core/result/storage_errors_as_failures.dart';
import '../../domain/entities/budget.dart';
import '../../domain/repositories/budget_repository.dart';
import '../../domain/value_objects/budget_error.dart';
import '../../domain/value_objects/budget_failure.dart';
import '../db/budgets_dao.dart';
import '../mappers/budget_mapper.dart';

/// [BudgetRepository] on the local drift database. Database errors become
/// [BudgetFailure]s; nothing is thrown past this class.
class BudgetRepositoryImpl implements BudgetRepository {
  /// [currency] goes into rows of budgets without a limit.
  const BudgetRepositoryImpl(this._dao, {required Currency currency})
    : _currency = currency;

  final BudgetsDao _dao;
  final Currency _currency;

  static const _storage = BudgetFailure(BudgetError.storage);

  @override
  Stream<Result<List<Budget>, BudgetFailure>> watchAll() => _dao
      .watchLive()
      .map<Result<List<Budget>, BudgetFailure>>(
        (rows) => Ok(rows.map(BudgetMapper.toDomain).toList()),
      )
      .transform(storageErrorsAsFailures(_storage));

  @override
  Future<Result<void, BudgetFailure>> save(Budget budget) async {
    try {
      await _dao.saveBudget(BudgetMapper.toRow(budget, currency: _currency));
      return const Ok(null);
    } on Object {
      return const Err(_storage);
    }
  }
}
