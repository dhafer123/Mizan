import 'expense_failure.dart';

/// An [ExpenseFailure] for one expense of several, at [index] (0-based).
class ExpenseItemFailure extends ExpenseFailure {
  const ExpenseItemFailure(this.index, super.error);

  final int index;

  @override
  bool operator ==(Object other) =>
      other is ExpenseItemFailure && other.index == index && super == other;

  @override
  int get hashCode => Object.hash(index, error);
}
