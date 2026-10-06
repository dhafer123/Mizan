import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/presentation/login/login_screen.dart';
import '../../features/auth/presentation/sign_up/sign_up_screen.dart';
import '../../features/budget/presentation/budget/budget_screen.dart';
import '../../features/budget/presentation/home/home_screen.dart';
import '../../features/budget/presentation/income/income_screen.dart';
import '../../features/expenses/presentation/categories/categories_screen.dart';
import '../../features/expenses/presentation/expense_list/expense_list_screen.dart';
import '../../features/settings/presentation/pin/pin_setup_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';

part 'app_router.g.dart';

/// Route paths, kept in one place so screens never hard-code strings.
abstract final class AppRoutes {
  static const home = '/';
  static const expenses = '/expenses';
  static const categories = '/categories';
  static const budget = '/budget';
  static const income = '/income';
  static const settings = '/settings';
  static const pin = '/settings/pin';
  static const login = '/login';
  static const signUp = '/signup';
}

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.expenses,
        builder: (context, state) => const ExpenseListScreen(),
      ),
      GoRoute(
        path: AppRoutes.categories,
        builder: (context, state) => const CategoriesScreen(),
      ),
      GoRoute(
        path: AppRoutes.budget,
        builder: (context, state) => const BudgetScreen(),
      ),
      GoRoute(
        path: AppRoutes.income,
        builder: (context, state) => const IncomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.pin,
        builder: (context, state) => const PinSetupScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        builder: (context, state) => const SignUpScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
}
