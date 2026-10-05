import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/expenses/data/repositories/category_repository_impl.dart';
import '../../features/expenses/data/repositories/expense_repository_impl.dart';
import '../../features/expenses/domain/repositories/category_repository.dart';
import '../../features/expenses/domain/repositories/expense_repository.dart';
import '../../features/expenses/domain/usecases/add_expense.dart';
import '../../features/expenses/domain/usecases/delete_expense.dart';
import '../../features/expenses/domain/usecases/edit_expense.dart';
import '../../features/expenses/domain/usecases/validate_expense.dart';
import '../../features/expenses/domain/usecases/watch_categories.dart';
import '../../features/expenses/domain/usecases/watch_month_expenses.dart';
import 'core_providers.dart';
import 'database_providers.dart';

part 'expenses_providers.g.dart';

@Riverpod(keepAlive: true)
ExpenseRepository expenseRepository(Ref ref) =>
    ExpenseRepositoryImpl(ref.watch(appDatabaseProvider).expensesDao);

@Riverpod(keepAlive: true)
CategoryRepository categoryRepository(Ref ref) =>
    CategoryRepositoryImpl(ref.watch(appDatabaseProvider).categoriesDao);

@Riverpod(keepAlive: true)
ValidateExpense validateExpense(Ref ref) =>
    ValidateExpense(ref.watch(clockProvider));

@Riverpod(keepAlive: true)
AddExpense addExpense(Ref ref) => AddExpense(
  ref.watch(expenseRepositoryProvider),
  ref.watch(idGeneratorProvider),
  ref.watch(validateExpenseProvider),
);

@Riverpod(keepAlive: true)
EditExpense editExpense(Ref ref) => EditExpense(
  ref.watch(expenseRepositoryProvider),
  ref.watch(validateExpenseProvider),
);

@Riverpod(keepAlive: true)
DeleteExpense deleteExpense(Ref ref) =>
    DeleteExpense(ref.watch(expenseRepositoryProvider));

@Riverpod(keepAlive: true)
WatchMonthExpenses watchMonthExpenses(Ref ref) =>
    WatchMonthExpenses(ref.watch(expenseRepositoryProvider));

@Riverpod(keepAlive: true)
WatchCategories watchCategories(Ref ref) =>
    WatchCategories(ref.watch(categoryRepositoryProvider));
