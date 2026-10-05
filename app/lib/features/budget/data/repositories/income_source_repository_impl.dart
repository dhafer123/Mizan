import '../../../../core/result/result.dart';
import '../../../../core/result/storage_errors_as_failures.dart';
import '../../domain/entities/income_source.dart';
import '../../domain/repositories/income_source_repository.dart';
import '../../domain/value_objects/budget_error.dart';
import '../../domain/value_objects/budget_failure.dart';
import '../db/income_sources_dao.dart';
import '../mappers/income_source_mapper.dart';

/// [IncomeSourceRepository] on the local drift database. Database errors
/// become [BudgetFailure]s; nothing is thrown past this class.
class IncomeSourceRepositoryImpl implements IncomeSourceRepository {
  const IncomeSourceRepositoryImpl(this._dao);

  final IncomeSourcesDao _dao;

  static const _storage = BudgetFailure(BudgetError.storage);

  @override
  Stream<Result<List<IncomeSource>, BudgetFailure>> watchAll() => _dao
      .watchLive()
      .map<Result<List<IncomeSource>, BudgetFailure>>(
        (rows) => Ok(rows.map(IncomeSourceMapper.toDomain).toList()),
      )
      .transform(storageErrorsAsFailures(_storage));

  @override
  Future<Result<void, BudgetFailure>> add(IncomeSource source) =>
      _guard(() => _dao.insertSource(IncomeSourceMapper.toRow(source)));

  @override
  Future<Result<void, BudgetFailure>> update(IncomeSource source) =>
      _guard(() => _dao.updateSource(IncomeSourceMapper.toRow(source)));

  @override
  Future<Result<void, BudgetFailure>> delete(String id) =>
      _guard(() => _dao.softDelete(id));

  static Future<Result<void, BudgetFailure>> _guard(
    Future<Object?> Function() write,
  ) async {
    try {
      await write();
      return const Ok(null);
    } on StateError {
      // The DAO's "no live income source with this id".
      return const Err(BudgetFailure(BudgetError.notFound));
    } on Object {
      return const Err(_storage);
    }
  }
}
