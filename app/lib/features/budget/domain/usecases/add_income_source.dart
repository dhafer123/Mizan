import '../../../../core/ids/id_generator.dart';
import '../../../../core/money/money.dart';
import '../../../../core/result/result.dart';
import '../entities/income_source.dart';
import '../repositories/income_source_repository.dart';
import '../value_objects/budget_failure.dart';
import '../value_objects/income_schedule.dart';
import 'validate_income_source.dart';

/// Records a new income source. Returns it as saved.
class AddIncomeSource {
  const AddIncomeSource(this._repository, this._ids, this._validate);

  final IncomeSourceRepository _repository;
  final IdGenerator _ids;
  final ValidateIncomeSource _validate;

  Future<Result<IncomeSource, BudgetFailure>> call({
    required String name,
    required Money amount,
    required IncomeSchedule schedule,
  }) async {
    final validated = _validate(
      IncomeSource(
        id: _ids.newId(),
        name: name,
        amount: amount,
        schedule: schedule,
      ),
    );
    switch (validated) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final source):
        final saved = await _repository.add(source);
        return saved.map((_) => source);
    }
  }
}
