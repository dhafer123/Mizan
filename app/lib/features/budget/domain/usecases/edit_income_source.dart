import '../../../../core/result/result.dart';
import '../entities/income_source.dart';
import '../repositories/income_source_repository.dart';
import '../value_objects/budget_failure.dart';
import 'validate_income_source.dart';

/// Saves changes to an income source. Returns it as saved.
class EditIncomeSource {
  const EditIncomeSource(this._repository, this._validate);

  final IncomeSourceRepository _repository;
  final ValidateIncomeSource _validate;

  Future<Result<IncomeSource, BudgetFailure>> call(IncomeSource source) async {
    switch (_validate(source)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final valid):
        final saved = await _repository.update(valid);
        return saved.map((_) => valid);
    }
  }
}
