import '../../../../core/result/result.dart';
import '../entities/income_source.dart';
import '../repositories/income_source_repository.dart';
import '../value_objects/budget_failure.dart';

/// The income sources, sorted by name.
class WatchIncomeSources {
  const WatchIncomeSources(this._repository);

  final IncomeSourceRepository _repository;

  Stream<Result<List<IncomeSource>, BudgetFailure>> call() =>
      _repository.watchAll().map(
        (result) => result.map(
          (sources) => [...sources]
            ..sort((a, b) {
              final byName = a.name.toLowerCase().compareTo(
                b.name.toLowerCase(),
              );
              return byName != 0 ? byName : a.id.compareTo(b.id);
            }),
        ),
      );
}
