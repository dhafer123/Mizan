import '../../../../core/clock/year_month.dart';
import '../../../../core/result/result.dart';
import '../../../../core/result/storage_errors_as_failures.dart';
import '../../domain/entities/expense.dart';
import '../../domain/repositories/expense_repository.dart';
import '../../domain/value_objects/expense_error.dart';
import '../../domain/value_objects/expense_failure.dart';
import '../db/expenses_dao.dart';
import '../mappers/expense_mapper.dart';

/// [ExpenseRepository] on the local drift database. Database errors become
/// [ExpenseFailure]s; nothing is thrown past this class.
class ExpenseRepositoryImpl implements ExpenseRepository {
  const ExpenseRepositoryImpl(this._dao);

  final ExpensesDao _dao;

  static const _notFound = ExpenseFailure(ExpenseError.notFound);

  @override
  Future<Result<void, ExpenseFailure>> add(Expense expense) =>
      _guard(() => _dao.insertExpense(ExpenseMapper.toRow(expense)));

  @override
  Future<Result<void, ExpenseFailure>> addAll(List<Expense> expenses) => _guard(
    () => _dao.insertExpenses(expenses.map(ExpenseMapper.toRow).toList()),
  );

  @override
  Future<Result<void, ExpenseFailure>> update(Expense expense) =>
      _guard(() => _dao.updateExpense(ExpenseMapper.toRow(expense)));

  @override
  Future<Result<void, ExpenseFailure>> delete(String id) =>
      _guard(() => _dao.softDelete(id));

  @override
  Future<Result<List<Expense>, ExpenseFailure>> getAll() async {
    try {
      return Ok((await _dao.getLive()).map(ExpenseMapper.toDomain).toList());
    } on Object {
      return const Err(ExpenseFailure(ExpenseError.storage));
    }
  }

  @override
  Stream<Result<List<Expense>, ExpenseFailure>> watchMonth(YearMonth month) =>
      _dao
          .watchBetween(month.firstDay, month.endExclusive)
          .map<Result<List<Expense>, ExpenseFailure>>(
            (rows) => Ok(rows.map(ExpenseMapper.toDomain).toList()),
          )
          .transform(
            storageErrorsAsFailures(const ExpenseFailure(ExpenseError.storage)),
          );

  static Future<Result<void, ExpenseFailure>> _guard(
    Future<Object?> Function() write,
  ) async {
    try {
      await write();
      return const Ok(null);
    } on StateError {
      // The DAO's "no live expense with this id".
      return const Err(_notFound);
    } on Object {
      return const Err(ExpenseFailure(ExpenseError.storage));
    }
  }
}
