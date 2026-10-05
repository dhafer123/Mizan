import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../app/di/expenses_providers.dart';
import '../../../../core/clock/year_month.dart';
import '../../../../core/result/result.dart';
import '../../domain/value_objects/expense_day.dart';
import '../shared/no_retry.dart';

part 'month_expenses_provider.g.dart';

/// The month's expenses by day. A failure becomes the error state.
@Riverpod(retry: noRetry)
Stream<List<ExpenseDay>> monthExpenses(Ref ref, YearMonth month) => ref
    .watch(watchMonthExpensesProvider)(month)
    .map(
      (result) => switch (result) {
        Ok(:final value) => value,
        Err(:final failure) => throw failure,
      },
    );
