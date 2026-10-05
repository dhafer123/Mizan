import '../../../../core/result/failure.dart';
import 'expense_error.dart';

class ExpenseFailure extends Failure {
  const ExpenseFailure(this.error);

  final ExpenseError error;

  @override
  String get message => switch (error) {
    ExpenseError.amountNotPositive => 'The amount must be more than 0.',
    ExpenseError.noCategory => 'Pick a category.',
    ExpenseError.noteTooLong => 'The note is too long.',
    ExpenseError.dateInFuture => "The date can't be in the future.",
    ExpenseError.notFound => 'This expense no longer exists.',
    ExpenseError.storage => "Couldn't save on this device. Try again.",
  };

  @override
  bool operator ==(Object other) =>
      other is ExpenseFailure && other.error == error;

  @override
  int get hashCode => error.hashCode;
}
