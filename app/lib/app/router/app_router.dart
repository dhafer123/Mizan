import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/presentation/login/login_screen.dart';
import '../../features/auth/presentation/sign_up/sign_up_screen.dart';
import '../../features/beta/presentation/feedback_screen.dart';
import '../../features/budget/presentation/budget/budget_screen.dart';
import '../../features/budget/presentation/home/home_screen.dart';
import '../../features/budget/presentation/income/income_screen.dart';
import '../../features/expenses/presentation/categories/categories_screen.dart';
import '../../features/expenses/presentation/expense_list/expense_list_screen.dart';
import '../../features/groups/presentation/group_detail/group_screen.dart';
import '../../features/groups/presentation/group_list/groups_screen.dart';
import '../../features/groups/presentation/join/join_group_screen.dart';
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
  static const feedback = '/settings/feedback';
  static const login = '/login';
  static const signUp = '/signup';
  static const groups = '/groups';
  static const joinGroup = '/groups/join';
  static String group(String id) => '/groups/$id';

  /// Invite links (`InviteLink`) open here: `mizan://mizan.app/join/<token>`.
  static const joinWithToken = '/join/:token';
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
        path: AppRoutes.feedback,
        builder: (context, state) => const FeedbackScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: AppRoutes.groups,
        builder: (context, state) => const GroupsScreen(),
      ),
      // Before `/groups/:id`, which would match it too.
      GoRoute(
        path: AppRoutes.joinGroup,
        builder: (context, state) => const JoinGroupScreen(),
      ),
      GoRoute(
        path: '/groups/:id',
        builder: (context, state) =>
            GroupScreen(groupId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.joinWithToken,
        builder: (context, state) =>
            JoinGroupScreen(token: state.pathParameters['token']),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
}
