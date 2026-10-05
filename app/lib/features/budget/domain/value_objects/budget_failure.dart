import '../../../../core/result/failure.dart';
import 'budget_error.dart';

class BudgetFailure extends Failure {
  const BudgetFailure(this.error);

  final BudgetError error;

  @override
  String get message => switch (error) {
    BudgetError.nameEmpty => 'Enter a name.',
    BudgetError.nameTooLong => 'The name is too long.',
    BudgetError.amountNotPositive => 'The amount must be more than 0.',
    BudgetError.invalidDay => 'Pick a day between 1 and 31.',
    BudgetError.limitNotPositive => 'The budget must be more than 0.',
    BudgetError.notFound => 'This income source no longer exists.',
    BudgetError.storage => "Couldn't save on this device. Try again.",
  };

  @override
  bool operator ==(Object other) =>
      other is BudgetFailure && other.error == error;

  @override
  int get hashCode => error.hashCode;
}
