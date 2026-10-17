import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/features/budget/presentation/budget/budget_screen.dart';
import 'package:mizan/features/budget/presentation/home/home_screen.dart';
import 'package:mizan/features/expenses/presentation/expense_list/expense_list_screen.dart';
import 'package:mizan/features/groups/presentation/group_list/groups_screen.dart';
import 'package:mizan/features/settings/presentation/settings_screen.dart';

import '../../support/app_harness.dart';

void main() {
  Future<AppHarness> boot(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final app = AppHarness();
    await app.boot(tester);
    return app;
  }

  Future<void> tapTab(WidgetTester tester, String label) async {
    await tester.tap(find.byTooltip(label));
    await tester.pumpAndSettle();
  }

  testWidgets('the four tabs, one tap apart', (tester) async {
    final app = await boot(tester);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(HomeScreen), findsOneWidget);

    await tapTab(tester, 'Expenses');
    expect(find.byType(ExpenseListScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing, reason: 'kept, offstage');

    await tapTab(tester, 'Groups');
    expect(find.byType(GroupsScreen), findsOneWidget);

    await tapTab(tester, 'Budget');
    expect(find.byType(BudgetScreen), findsOneWidget);

    await tapTab(tester, 'Home');
    expect(find.byType(HomeScreen), findsOneWidget);

    await app.shutDown(tester);
  });

  testWidgets('back from another tab returns to Home first', (tester) async {
    final app = await boot(tester);

    await tapTab(tester, 'Budget');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );

    await app.shutDown(tester);
  });

  testWidgets('other screens open full screen, above the tabs', (tester) async {
    final app = await boot(tester);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);

    await app.shutDown(tester);
  });

  testWidgets('a snackbar shows once, above its own tab', (tester) async {
    final app = await boot(tester);
    // Visit every tab, so all four Scaffolds are alive.
    for (final tab in ['Expenses', 'Groups', 'Budget', 'Home']) {
      await tapTab(tester, tab);
    }

    ScaffoldMessenger.of(
      tester.element(find.byType(HomeScreen)),
    ).showSnackBar(const SnackBar(content: Text('Added 1 expense.')));
    await tester.pumpAndSettle();

    expect(find.text('Added 1 expense.'), findsOneWidget);

    await app.shutDown(tester);
  });
}
