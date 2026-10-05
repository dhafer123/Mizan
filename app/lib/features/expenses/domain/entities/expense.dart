import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/money/money.dart';
import '../value_objects/expense_source.dart';

part 'expense.freezed.dart';

/// A personal expense.
@freezed
abstract class Expense with _$Expense {
  const factory Expense({
    required String id,
    required Money amount,
    required String categoryId,

    /// The calendar day it was spent (UTC midnight, see `CalendarDay`).
    required DateTime date,
    String? note,
    @Default(ExpenseSource.manual) ExpenseSource source,
  }) = _Expense;
}
