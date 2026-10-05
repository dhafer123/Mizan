import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/budget/presentation/home/home_screen.dart';
import '../../features/expenses/presentation/categories/categories_screen.dart';
import '../../features/expenses/presentation/expense_list/expense_list_screen.dart';

part 'app_router.g.dart';

/// Route paths, kept in one place so screens never hard-code strings.
abstract final class AppRoutes {
  static const home = '/';
  static const expenses = '/expenses';
  static const categories = '/categories';
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
    ],
  );
  ref.onDispose(router.dispose);
  return router;
}
